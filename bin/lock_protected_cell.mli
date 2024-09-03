type 'a t

val make : unit -> 'a t

val set : 'a t -> 'a -> unit

val unset : 'a t -> unit

val get : 'a t -> 'a option
