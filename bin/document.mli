open Docfd_lib

type t

val equal : t -> t -> bool

module Compare : sig
  val mod_time : t -> t -> int

  val path_date : t -> t -> int

  val path : t -> t -> int
end

val search_mode : t -> Search_mode.t

val path : t -> string

val path_date : t -> Timedesc.Date.t option

val mod_time : t -> Timedesc.t

val title : t -> string option

val word_ids : t -> Int_set.t

val doc_hash : t -> string

val doc_id : t -> int64

val search_scope : t -> Diet.Int.t option

val last_scan : t -> Timedesc.t

val satisfies_filter_exp :
  Task_pool.t ->
  Filter_exp.t ->
  t ->
  bool

val of_path :
  env:Eio_unix.Stdenv.base ->
  Task_pool.t ->
  already_in_transaction:bool ->
  Search_mode.t ->
  ?doc_hash:string ->
  string ->
  (t, string) result

val reset_search_scope_to_full : t -> t

val inter_search_scope : Diet.Int.t -> t -> t

module Ir0 : sig
  type t

  val of_path :
    env:Eio_unix.Stdenv.base ->
    Search_mode.t ->
    ?doc_hash:string ->
    string ->
    (t, string) result
end

module Ir1 : sig
  type t

  val of_ir0 :
    env:Eio_unix.Stdenv.base ->
    Ir0.t ->
    (t, string) result
end

module Ir2 : sig
  type t

  val of_ir1 : Task_pool.t -> Ir1.t -> t
end

val of_ir2 :
  Sqlite3.db ->
  already_in_transaction:bool ->
  Ir2.t ->
  t
