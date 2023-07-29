type t

val make : unit -> t

val signal : t -> unit

val await : t -> unit
