type t

val empty : t

val make :
  fuzzy_max_edit_distance : int ->
  ci_fuzzy : string list ->
  ci_full : string list ->
  ci_sub : string list ->
  exact : string list ->
  t

val ci_fuzzy : t -> String_set.t

val ci_full : t -> String_set.t

val ci_sub : t -> String_set.t

val exact : t -> String_set.t

val fuzzy_index : t -> Spelll.automaton list
