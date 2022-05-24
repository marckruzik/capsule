open Yocaml

let program target =
  let* () = Lib.Rule.static ~target in
  return ()

let build target = Yocaml_unix.execute $ program target

let watch target port =
  let server = Yocaml_unix.serve ~filepath:target ~port $ program target in
  let () = build target in
  Lwt_main.run server
