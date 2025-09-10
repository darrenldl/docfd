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
  data : [
    | `String of string
    | `Match_typ_marker of match_typ_marker
    | `Explicit_spaces
  ];
  group_id : int;
}
[@@deriving show]

type ir0 = {
  data : [
    | `String of string
    | `Match_typ_marker of match_typ_marker
    | `Explicit_spaces
  ];
  is_linked_to_prev : bool;
  is_linked_to_next : bool;
  match_typ : match_typ option;
}

module Enriched_token = struct
  type data = [ `String of string | `Explicit_spaces ]
  [@@deriving ord]

  module Data_map = Map.Make (struct
      type t = data

      let compare = compare_data
    end)

  let pp_data formatter data =
    Fmt.pf formatter "%s"
      (match data with
       | `String s -> s
       | `Explicit_spaces -> " ")

  type t = {
    data : data;
    is_linked_to_prev : bool;
    is_linked_to_next : bool;
    automaton : Spelll.automaton;
    match_typ : match_typ;
  }

  let make data ~is_linked_to_prev ~is_linked_to_next automaton match_typ =
    { data; is_linked_to_prev; is_linked_to_next; automaton; match_typ }

  let pp fmt (x : t) =
    Fmt.pf fmt "%a:%b:%b:%a"
      pp_data
      x.data
      x.is_linked_to_prev
      x.is_linked_to_next
      pp_match_typ
      x.match_typ

  let data (t : t) =
    t.data

  let match_typ (t : t) =
    t.match_typ

  let automaton (t : t) =
    t.automaton

  let is_linked_to_prev (t : t) =
    t.is_linked_to_prev

  let is_linked_to_next (t : t) =
    t.is_linked_to_next

  let compare (x : t) (y : t) =
    match compare_data x.data y.data with
    | 0 -> (
        match Bool.compare x.is_linked_to_prev y.is_linked_to_prev with
        | 0 -> (
            match Bool.compare x.is_linked_to_next y.is_linked_to_next with
            | 0 -> (
                compare_match_typ x.match_typ y.match_typ
              )
            | n -> n
          )
        | n -> n
      )
    | n -> n

  let equal (x : t) (y : t) =
    compare x y = 0

  let compatible_with_word (token : t) indexed_word =
    String.length indexed_word > 0
    &&
    (match data token with
     | `Explicit_spaces -> (
         Parser_components.is_space indexed_word.[0]
       )
     | `String search_word -> (
         let search_word_ci = String.lowercase_ascii search_word in
         let indexed_word_ci = String.lowercase_ascii indexed_word in
         let use_ci_match = String.equal search_word search_word_ci in
         let indexed_word_len = String.length indexed_word in
         if Parser_components.is_possibly_utf_8 indexed_word.[0] then (
           String.equal search_word indexed_word
         ) else (
           match match_typ token with
           | `Fuzzy -> (
               String.equal search_word_ci indexed_word_ci
               || CCString.find ~sub:search_word_ci indexed_word_ci >= 0
               || (indexed_word_len >= 2
                   && CCString.find ~sub:indexed_word_ci search_word_ci >= 0)
               || (Misc_utils.first_n_chars_of_string_contains ~n:5 indexed_word_ci search_word_ci.[0]
                   && Spelll.match_with (automaton token) indexed_word_ci)
             )
           | `Exact -> (
               if use_ci_match then (
                 String.equal search_word_ci indexed_word_ci
               ) else (
                 String.equal search_word indexed_word
               )
             )
           | `Prefix -> (
               if use_ci_match then (
                 CCString.prefix ~pre:search_word_ci indexed_word_ci
               ) else (
                 CCString.prefix ~pre:search_word indexed_word
               )
             )
           | `Suffix -> (
               if use_ci_match then (
                 CCString.suffix ~suf:search_word_ci indexed_word_ci
               ) else (
                 CCString.suffix ~suf:search_word indexed_word
               )
             )
         )
       )
    )
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
  mutex : Eio.Mutex.t;
  cache : (string, Spelll.automaton) CCCache.t;
}

let cache = {
  mutex = Eio.Mutex.create ();
  cache = CCCache.lru ~eq:String.equal Params.search_word_automaton_cache_size;
}

let compare (t1 : t) (t2 : t) =
  List.compare Enriched_token.compare t1.enriched_tokens t2.enriched_tokens

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
              is_linked_to_next = false;
              match_typ = None;
            }
          in
          aux (ir0 :: acc) (Some token) rest
        )
      )
  in
  aux [] None tokens

let ir0_s_link_forward (ir0_s : ir0 list) : ir0 list =
  List.rev ir0_s
  |> List.fold_left (fun (acc, next) x ->
      match next with
      | None -> (x :: acc, Some x)
      | Some next -> (
          let x = { x with is_linked_to_next = next.is_linked_to_prev } in
          (x :: acc, Some x)
        )
    )
    ([], None)
  |> fst

let ir0_process_exact_prefix_match_typ_markers (ir0_s : ir0 list) : ir0 list =
  let rec aux
      (acc : ir0 list)
      token_removed
      (marker : ([ `Exact ] * [ `Exact | `Prefix ]) option)
      (ir0_s : ir0 list)
    =
    match ir0_s with
    | [] -> List.rev acc
    | x :: xs -> (
        match marker with
        | None -> (
            let default () =
              aux (x :: acc) false None xs
            in
            match x.data with
            | `String _ | `Explicit_spaces ->
              default ()
            | `Match_typ_marker m -> (
                match x.match_typ with
                | None -> (
                    if x.is_linked_to_next then (
                      match m with
                      | `Exact ->
                        aux acc true (Some (`Exact, `Exact)) xs
                      | `Prefix ->
                        aux acc true (Some (`Exact, `Prefix)) xs
                      | _ ->
                        default ()
                    ) else (
                      default ()
                    )
                  )
                | Some _ ->
                  default ()
              )
          )
        | Some (m, m_last) -> (
            let x =
              if x.is_linked_to_prev then (
                { x with
                  is_linked_to_prev = not token_removed;
                  match_typ = Some (
                      if x.is_linked_to_next then
                        (m :> match_typ)
                      else
                        (m_last :> match_typ)
                    );
                }
              ) else (
                x
              )
            in
            let marker =
              if x.is_linked_to_next then
                marker
              else
                None
            in
            aux (x :: acc) false marker xs
          )
      )
  in
  aux [] false None ir0_s

let ir0_process_suffix_match_typ_markers (ir0_s : ir0 list) : ir0 list =
  let rec aux
      (acc : ir0 list)
      token_removed
      (marker : ([ `Suffix ] * [ `Exact ]) option)
      (ir0_s : ir0 list)
    =
    match ir0_s with
    | [] -> acc
    | x :: xs -> (
        match marker with
        | None -> (
            let default () =
              aux (x :: acc) false None xs
            in
            match x.data with
            | `String _ | `Explicit_spaces ->
              default ()
            | `Match_typ_marker m -> (
                match x.match_typ with
                | None -> (
                    if x.is_linked_to_prev then (
                      match m with
                      | `Suffix ->
                        aux acc true (Some (`Suffix, `Exact)) xs
                      | _ ->
                        default ()
                    ) else (
                      default ()
                    )
                  )
                | Some _ ->
                  default ()
              )
          )
        | Some (m_first, m) -> (
            let x =
              if x.is_linked_to_next then (
                { x with
                  is_linked_to_next = not token_removed;
                  match_typ = Some (
                      if x.is_linked_to_prev then
                        (m :> match_typ)
                      else
                        (m_first :> match_typ)
                    );
                }
              ) else (
                x
              )
            in
            let marker =
              if x.is_linked_to_prev then
                marker
              else
                None
            in
            aux (x :: acc) false marker xs
          )
      )
  in
  aux [] false None (List.rev ir0_s)

let enriched_tokens_of_ir0 (ir0_s : ir0 list) : Enriched_token.t list =
  List.map (fun (ir0 : ir0) ->
      let data =
        match ir0.data with
        | `String s -> `String s
        | `Match_typ_marker m ->
          `String (string_of_match_typ_marker m)
        | `Explicit_spaces -> `Explicit_spaces
      in
      let is_linked_to_prev = ir0.is_linked_to_prev in
      let is_linked_to_next = ir0.is_linked_to_next in
      let automaton =
        match data with
        | `String string -> (
            Eio.Mutex.use_rw cache.mutex ~protect:false (fun () ->
                let automaton =
                  CCCache.with_cache cache.cache
                    (Spelll.of_string ~limit:!Params.max_fuzzy_edit_dist)
                    string
                in
                automaton
              )
          )
        | `Explicit_spaces ->
          Spelll.of_string ~limit:0 ""
      in
      Enriched_token.make
        data
        ~is_linked_to_prev
        ~is_linked_to_next
        automaton
        (Option.value ~default:`Fuzzy ir0.match_typ)
    ) ir0_s

let of_annotated_tokens
    (annotated_tokens : annotated_token Seq.t)
  =
  let enriched_tokens =
    annotated_tokens
    |> ir0_s_of_annotated_tokens
    |> ir0_s_link_forward
    |> ir0_process_exact_prefix_match_typ_markers
    |> ir0_process_suffix_match_typ_markers
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

let parse phrase =
  phrase
  |> Tokenization.tokenize ~drop_spaces:false
  |> of_tokens

let annotated_tokens t =
  t.annotated_tokens

let enriched_tokens t =
  t.enriched_tokens
