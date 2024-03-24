type t = {
  phrase : string list;
  has_space_before : bool list;
  fuzzy_index : Spelll.automaton list;
}

type enriched_token = {
  string : string;
  has_space_before : bool;
  automaton : Spelll.automaton;
}

let to_enriched_tokens (t : t) : enriched_token list =
        List.combine
        (List.combine t.phrase t.has_space_before)
        t.fuzzy_index
              |> List.map (fun ((string, has_space_before), automaton) ->
                  { string; has_space_before; automaton })

let pp formatter (t : t) =
  Fmt.pf formatter "%a" Fmt.(list ~sep:sp string) t.phrase

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

let equal (t1 : t) (t2 : t) =
  List.equal String.equal t1.phrase t2.phrase

let compare (t1 : t) (t2 : t) =
  List.compare String.compare t1.phrase t2.phrase

let empty : t =
  {
    phrase = [];
    has_space_before = [];
    fuzzy_index = [];
  }

let make
    ~fuzzy_max_edit_dist
    phrase
  =
  let process_tokens
  (phrase : string Seq.t) =
    let rec aux word_acc has_space_before_acc has_space_before phrase =
    match phrase () with
    | Seq.Nil -> (List.rev word_acc, List.rev has_space_before_acc)
    | Seq.Cons (word, rest) -> (
      if Parser_components.is_space (String.get word 0) then (
        aux word_acc has_space_before_acc true rest
      ) else (
        aux (word :: word_acc) (has_space_before :: has_space_before_acc) false rest
      )
    )
    in
    aux [] [] false phrase
  in
  let phrase, has_space_before =
    phrase
               |> Tokenize.f ~drop_spaces:true
               |> process_tokens
  in
  let fuzzy_index =
    phrase
    |> List.map (fun x ->
        Mutex.lock cache.mutex;
        let dfa =
          CCCache.with_cache cache.cache
            (Spelll.of_string ~limit:fuzzy_max_edit_dist)
            x
        in
        Mutex.unlock cache.mutex;
        dfa
      )
  in
  {
    phrase;
    has_space_before;
    fuzzy_index;
  }
