type t

val of_mutez : Z.t -> t
val of_nanotez : Z.t -> t
val zero : t
val pp : Format.formatter -> t -> unit
val to_string : t -> string
val encoding : t Data_encoding.t
