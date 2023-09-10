val run : (unit -> 'a) -> 'a

val map_list : ('a -> 'b) -> 'a list -> 'b list

val filter_list : ('a -> bool) -> 'a list -> 'a list

val filter_map_list : ('a -> 'b option) -> 'a list -> 'b list
