type t

val size : int

val make : sw:Eio.Switch.t -> _ Eio.Domain_manager.t -> t

val run : t -> (unit -> 'a) -> 'a

val map_list : t -> ('a -> 'b) -> 'a list -> 'b list

val filter_list : t -> ('a -> bool) -> 'a list -> 'a list

val filter_map_list : t -> ('a -> 'b option) -> 'a list -> 'b list
