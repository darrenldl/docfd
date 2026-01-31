type t

val add : string -> int

val filter : Task_pool.t -> (string -> bool) -> (int * string) Dynarray.t

val word_of_id : int -> string

val id_of_word : string -> int option

val read_from_db : unit -> unit

val write_to_db : Sqlite3.db -> already_in_transaction:bool -> unit
