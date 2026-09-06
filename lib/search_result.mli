type found_word = [
  | `String of string
  | `Id of int
]

val string_of_found_word : found_word -> string

val string_ci_of_found_word : found_word -> string

type indexed_found_word = {
  found_word_pos : int;
  found_word : found_word;
}

type t

val make :
  Search_phrase.t ->
  found_phrase:indexed_found_word list ->
  found_phrase_opening_closing_symbol_match_count:int ->
  t

val search_phrase : t -> Search_phrase.t

val found_phrase : t -> indexed_found_word list

val score : t -> float

val equal : t -> t -> bool

val compare_relevance : t -> t -> int
