type t = {
  ci_fuzzy : String_set.t;
  ci_full : String_set.t;
  ci_sub : String_set.t;
  exact : String_set.t;
  fuzzy_index : Spelll.automaton list;
}

let pp formatter (t : t) : unit =
  Fmt.pf formatter "@[f:[%a]@,i:[%a]@,s:[%a],e:[%a]@]"
    Fmt.(seq ~sep:sp string) (String_set.to_seq t.ci_fuzzy)
    Fmt.(seq ~sep:sp string) (String_set.to_seq t.ci_full)
    Fmt.(seq ~sep:sp string) (String_set.to_seq t.ci_sub)
    Fmt.(seq ~sep:sp string) (String_set.to_seq t.exact)

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

let equal t1 t2 =
  String_set.equal t1.ci_fuzzy t2.ci_fuzzy
  && String_set.equal t1.ci_full t2.ci_full
  && String_set.equal t1.ci_sub t2.ci_sub
  && String_set.equal t1.exact t2.exact

let make
    ~fuzzy_max_edit_distance
    ~ci_fuzzy
    ~ci_full
    ~ci_sub
    ~exact
  =
  let filter l =
    List.filter (fun s -> s <> "") l
  in
  let ci_fuzzy = ci_fuzzy |> filter |> Misc_utils.ci_string_set_of_list in
  let ci_full = ci_full |> filter |> Misc_utils.ci_string_set_of_list in
  let ci_sub = ci_sub |> filter |> Misc_utils.ci_string_set_of_list in
  let exact = exact |> filter |> String_set.of_list in
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
