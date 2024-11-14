type t

val last_command : t -> Command.t option

val store : t -> Document_store.t

val id : t -> int

val equal_id : t -> t -> bool

val make : last_command:Command.t option -> Document_store.t -> t

val make_empty : unit -> t

val update_store : Document_store.t -> t -> t
