type t =
  | ENDORSEMENT
  | SEED_NONCE_REVELATION
  | DOUBLE_ENDORSEMENT_EVIDENCE
  | DOUBLE_BAKING_EVIDENCE
  | ACTIVATE_ACCOUNT
  | PROPOSALS
  | BALLOT
  | REVEAL
  | TRANSACTION
  | ORIGINATION
  | DELEGATION

val to_string : t -> string
val from_string : string -> t option
val tag : t -> int
