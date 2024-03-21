type t = {
  phrase : string list;
  fuzzy_index : Spelll.automaton list;
}

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
    fuzzy_index = [];
  }

let make
    ~fuzzy_max_edit_dist
    phrase
  =
  let phrase = phrase
               |> Tokenize.f ~drop_spaces:true
               |> List.of_seq
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
    fuzzy_index;
  }
