type 'a t

val add : string -> 'a -> 'a t -> 'a t

val search : string -> 'a t -> 'a option
