type t

val empty : t

val add : string -> t -> t * int

val word_of_index : int -> t -> string

val index_of_word : string -> t -> int
