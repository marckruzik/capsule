type synced_state = {
    account_info : Beacon_js.Account_info.t
  ; balance : Tezos_js.Tez.t
  ; address_form : string * bool
  ; cost_per_byte : Tezos_js.Tez.t
  ; head : Tezos_js.Monitored_head.t option
}

type state = Not_sync | Sync of synced_state
type t = { error : string option; state : state }

val update : t -> Messages.t -> t * Messages.t Vdom.Cmd.t
val init : Beacon_js.Client.t -> (t * Messages.t Vdom.Cmd.t) Lwt.t
