type t = {
  fuzzy_max_edit_distance : int;
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
  t1.fuzzy_max_edit_distance = t2.fuzzy_max_edit_distance 
  &&
  List.equal String.equal t1.phrase t2.phrase

let make
    ~fuzzy_max_edit_distance
    ~phrase
  =
  let phrase = phrase
               |> Tokenize.f ~drop_spaces:true
               |> List.of_seq
  in
  let fuzzy_index =
    phrase
    |> List.map (fun x -> Spelll.of_string ~limit:fuzzy_max_edit_distance x)
  in
  {
    fuzzy_max_edit_distance;
    phrase;
    fuzzy_index;
  }
