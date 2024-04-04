open Docfd_lib

type search_mode = [
  | `Single_line
  | `Multiline
]

type t

val make : search_mode -> path:string -> t

val search_mode : t -> search_mode

val path : t -> string

val title : t -> string option

val index : t -> Index.t

val last_scan : t -> Timedesc.t

val of_path :
  env:Eio_unix.Stdenv.base ->
  Task_pool.t ->
  search_mode ->
  string ->
  (t, string) result
