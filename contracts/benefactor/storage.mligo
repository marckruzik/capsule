type storage_v1 = [@layout:comb] {
  owner_address: address
; historical_balance: tez
; level: nat
; history: (nat, (address * tez * timestamp)) big_map
}

let init : storage_v1  = {
  owner_address = ("tz1gptNykuiTaYvGECzLNPDbZ9ybcQxwHhD4" : address)
; historical_balance = 0tez
; level = 0n
; history = Big_map.empty
}