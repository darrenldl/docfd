open Docfd_lib

type t

val make : Search_mode.t -> path:string -> t

val search_mode : t -> Search_mode.t

val path : t -> string

val title : t -> string option

val index : t -> Index.t

val last_scan : t -> Timedesc.t

val of_path :
  env:Eio_unix.Stdenv.base ->
  Task_pool.t ->
  Search_mode.t ->
  string ->
  (t, string) result
