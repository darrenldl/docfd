type t

val add : string -> int

val filter : Task_pool.t -> (string -> bool) -> Int_set.t

val word_of_index : int -> string

val index_of_word : string -> int

val read_from_db : unit -> unit

val write_to_db : unit -> unit
