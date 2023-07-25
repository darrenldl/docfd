type t

val empty : t

val add : string -> t -> t * int

val word_of_index : int -> t -> string

val index_of_word : string -> t -> int

val to_json : t -> Yojson.Safe.t

val of_json : Yojson.Safe.t -> t option
