type match_typ = [
  | `Fuzzy
  | `Exact
  | `Suffix
  | `Prefix
]
[@@deriving show, ord]

type match_typ_marker = [ `Exact | `Prefix | `Suffix ]
[@@deriving show, ord]

let char_of_match_typ_marker (x : match_typ_marker) =
  match x with
  | `Exact -> '\''
  | `Prefix -> '^'
  | `Suffix -> '$'

let string_of_match_typ_marker (x : match_typ_marker) =
  match x with
  | `Exact -> "\'"
  | `Prefix -> "^"
  | `Suffix -> "$"

type annotated_token = {
  data : [ `String of string | `Match_typ_marker of match_typ_marker ];
  group_id : int;
}
[@@deriving show, ord]

type ir0 = {
  data : [ `String of string | `Match_typ_marker of match_typ_marker ];
  is_linked_to_prev : bool;
  match_typ : match_typ option;
}

module Enriched_token = struct
  type t = {
    string : string;
    is_linked_to_prev : bool;
    automaton : Spelll.automaton;
    match_typ : match_typ;
  }

  let make ~string ~is_linked_to_prev automaton match_typ =
    { string; is_linked_to_prev; automaton; match_typ }

  let pp fmt (x : t) =
    Fmt.pf fmt "%s:%b:%a" x.string x.is_linked_to_prev pp_match_typ x.match_typ

  let string (t : t) =
    t.string

  let match_typ (t : t) =
    t.match_typ

  let automaton (t : t) =
    t.automaton

  let is_linked_to_prev (t : t) =
    t.is_linked_to_prev

  let equal (x : t) (y : t) =
    String.equal x.string y.string
    &&
    x.is_linked_to_prev = y.is_linked_to_prev
    &&
    x.match_typ = y.match_typ
end

type t = {
  annotated_tokens : annotated_token list;
  enriched_tokens : Enriched_token.t list;
}

let is_empty (t : t) =
  List.is_empty t.enriched_tokens

let pp fmt (t : t) =
  Fmt.pf fmt "%a"
    Fmt.(list ~sep:sp Enriched_token.pp)
    t.enriched_tokens

type cache = {
  mutex : Mutex.t;
  cache : (string, Spelll.automaton) CCCache.t;
}

let cache = {
  mutex = Mutex.create ();
  cache = CCCache.lru ~eq:String.equal Params.search_word_automaton_cache_size;
}

let compare (t1 : t) (t2 : t) =
  List.compare compare_annotated_token t1.annotated_tokens t2.annotated_tokens

let equal (t1 : t) (t2 : t) =
  compare t1 t2 = 0

let empty : t =
  {
    annotated_tokens = [];
    enriched_tokens = [];
  }

let ir0_s_of_annotated_tokens (tokens : annotated_token Seq.t) : ir0 list =
  let token_is_space (token : annotated_token) =
    match token.data with
    | `String s -> Parser_components.is_space (String.get s 0)
    | _ -> false
  in
  let rec aux acc (prev_token : annotated_token option) (tokens : annotated_token Seq.t) =
    match tokens () with
    | Seq.Nil -> List.rev acc
    | Seq.Cons (token, rest) -> (
        let is_linked_to_prev =
          match prev_token with
          | None -> false
          | Some prev_token -> (
              (prev_token.group_id = token.group_id)
              &&
              (not (token_is_space prev_token))
            )
        in
        if token_is_space token then (
          aux acc None rest
        ) else (
          let ir0 : ir0 = 
            { data = token.data;
              is_linked_to_prev;
              match_typ = None;
            }
          in
          aux (ir0 :: acc) (Some token) rest
        )
      )
  in
  aux [] None tokens

let ir0_process_exact_prefix_match_typ_markers (ir0_s : ir0 list) : ir0 list =
  let rec aux (acc : ir0 list) (marker : [ `Exact | `Prefix] option) (ir0_s : ir0 list) =
    match ir0_s with
    | [] -> List.rev acc
    | x :: xs -> (
        match marker with
        | None -> (
            match x.data with
            | `String _ ->
              aux (x :: acc) None xs
            | `Match_typ_marker m -> (
                match m with
                | `Exact | `Prefix as m -> (
                    aux acc (Some (m :> [`Exact | `Prefix ])) xs
                  )
                | `Suffix ->
                  aux (x :: acc) None xs
              )
          )
        | Some m -> (
            if x.is_linked_to_prev then (
              aux ({ x with match_typ = Some (m :> match_typ) } :: acc) marker xs
            ) else (
              aux (x :: acc) None xs
            )
          )
      )
  in
  aux [] None ir0_s

let enriched_tokens_of_ir0 (ir0_s : ir0 list) : Enriched_token.t list =
  List.map (fun (ir0 : ir0) ->
      let string =
        match ir0.data with
        | `String s -> s
        | `Match_typ_marker m -> string_of_match_typ_marker m
      in
      let is_linked_to_prev = ir0.is_linked_to_prev in
      let automaton =
        Mutex.lock cache.mutex;
        let automaton =
          CCCache.with_cache cache.cache
            (Spelll.of_string ~limit:!Params.max_fuzzy_edit_dist)
            string
        in
        Mutex.unlock cache.mutex;
        automaton
      in
      Enriched_token.make
        ~string ~is_linked_to_prev automaton (Option.value ~default:`Fuzzy ir0.match_typ)
    ) ir0_s

let of_annotated_tokens
    (annotated_tokens : annotated_token Seq.t)
  =
  let enriched_tokens =
    annotated_tokens
    |> ir0_s_of_annotated_tokens
    |> ir0_process_exact_prefix_match_typ_markers
    |> enriched_tokens_of_ir0
  in
  {
    annotated_tokens = List.of_seq annotated_tokens;
    enriched_tokens;
  }

let of_tokens
    (tokens : string Seq.t)
  =
  tokens
  |> Seq.map (fun s -> { data = `String s; group_id = 0 })
  |> of_annotated_tokens

let make phrase =
  phrase
  |> Tokenize.tokenize ~drop_spaces:false
  |> of_tokens

let enriched_tokens t =
  t.enriched_tokens

let actual_search_phrase t =
  List.map Enriched_token.string t.enriched_tokens
