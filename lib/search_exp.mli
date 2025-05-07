type t

val pp : Format.formatter -> t -> unit

val empty : t

val is_empty : t -> bool

val flattened : t -> Search_phrase.t list

val parse : string -> t option

val equal : t -> t -> bool
