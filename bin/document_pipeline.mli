type t

val make : env:Eio_unix.Stdenv.base -> Docfd_lib.Task_pool.t -> Document.Ir0.t Seq.t -> t

val run : document_sizes:int String_map.t -> report_progress:(int -> unit) -> t -> unit

val finalize : t -> Document.t list
