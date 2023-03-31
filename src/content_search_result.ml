type t = {
  search_phrase : string list;
  found_phrase : (string * int) list;
}

type score_ctx = {
  exact_match_count : float;
  sub_match_search_char_count : float;
  sub_match_found_char_count : float;
  fuzzy_match_edit_distance : float;
  fuzzy_match_found_char_count : float;
}

let empty_score_ctx = {
  exact_match_count = 0.0;
  sub_match_search_char_count = 0.0;
  sub_match_found_char_count = 0.0;
  fuzzy_match_edit_distance = 0.0;
  fuzzy_match_found_char_count = 0.0;
}

let score (t : t) : float =
  let quite_close_to_zero x =
    -0.01 < x && x < 0.01
  in
  let ctx =
    List.fold_left2 (fun (ctx : score_ctx) x (y, _) ->
        if String.equal x y then
          { ctx with exact_match_count = ctx.exact_match_count +. 1.0 }
        else if CCString.find ~sub:x y >= 0 then
          { ctx with
            sub_match_search_char_count =
              ctx.sub_match_search_char_count +. Int.to_float (String.length x);
            sub_match_found_char_count =
              ctx.sub_match_found_char_count +. Int.to_float (String.length y);
          }
        else (
          { ctx with
            fuzzy_match_edit_distance =
              ctx.fuzzy_match_edit_distance +. Int.to_float (Spelll.edit_distance x y);
            fuzzy_match_found_char_count =
              ctx.fuzzy_match_found_char_count +. Int.to_float (String.length x);
          }
        )
      )
      empty_score_ctx
      t.search_phrase
      t.found_phrase
  in
  let search_phrase_length =
    Int.to_float @@ List.length t.search_phrase
  in
  let unique_match_count =
    t.found_phrase
    |> List.map snd
    |> List.sort_uniq Int.compare
    |> List.length
    |> Int.to_float
  in
  let (total_distance, _) =
    List.fold_left (fun (n, last_pos) (_, d) ->
        match last_pos with
        | None -> (n, Some d)
        | Some last_pos -> (n + abs (d - last_pos), Some d)
      )
      (0, None)
      t.found_phrase
  in
  let total_distance = Int.to_float total_distance in
  let average_distance =
    total_distance /. unique_match_count
  in
  let sub_matches_closeness =
    if quite_close_to_zero ctx.sub_match_found_char_count then
      0.0
    else
      ctx.sub_match_search_char_count
      /.
      ctx.sub_match_found_char_count
  in
  let fuzzy_matches_closeness =
    if quite_close_to_zero ctx.fuzzy_match_found_char_count then
      0.0
    else
      1.0
      -.
      (ctx.fuzzy_match_edit_distance
       /.
       ctx.fuzzy_match_found_char_count)
  in
  (unique_match_count /. search_phrase_length)
  *.
  (if quite_close_to_zero average_distance then 1.0 else 1.0 /. average_distance)
  *.
  (
    (if quite_close_to_zero ctx.exact_match_count then 0.0 else 1.0)
    +.
    sub_matches_closeness
    +.
    fuzzy_matches_closeness
  )

let compare t1 t2 =
  Float.compare (score t2) (score t1)
