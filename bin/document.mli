open Docfd_lib

type t

val make : Search_mode.t -> path:string -> t

val search_mode : t -> Search_mode.t

val path : t -> string

val title : t -> string option

val index : t -> Index.t

val search_scope : t -> Diet.Int.t

val last_scan : t -> Timedesc.t

val of_path :
  env:Eio_unix.Stdenv.base ->
  Task_pool.t ->
  Search_mode.t ->
  ?hash:string ->
  ?index:Index.t ->
  string ->
  (t, string) result

val compute_index_path :
  hash:string ->
  string option

val find_index :
  env:Eio_unix.Stdenv.base ->
  hash:string ->
  Index.t option
