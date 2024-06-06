type match_typ = [
  | `Fuzzy
  | `Exact
  | `Suffix
  | `Prefix
]

type annotated_token = {
  string : string;
  group_id : int;
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
    Fmt.pf fmt "%s:%b" x.string x.is_linked_to_prev

  let string (t : t) =
    t.string

  let match_typ t =
    t.match_typ

  let automaton t =
    t.automaton

  let is_linked_to_prev t =
    t.is_linked_to_prev

  let equal (x : t) (y : t) =
    String.equal x.string y.string
    &&
    x.is_linked_to_prev = y.is_linked_to_prev
end

type t = {
  raw_phrase : string list;
  enriched_tokens : Enriched_token.t list;
  is_linked_to_prev : bool list;
  fuzzy_index : Spelll.automaton list;
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

let fuzzy_index t =
  t.fuzzy_index

let compare (t1 : t) (t2 : t) =
  match List.compare String.compare t1.raw_phrase t2.raw_phrase with
  | 0 -> (
      match t1.is_linked_to_prev, t2.is_linked_to_prev with
      | [], [] -> 0
      | _ :: xs, _ :: ys -> List.compare Bool.compare xs ys
      | xs, ys -> List.compare Bool.compare xs ys
    )
  | n -> n

let equal (t1 : t) (t2 : t) =
  compare t1 t2 = 0

let empty : t =
  {
    raw_phrase = [];
    is_linked_to_prev = [];
    fuzzy_index = [];
    enriched_tokens = [];
  }

let process_tokens
    (phrase : annotated_token Seq.t)
  : string list * bool list =
  let token_is_space (token : annotated_token) =
    Parser_components.is_space (String.get token.string 0)
  in
  let rec aux
      word_acc
      is_linked_to_prev_acc
      (prev_token : annotated_token option)
      (phrase : annotated_token Seq.t) =
    match phrase () with
    | Seq.Nil -> (List.rev word_acc, List.rev is_linked_to_prev_acc)
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
          aux
            word_acc
            is_linked_to_prev_acc
            (Some token)
            rest
        ) else (
          aux
            (token.string :: word_acc)
            (is_linked_to_prev :: is_linked_to_prev_acc)
            (Some token)
            rest
        )
      )
  in
  aux [] [] None phrase

let add_enriched_tokens (t : t) : t =
  let rec aux acc (l : Enriched_token.t list) =
    match l with
    | [] -> List.rev acc
    | x0 :: xs when List.mem x0.string [ "'"; "^" ] -> (
        let match_typ =
          match x0.string with
          | "'" -> `Exact
          | "^" -> `Prefix
          | _ -> failwith "unexpected case"
        in
        match xs with
        | [] -> aux acc xs
        | x1 :: xs -> (
            if x1.is_linked_to_prev then
              aux ({x1 with match_typ} :: acc) xs
            else
              aux (x1 :: acc) xs
          )
      )
    | x :: xs when x.string = "$" -> (
        match acc with
        | [] -> aux acc xs
        | y :: ys -> (
            if x.is_linked_to_prev then
              aux ({y with match_typ = `Suffix} :: ys) xs
            else
              aux acc xs
          )
      )
    | x :: xs -> (
        aux (x :: acc) xs
      )
  in
  let enriched_tokens =
    List.combine
      (List.combine t.raw_phrase t.is_linked_to_prev)
      t.fuzzy_index
    |> List.map (fun ((string, is_linked_to_prev), automaton) ->
        Enriched_token.make ~string ~is_linked_to_prev automaton `Fuzzy)
    |> aux []
  in
  { t with enriched_tokens }

let of_annotated_tokens
    ~max_fuzzy_edit_dist
    (tokens : annotated_token Seq.t)
  =
  let raw_phrase, is_linked_to_prev = process_tokens tokens in
  let fuzzy_index =
    raw_phrase
    |> List.map (fun x ->
        Mutex.lock cache.mutex;
        let automaton =
          CCCache.with_cache cache.cache
            (Spelll.of_string ~limit:max_fuzzy_edit_dist)
            x
        in
        Mutex.unlock cache.mutex;
        automaton
      )
  in
  {
    raw_phrase;
    is_linked_to_prev;
    fuzzy_index;
    enriched_tokens = [];
  }
  |> add_enriched_tokens

let of_tokens
    ~max_fuzzy_edit_dist
    (tokens : string Seq.t)
  =
  tokens
  |> Seq.map (fun string -> { string; group_id = 0 })
  |> of_annotated_tokens ~max_fuzzy_edit_dist

let make ~max_fuzzy_edit_dist phrase =
  phrase
  |> Tokenize.tokenize ~drop_spaces:false
  |> of_tokens ~max_fuzzy_edit_dist

let enriched_tokens t =
  t.enriched_tokens

let actual_search_phrase t =
  List.map Enriched_token.string t.enriched_tokens
