type t = {
  ci_fuzzy_tag_matches : String_set.t;
  ci_full_tag_matches : String_set.t;
  ci_sub_tag_matches : String_set.t;
  exact_tag_matches : String_set.t;
  fuzzy_index : Spelll.automaton list;
}

let ci_fuzzy_tag_matches t =
  t.ci_fuzzy_tag_matches

let ci_full_tag_matches t =
  t.ci_full_tag_matches

let ci_sub_tag_matches t =
  t.ci_sub_tag_matches

let exact_tag_matches t =
  t.exact_tag_matches

let fuzzy_index t =
  t.fuzzy_index

let empty = {
  ci_fuzzy_tag_matches = String_set.empty;
  ci_full_tag_matches = String_set.empty;
  ci_sub_tag_matches = String_set.empty;
  exact_tag_matches = String_set.empty;
  fuzzy_index = [];
}

let make
    ~fuzzy_max_edit_distance
    ~ci_fuzzy_tag_matches
    ~ci_full_tag_matches
    ~ci_sub_tag_matches
    ~exact_tag_matches
  =
  let ci_fuzzy_tag_matches = String_set.of_list ci_fuzzy_tag_matches in
  let ci_full_tag_matches = String_set.of_list ci_full_tag_matches in
  let ci_sub_tag_matches = String_set.of_list ci_sub_tag_matches in
  let exact_tag_matches = String_set.of_list exact_tag_matches in
  let fuzzy_index =
    String_set.to_seq ci_fuzzy_tag_matches
    |> Seq.map (fun x -> Spelll.of_string ~limit:fuzzy_max_edit_distance x)
    |> List.of_seq
  in
  {
    ci_fuzzy_tag_matches;
    ci_full_tag_matches;
    ci_sub_tag_matches;
    exact_tag_matches;
    fuzzy_index;
  }
