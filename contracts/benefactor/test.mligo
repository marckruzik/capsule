#import "main.mligo" "Benefactor"
#import "ligo-breathalyzer/lib/lib.mligo" "Breath"
#import "../util/list_ext.mligo" "ListExt"

type originated = Breath.Contract.originated
type benefactor_originated = 
  (Benefactor.entrypoint, Benefactor.storage_v1) originated

let originate (owner: Breath.Context.actor) () = 
  Breath.Contract.originate 
    Void
    "benefactor_sc"
    Benefactor.main
    { owner_address = owner.address
    ; historical_balance = 1tez
    ; level = 0n
    ; history = Big_map.empty 
    }
    1tez

let deposit (contract: benefactor_originated) (qty: tez) () = 
  Breath.Contract.transfer_to contract Deposit qty

let retreive (contract: benefactor_originated) (qty: tez) () = 
  Breath.Contract.transfer_to contract (Retreive qty) 0tez

let expect_state 
  (contract: benefactor_originated)
  (exp_balance : tez)
  (exp_owner_address : address)
  (exp_historical_balance : tez)
  (exp_level : nat)
  (exp_history : (nat * (address * tez)) list) =
    let balance = Breath.Contract.balance_of contract in
    let { owner_address; historical_balance; level; history} = 
      Breath.Contract.storage_of contract
    in
    let check_history : Breath.Result.result list = 
      List.map (fun (i, (addr, amount) : nat * (address * tez) ) ->
        Breath.Assert.is_some_and 
          "history entries" 
          (fun (sc_addr, sc_amount, _ : address * tez * timestamp) -> 
            let check_addr = Breath.Assert.is_equal "address" addr sc_addr in
            let check_amount = Breath.Assert.is_equal "amount" amount sc_amount in
            Breath.Result.and_then check_addr check_amount
          ) (Big_map.find_opt i history)
      ) exp_history
    in
    let cases = 
      ListExt.concat [
        Breath.Assert.is_equal "balance" exp_balance balance
      ; Breath.Assert.is_equal "owner" exp_owner_address owner_address
      ; Breath.Assert.is_equal "historical_balance" exp_historical_balance historical_balance
      ; Breath.Assert.is_equal "level" exp_level level
      ; Breath.Assert.is_equal "history size" (List.length exp_history) (level)
    ] check_history 
    in Breath.Result.reduce cases

let case_simple_origination =
  Breath.Model.case
    "originate contract"
    "when the contract is originate, the history should be empty"
    (fun _ -> 
      let (operator, (_alice, _bob, _carol)) = Breath.Context.init_default () in
      let sc = Breath.Context.act_as operator (originate operator) in
      expect_state sc 1tez operator.address 1tez 0n [])

let case_some_deposits =
  Breath.Model.case
    "make some deposits"
    "it should track the history"
    (fun _ -> 
      let (operator, (alice, bob, carol)) = Breath.Context.init_default () in
      let sc = Breath.Context.act_as operator (originate operator) in
      let alice_action = Breath.Context.act_as alice (deposit sc 2tez) in
      let bob_action = Breath.Context.act_as bob (deposit sc 4tez) in
      let carol_action = Breath.Context.act_as carol (deposit sc 5tez) in
      Breath.Result.reduce [
        alice_action
      ; bob_action
      ; carol_action
      ; expect_state sc 12tez operator.address 12tez 3n [
          0n, (alice.address, 2tez)
        ; 1n, (bob.address, 4tez)
        ; 2n, (carol.address, 5tez)
      ]])

let case_retreive_when_not_owner =
  Breath.Model.case
    "retreive"
    "when a not-owner try to retrive tez, it should raise an error"
    (fun _ -> 
      let (operator, (alice, _bob, _carol)) = Breath.Context.init_default () in
      let sc = Breath.Context.act_as operator (originate operator) in
      let alice_action = Breath.Context.act_as alice (retreive sc 2tez) in
      Breath.Result.reduce [
        Breath.Expect.fail_with_message 
          "You are not the owner of the benefactor wallet" 
          alice_action
      ; expect_state sc 1tez operator.address 1tez 0n []
      ])

let case_retreive_when_the_amount_is_too_high =
  Breath.Model.case
    "retreive"
    "when the requested amount is too high, it should raise an error"
    (fun _ -> 
      let (operator, (alice, _bob, _carol)) = Breath.Context.init_default () in
      let sc = Breath.Context.act_as operator (originate operator) in
      let alice_action = Breath.Context.act_as alice (deposit sc 2tez) in
      let operator_action = Breath.Context.act_as operator (retreive sc 3tez) in
      Breath.Result.reduce [
        alice_action
      ; Breath.Expect.fail_with_message 
          "The minimum balance of the contract must be [1tez]"
          operator_action
      ; expect_state sc 3tez operator.address 3tez 1n [ 
          0n, (alice.address, 2tez) 
        ]
      ])

let case_retreive =
  Breath.Model.case
    "retreive"
    "when the requested amount is valid and by the owner, it should perform the transfer"
    (fun _ -> 
      let (operator, (alice, _bob, _carol)) = Breath.Context.init_default () in
      let sc = Breath.Context.act_as operator (originate operator) in
      let alice_action = Breath.Context.act_as alice (deposit sc 5tez) in
      let operator_action = Breath.Context.act_as operator (retreive sc 3tez) in
      Breath.Result.reduce [
        alice_action
      ; operator_action
      ; expect_state sc 3tez operator.address 6tez 1n [ 
          0n, (alice.address, 5tez) 
        ]
      ])

let case_history_head_1 =
  Breath.Model.case
    "history head"
    "some computation using [history_head]"
    (fun _ -> 
      let (operator, (_alice, _bob, _carol)) = Breath.Context.init_default () in
      let sc = Breath.Context.act_as operator (originate operator) in
      let ca = sc.originated_address in
      let hd : (address * tez * timestamp) list option = 
        Tezos.call_view "history_head" 5n ca 
      in
      Breath.Result.reduce [
        Breath.Assert.is_some_and "history_head view" (fun li -> 
          Breath.Assert.is_equal "history" [] li
        ) hd
      ; expect_state sc 1tez operator.address 1tez 0n []
      ])

let suite = Breath.Model.suite "Benefactor" [
  case_simple_origination
; case_some_deposits
; case_retreive_when_not_owner
; case_retreive_when_the_amount_is_too_high
; case_retreive
; case_history_head_1
]