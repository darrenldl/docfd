open Docfd_lib

type t

val search_mode : t -> Search_mode.t

val path : t -> string

val title : t -> string option

val doc_hash : t -> string

val search_scope : t -> Diet.Int.t option

val last_scan : t -> Timedesc.t

val of_path :
  env:Eio_unix.Stdenv.base ->
  Task_pool.t ->
  Search_mode.t ->
  ?doc_hash:string ->
  string ->
  (t, string) result

val inter_search_scope : Diet.Int.t -> t -> t

type ir

val ir_of_path :
  env:Eio_unix.Stdenv.base ->
  Search_mode.t ->
  ?doc_hash:string ->
  string ->
  (ir, string) result

val of_ir : Task_pool.t -> ir -> t
