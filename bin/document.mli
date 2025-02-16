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

val of_ir1 : Task_pool.t -> Ir1.t -> t
