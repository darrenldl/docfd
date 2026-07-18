val close_db : unit -> unit

val with_db : (Sqlite3.db -> 'a) -> 'a

val exec : Sqlite3.db -> string -> unit

val with_stmt : Sqlite3.db -> string -> ?names:((string * Sqlite3.Data.t) list) -> (Sqlite3.stmt -> 'a) -> 'a

val step_stmt : Sqlite3.db -> string -> ?names:((string * Sqlite3.Data.t) list) -> (Sqlite3.stmt -> 'a) -> 'a

val iter_stmt : Sqlite3.db -> string -> ?names:((string * Sqlite3.Data.t) list) -> (Sqlite3.Data.t array -> unit) -> unit

val fold_stmt : Sqlite3.db -> string -> ?names:((string * Sqlite3.Data.t) list) -> ('a -> Sqlite3.Data.t array -> 'a) -> 'a -> 'a

module Stmt : sig
  val bind_names : Sqlite3.stmt -> (string * Sqlite3.Data.t) list -> unit

  val reset : Sqlite3.stmt -> unit

  val step : Sqlite3.stmt -> unit

  val iter : Sqlite3.stmt -> (Sqlite3.Data.t array -> unit) -> unit

  val finalize : Sqlite3.stmt -> unit

val column_int64 : Sqlite3.stmt -> int -> int64

val column_int : Sqlite3.stmt -> int -> int

val column_text : Sqlite3.stmt -> int -> string

val data_count : Sqlite3.stmt -> int
end

module Data = Sqlite3.Data

module Rc = Sqlite3.Rc
