type t

val make : unit -> t

val equal : t -> t -> bool

val add : t -> string -> int

val word_of_index : t -> int -> string

val index_of_word : t -> string -> int

val encode : Buffer.t -> t -> unit

val decode : string -> int ref -> t
