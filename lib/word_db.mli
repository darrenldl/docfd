type t

val make : unit -> t

val add : t -> string -> int

val word_of_index : t -> int -> string

val index_of_word : t -> string -> int

val to_json : t -> Yojson.Safe.t

val of_json : Yojson.Safe.t -> t option
