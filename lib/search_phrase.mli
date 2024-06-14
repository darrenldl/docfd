type match_typ = [
  | `Fuzzy
  | `Exact
  | `Suffix
  | `Prefix
]
[@@deriving show, ord]

type match_typ_marker = [ `Exact | `Prefix | `Suffix ]
[@@deriving show]

type annotated_token = {
  data : [ `String of string | `Match_typ_marker of match_typ_marker ];
  group_id : int;
}
[@@deriving show]

module Enriched_token : sig
  type t

  val make :
    string:string ->
    is_linked_to_prev:bool ->
    is_linked_to_next:bool ->
    Spelll.automaton ->
    match_typ ->
    t

  val string : t -> string

  val equal : t -> t -> bool

  val pp : Format.formatter -> t -> unit

  val match_typ : t -> match_typ

  val is_linked_to_prev : t -> bool

  val is_linked_to_next : t -> bool

  val automaton : t -> Spelll.automaton
end

type t

val empty : t

val compare : t -> t -> int

val equal : t -> t -> bool

val pp : Format.formatter -> t -> unit

val of_annotated_tokens : annotated_token Seq.t -> t

val of_tokens : string Seq.t -> t

val make : string -> t

val is_empty : t -> bool

val actual_search_phrase_strings : t -> string list

val annotated_tokens : t -> annotated_token list

val enriched_tokens : t -> Enriched_token.t list
