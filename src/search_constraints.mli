type t

val empty : t

val make :
  fuzzy_max_edit_distance : int ->
  ci_fuzzy_tag_matches : string list ->
  ci_full_tag_matches : string list ->
  ci_sub_tag_matches : string list ->
  exact_tag_matches : string list ->
  t

val ci_fuzzy_tag_matches : t -> String_set.t

val ci_full_tag_matches : t -> String_set.t

val ci_sub_tag_matches : t -> String_set.t

val exact_tag_matches : t -> String_set.t

val fuzzy_index : t -> Spelll.automaton list
