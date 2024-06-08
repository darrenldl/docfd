type t

val pp : Format.formatter -> t -> unit

val empty : t

val is_empty : t -> bool

val max_fuzzy_edit_dist : t -> int

val flattened : t -> Search_phrase.t list

val make : max_fuzzy_edit_dist:int -> string -> t option

val equal : t -> t -> bool
