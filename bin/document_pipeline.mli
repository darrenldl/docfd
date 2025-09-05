type t

val make : env:Eio_unix.Stdenv.base -> Docfd_lib.Task_pool.t -> t

val feed : t -> Search_mode.t -> doc_hash:string -> string -> unit

val run : t -> unit

val finalize : t -> Document.t list
