type t = {
  phrase : string list;
  fuzzy_index : Spelll.automaton list;
}

let phrase t =
  t.phrase

let is_empty (t : t) =
  t.phrase = []

let fuzzy_index t =
  t.fuzzy_index

let equal (t1 : t) (t2 : t) =
  List.equal String.equal t1.phrase t2.phrase

let make
    ~fuzzy_max_edit_distance
    ~phrase
  =
  let phrase = phrase
               |> Content_index.tokenize
               |> List.filter (fun s -> s <> "")
  in
  let fuzzy_index =
    phrase
    |> List.map (fun x -> Spelll.of_string ~limit:fuzzy_max_edit_distance x)
  in
  {
    phrase;
    fuzzy_index;
  }
