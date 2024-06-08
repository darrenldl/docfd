type match_typ = [
  | `Fuzzy
  | `Exact
  | `Suffix
  | `Prefix
]

type annotated_token = {
  string : string;
  group_id : int;
  match_typ : match_typ;
}

module Enriched_token : sig
  type t

  val make :
    string:string ->
    is_linked_to_prev:bool ->
    Spelll.automaton ->
    match_typ ->
    t

  val string : t -> string

  val equal : t -> t -> bool

  val pp : Format.formatter -> t -> unit

  val match_typ : t -> match_typ

  val is_linked_to_prev : t -> bool

  val automaton : t -> Spelll.automaton
end

type t

val empty : t

val compare : t -> t -> int

val equal : t -> t -> bool

val pp : Format.formatter -> t -> unit

val of_annotated_tokens : max_fuzzy_edit_dist:int -> annotated_token Seq.t -> t

val of_tokens : max_fuzzy_edit_dist:int -> string Seq.t -> t

val make : max_fuzzy_edit_dist:int -> string -> t

val is_empty : t -> bool

val fuzzy_index : t -> Spelll.automaton list

val actual_search_phrase : t -> string list

val enriched_tokens : t -> Enriched_token.t list
