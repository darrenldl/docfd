type indexed_found_word = {
  found_word_pos : int;
  found_word_ci : string;
  found_word : string;
}

type t

val make : search_phrase:string list -> found_phrase:indexed_found_word list -> t

val search_phrase : t -> string list

val found_phrase : t -> indexed_found_word list

val score : t -> float

val equal : t -> t -> bool

val compare : t -> t -> int

val compare_rev : t -> t -> int
