type indexed_found_word = {
  found_word_pos : int;
  found_word_ci : string;
  found_word : string;
}

type t = {
  search_phrase : string list;
  found_phrase : indexed_found_word list;
}

let equal t1 t2 =
  List.length t1.search_phrase = List.length t2.search_phrase
  && List.for_all2 String.equal t1.search_phrase t2.search_phrase
  && List.length t1.found_phrase = List.length t2.found_phrase
  && List.for_all2 (fun x1 x2 -> x1.found_word_pos = x2.found_word_pos)
    t1.found_phrase t2.found_phrase

type stats = {
  total_search_char_count : float;
  total_found_char_count : float;
  exact_match_found_char_count : float;
  ci_exact_match_found_char_count : float;
  sub_match_overlap_char_count : float;
  sub_match_total_char_count : float;
  ci_sub_match_overlap_char_count : float;
  ci_sub_match_total_char_count : float;
  fuzzy_match_edit_distance : float;
  fuzzy_match_search_char_count : float;
  fuzzy_match_found_char_count : float;
}

let empty_stats = {
  total_search_char_count = 0.0;
  total_found_char_count = 0.0;
  exact_match_found_char_count = 0.0;
  ci_exact_match_found_char_count = 0.0;
  sub_match_overlap_char_count = 0.0;
  sub_match_total_char_count = 0.0;
  ci_sub_match_overlap_char_count = 0.0;
  ci_sub_match_total_char_count = 0.0;
  fuzzy_match_edit_distance = 0.0;
  fuzzy_match_search_char_count = 0.0;
  fuzzy_match_found_char_count = 0.0;
}

let make ~search_phrase ~found_phrase =
  let len = List.length search_phrase in
  if len = 0 then
    invalid_arg "Search_phrase is empty"
  else
  if len <> List.length found_phrase then
    invalid_arg "Length of found_phrase does not match length of search_phrase"
  else
    { search_phrase; found_phrase }

let search_phrase (t : t) =
  t.search_phrase

let found_phrase (t : t) =
  t.found_phrase

let score (t : t) : float =
  assert (match t.search_phrase with [] -> false | _ -> true);
  assert (List.length t.search_phrase = List.length t.found_phrase);
  let quite_close_to_zero x =
    -0.01 < x && x < 0.01
  in
  let stats =
    List.fold_left2 (fun (stats : stats) search_word { found_word_ci; found_word; _ } ->
        let search_word_len = Int.to_float (String.length search_word) in
        let found_word_len = Int.to_float (String.length found_word) in
        let search_word_ci = String.lowercase_ascii search_word in
        let stats =
          { stats with
            total_search_char_count =
              stats.total_search_char_count +. search_word_len;
            total_found_char_count =
              stats.total_found_char_count +. found_word_len;
          }
        in
        if String.equal search_word found_word then (
          { stats with
            exact_match_found_char_count =
              stats.exact_match_found_char_count +. found_word_len;
          }
        ) else if String.equal search_word_ci found_word_ci then (
          { stats with
            ci_exact_match_found_char_count =
              stats.ci_exact_match_found_char_count +. found_word_len;
          }
        ) else if CCString.find ~sub:search_word found_word >= 0 then (
          { stats with
            sub_match_overlap_char_count =
              stats.sub_match_overlap_char_count +. search_word_len;
            sub_match_total_char_count =
              stats.sub_match_total_char_count +. search_word_len +. found_word_len;
          }
        ) else if CCString.find ~sub:found_word search_word >= 0 then (
          { stats with
            sub_match_overlap_char_count =
              stats.sub_match_overlap_char_count +. found_word_len;
            sub_match_total_char_count =
              stats.sub_match_total_char_count +. search_word_len +. found_word_len;
          }
        ) else if CCString.find ~sub:search_word_ci found_word_ci >= 0 then (
          { stats with
            ci_sub_match_overlap_char_count =
              stats.ci_sub_match_overlap_char_count +. search_word_len;
            ci_sub_match_total_char_count =
              stats.ci_sub_match_total_char_count +. search_word_len +. found_word_len;
          }
        ) else if CCString.find ~sub:found_word_ci search_word_ci >= 0 then (
          { stats with
            ci_sub_match_overlap_char_count =
              stats.ci_sub_match_overlap_char_count +. found_word_len;
            ci_sub_match_total_char_count =
              stats.ci_sub_match_total_char_count +. search_word_len +. found_word_len;
          }
        ) else (
          { stats with
            fuzzy_match_edit_distance =
              stats.fuzzy_match_edit_distance
              +. Int.to_float (Spelll.edit_distance search_word_ci found_word_ci);
            fuzzy_match_search_char_count =
              stats.fuzzy_match_search_char_count +. search_word_len;
            fuzzy_match_found_char_count =
              stats.fuzzy_match_found_char_count +. found_word_len;
          }
        )
      )
      empty_stats
      t.search_phrase
      t.found_phrase
  in
  let search_phrase_length =
    Int.to_float @@ List.length t.search_phrase
  in
  let unique_match_count =
    t.found_phrase
    |> List.map (fun x -> x.found_word_pos)
    |> List.sort_uniq Int.compare
    |> List.length
    |> Int.to_float
  in
  let (total_distance, out_of_order_match_count, _) =
    List.fold_left
      (fun (total_dist, out_of_order_match_count, last_pos) { found_word_pos = pos; _ } ->
         match last_pos with
         | None -> (total_dist, out_of_order_match_count, Some pos)
         | Some last_pos ->
           let total_dist = total_dist +. Int.to_float (abs (pos - last_pos)) in
           let out_of_order_match_count =
             if last_pos <= pos then
               out_of_order_match_count
             else
               out_of_order_match_count +. 1.0
           in
           (total_dist, out_of_order_match_count, Some pos)
      )
      (0.0, 0.0, None)
      t.found_phrase
  in
  let average_distance =
    total_distance /. unique_match_count
  in
  let exact_match_score =
    if quite_close_to_zero stats.exact_match_found_char_count then
      0.0
    else
      1.4
  in
  let ci_exact_match_score =
    if quite_close_to_zero stats.ci_exact_match_found_char_count then
      0.0
    else
      1.2
  in
  let sub_match_score =
    if quite_close_to_zero stats.sub_match_total_char_count then
      0.0
    else (
      (stats.sub_match_overlap_char_count *. 2.0)
      /.
      stats.sub_match_total_char_count
    )
  in
  let ci_sub_match_score =
    if quite_close_to_zero stats.ci_sub_match_total_char_count then
      0.0
    else (
      0.9
      *.
      ((stats.ci_sub_match_overlap_char_count *. 2.0)
       /.
       stats.ci_sub_match_total_char_count)
    )
  in
  let fuzzy_match_score =
    if quite_close_to_zero stats.fuzzy_match_search_char_count then
      0.0
    else (
      1.0
      -.
      (stats.fuzzy_match_edit_distance
       /.
       stats.fuzzy_match_search_char_count)
    )
  in
  let total_char_count =
    stats.total_search_char_count +. stats.total_found_char_count
  in
  (1.0 +. (0.10 *. (unique_match_count /. search_phrase_length)))
  *.
  (1.0 -. (out_of_order_match_count /. search_phrase_length))
  *.
  (if quite_close_to_zero average_distance then 1.0 else 1.0 /. average_distance)
  *.
  (
    (exact_match_score *.
     (stats.exact_match_found_char_count /. total_char_count))
    +.
    (ci_exact_match_score *.
     (stats.ci_exact_match_found_char_count /. total_char_count))
    +.
    (sub_match_score
     *. (stats.sub_match_overlap_char_count /. total_char_count))
    +.
    (ci_sub_match_score
     *. (stats.ci_sub_match_overlap_char_count /. total_char_count))
    +.
    (fuzzy_match_score
     *. (stats.fuzzy_match_found_char_count /. total_char_count))
  )

let compare t1 t2 =
  Float.compare (score t1) (score t2)

let compare_rev t1 t2 =
  compare t2 t1
