type t = {
  phrase : string list;
  is_linked_to_prev : bool list;
  fuzzy_index : Spelll.automaton list;
}

type annotated_token = {
  string : string;
  group_id : int;
}

type enriched_token = {
  string : string;
  is_linked_to_prev : bool;
  automaton : Spelll.automaton;
}

let pp_enriched_token fmt (x : enriched_token) =
  Fmt.pf fmt "%s:%b" x.string x.is_linked_to_prev

let equal_enriched_token (x : enriched_token) (y : enriched_token) =
  String.equal x.string y.string
  &&
  x.is_linked_to_prev = y.is_linked_to_prev

let to_enriched_tokens (t : t) : enriched_token list =
  List.combine
    (List.combine t.phrase t.is_linked_to_prev)
    t.fuzzy_index
  |> List.map (fun ((string, is_linked_to_prev), automaton) ->
      { string; is_linked_to_prev; automaton })

let pp fmt (t : t) =
  Fmt.pf fmt "%a"
    Fmt.(list ~sep:sp pp_enriched_token)
    (to_enriched_tokens t)

type cache = {
  mutex : Mutex.t;
  cache : (string, Spelll.automaton) CCCache.t;
}

let cache = {
  mutex = Mutex.create ();
  cache = CCCache.lru ~eq:String.equal Params.search_word_automaton_cache_size;
}

let phrase t =
  t.phrase

let is_empty (t : t) =
  t.phrase = []

let fuzzy_index t =
  t.fuzzy_index

let compare (t1 : t) (t2 : t) =
  match List.compare String.compare t1.phrase t2.phrase with
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
    phrase = [];
    is_linked_to_prev = [];
    fuzzy_index = [];
  }

type token_process_ctx = {
  prev_was_space : bool;
  prev_group_id : int;
}

let of_annotated_tokens
    ~max_fuzzy_edit_dist
    (tokens : annotated_token Seq.t)
  =
  let token_is_space (token : annotated_token) =
    Parser_components.is_space (String.get token.string 0)
  in
  let process_tokens
      (phrase : annotated_token Seq.t) =
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
  in
  let phrase, is_linked_to_prev = process_tokens tokens in
  let fuzzy_index =
    phrase
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
    phrase;
    is_linked_to_prev;
    fuzzy_index;
  }

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
