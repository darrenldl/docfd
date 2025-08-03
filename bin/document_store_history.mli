type t

val make : unit -> t

val length : t -> int

val get : t -> int -> Document_store_snapshot.t

val get_last : t -> Document_store_snapshot.t

val set : t -> int -> Document_store_snapshot.t -> unit

val add_last : t -> Document_store_snapshot.t -> unit

val snapshots : t -> Document_store_snapshot.t Seq.t
