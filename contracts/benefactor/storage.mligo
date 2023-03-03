type storage_v1 = {
  owner_address: address
; historical_balance: tez
; level: nat
; history: (nat, (address * tez * timestamp)) big_map
}