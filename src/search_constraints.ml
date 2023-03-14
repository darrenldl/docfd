type t = {
  ci_fuzzy : String_set.t;
  ci_full : String_set.t;
  ci_sub : String_set.t;
  exact : String_set.t;
  fuzzy_index : Spelll.automaton list;
}

let ci_fuzzy t =
  t.ci_fuzzy

let ci_full t =
  t.ci_full

let ci_sub t =
  t.ci_sub

let exact t =
  t.exact

let fuzzy_index t =
  t.fuzzy_index

let empty = {
  ci_fuzzy = String_set.empty;
  ci_full = String_set.empty;
  ci_sub = String_set.empty;
  exact = String_set.empty;
  fuzzy_index = [];
}

let is_empty (t : t) =
  String_set.is_empty t.ci_fuzzy
  && String_set.is_empty t.ci_full
  && String_set.is_empty t.ci_sub
  && String_set.is_empty t.exact

let make
    ~fuzzy_max_edit_distance
    ~ci_fuzzy
    ~ci_full
    ~ci_sub
    ~exact
  =
  let ci_fuzzy = String_set.of_list ci_fuzzy in
  let ci_full = String_set.of_list ci_full in
  let ci_sub = String_set.of_list ci_sub in
  let exact = String_set.of_list exact in
  let fuzzy_index =
    String_set.to_seq ci_fuzzy
    |> Seq.map (fun x -> Spelll.of_string ~limit:fuzzy_max_edit_distance x)
    |> List.of_seq
  in
  {
    ci_fuzzy;
    ci_full;
    ci_sub;
    exact;
    fuzzy_index;
  }
