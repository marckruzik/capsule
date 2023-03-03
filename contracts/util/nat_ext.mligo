[@inline]
let max (x : nat) (y : nat) : nat = 
  if (x > y) then x
  else y

[@inline]
let min (x : nat) (y : nat) : nat = 
  if ( x < y) then x
  else y