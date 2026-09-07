type matched_word = {
  pos : int;
  word : string;
}

type t

val make :
  Search_phrase.t ->
  found_phrase:matched_word list ->
  found_phrase_opening_closing_symbol_match_count:int ->
  t

val search_phrase : t -> Search_phrase.t

val found_phrase : t -> matched_word list

val score : t -> float

val equal : t -> t -> bool

val compare_relevance : t -> t -> int
