open Docfd_lib

type t

val make : path:string -> t

val path : t -> string

val title : t -> string option

val index : t -> Index.t

val last_scan : t -> Timedesc.t

val of_path : env:Eio_unix.Stdenv.base -> string -> (t, string) result
