type t

val add : string -> int

val word_of_index : int -> string

val index_of_word : string -> int

val read_from_db : db:Sqlite3.db -> unit

val write_to_db : db:Sqlite3.db -> unit
