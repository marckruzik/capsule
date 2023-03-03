#include "storage.mligo"
#include "entrypoint.mligo"
#import "../util/nat_ext.mligo" "Nat"

let main 
    (action, previous_storage : entrypoint * storage_v1) 
: operation list * storage_v1 = match action with

  | Deposit ->
    let donation = Tezos.get_amount () in
    let donator = Tezos.get_sender () in
    let history_ts = Tezos.get_now () in 
    let new_level = previous_storage.level + 1n in

    let new_balance = 
      previous_storage.historical_balance + donation 
    in

    let new_history = 
       Big_map.add 
         previous_storage.level
         (donator, donation, history_ts) 
         previous_storage.history
    in

    let new_storage = { 
        previous_storage with 
          historical_balance = new_balance
        ; level = new_level
        ; history = new_history } 
    in

    ([], new_storage)

  | Retreive amount -> 
    let requester = Tezos.get_sender () in
    if (requester = previous_storage.owner_address) then
      let balance = Tezos.get_balance () in
      if (Option.value 0tez (balance - amount) > 1tez) then 
        let owner : unit contract = 
          Tezos.get_contract_with_error 
            previous_storage.owner_address
            "Unable to find the owner"
        in
        ([Tezos.transaction unit amount owner], previous_storage)
      else failwith "The minimum balance of the contract must be [1tez]"
    else failwith "You are not the owner of the benefactor wallet"

let rec collect_history
  (storage: storage_v1)
  (index: nat) 
  (stop: nat) 
  (acc : (address * tez * timestamp) list) :
  (address * tez * timestamp) list = 
  if (index >= stop) then acc
  else
    let new_acc =
      match Big_map.find_opt index storage.history with
      | None -> acc
      | Some x -> x :: acc
    in collect_history storage (index + 1n) stop new_acc

[@view]
let history_lookup 
  ((start, length), storage : (nat * nat) * storage_v1) : 
  (address * tez * timestamp) list = 
    if (start >= storage.level) then []
    else
      let stop = Nat.min (start + length) (storage.level) in
      collect_history storage start stop []

[@view]
let history_head 
  (length, storage: nat * storage_v1) :
  (address * tez * timestamp) list = 
  match is_nat (storage.level - length) with
  | None -> []
  | Some start -> history_lookup ((start, length), storage)
