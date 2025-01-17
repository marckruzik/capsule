type error = [ `Json_error of string | `Json_exn of exn | `Http_error of int ]

type retention_policy =
  | Raise of (exn -> (unit, error) result Lwt.t)
  | Restart of float

module Directory = struct
  open Path

  let get_chain () = ~/:chain_id
  let get_block () = ~:get_chain /: block_id
  let get_context () = ~:get_block / "context"
  let get_contract () = ~:get_context /: contract_id
  let get_balance () = ~:get_contract / "balance"
  let get_parametric_constants () = ~:get_context / "constants" / "parametric"
  let get_manager_key () = ~:get_contract / "manager_key"
  let monitor_heads () = ~/"monitor" / "heads" / "main"
end

open Core_js

let make_fetch entrypoint url =
  match Entrypoint.method_of entrypoint with
  | `GET -> Fetch.get url
  | `POST -> Fetch.post url
  | `PATCH -> Fetch.patch url
  | `DELETE -> Fetch.delete url

let make_stream ?(retention_policy = Restart 1.) ~network ~entrypoint ~on_chunk
    =
  let entrypoint = entrypoint () in
  Entrypoint.sprintf_with
    (fun path ->
      let open Lwt_util in
      let url = Network.base_path network ^ path in
      let rec loop () =
        let* response = make_fetch entrypoint url in
        let rpc_encoding = Entrypoint.encoding_of entrypoint in
        if Fetch.Response.ok response then
          let reader = Fetch.Response.get_reader response in
          try
            let rec read () =
              let* is_done, json_txt = Fetch.Response.read_body reader in
              if not is_done then
                let*? obj =
                  json_txt
                  |> Data_encoding.Json.from_string
                  |> Result.map_error (fun message -> `Json_error message)
                  |> Result.bind (fun x ->
                         try Ok (Data_encoding.Json.destruct rpc_encoding x)
                         with exn -> Error (`Json_exn exn))
                  |> return
                in
                let*? () = on_chunk obj in
                read ()
              else return_ok ()
            in
            read ()
          with exn -> (
            let () = Console.(message log) "trapped exception" in
            let () = Console.error exn in

            match retention_policy with
            | Raise handler -> handler exn
            | Restart delay ->
                let* () = Js_of_ocaml_lwt.Lwt_js.sleep delay in
                loop ())
        else return_error @@ `Http_error (Fetch.Response.status response)
      in
      loop ())
    entrypoint

let make_call ~network ~entrypoint =
  let entrypoint = entrypoint () in
  Entrypoint.sprintf_with
    (fun path ->
      let open Lwt_util in
      let url = Network.base_path network ^ path in
      let rpc_encoding = Entrypoint.encoding_of entrypoint in
      let* response = make_fetch entrypoint url in
      if Fetch.Response.ok response then
        let+ json_txt = Fetch.Response.text response in
        json_txt
        |> Data_encoding.Json.from_string
        |> Result.map @@ Data_encoding.Json.destruct rpc_encoding
        |> Result.map_error (fun message -> `Json_error message)
      else return_error @@ `Http_error (Fetch.Response.status response))
    entrypoint

let make_call_head ~network ~entrypoint =
  make_call ~network ~entrypoint Chain_id.main Block_id.head

let is_reachable ~network ~entrypoint =
  let entrypoint = entrypoint () in
  Entrypoint.sprintf_with
    (fun path ->
      let open Lwt_util in
      let url = Network.base_path network ^ path in
      let+ response = make_fetch entrypoint url in
      Fetch.Response.ok response)
    entrypoint

let is_reachable_head ~network ~entrypoint =
  is_reachable ~network ~entrypoint Chain_id.main Block_id.head

let get_balance () = Entrypoint.get ~path:Directory.get_balance Tez.encoding

let get_parametric_constants () =
  Entrypoint.get ~path:Directory.get_parametric_constants Constants.encoding

let get_manager_key () =
  Entrypoint.get ~path:Directory.get_manager_key Data_encoding.(option string)

let monitor_heads () =
  Entrypoint.get ~path:Directory.monitor_heads Monitored_head.encoding
