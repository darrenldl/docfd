type t

val make : search_phrase:string list -> found_phrase:(int * string * string) list -> t

val search_phrase : t -> string list

val found_phrase : t -> (int * string * string) list

val score : t -> float

val compare : t -> t -> int
