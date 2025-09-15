type t

val add : string -> int

val add_word_id_doc_id_link : word_id:int -> doc_id:int64 -> unit

val filter : Task_pool.t -> (string -> bool) -> Int_set.t

val doc_ids_of_word_id : word_id:int -> CCBV.t

val word_of_index : int -> string

val index_of_word : string -> int

val read_from_db : unit -> unit

val write_to_db : Sqlite3.db -> already_in_transaction:bool -> unit
