type t = {
  original_phrase : string list;
  found_phrase : (string * int) list;
}

let score (t : t) : float =
  let (exact_matches, sub_matches, fuzzy_matches) =
    List.fold_left2 (fun (e, s, f) x (y, _) ->
      if String.equal x y then (e+1, s, f)
      else if CCString.find ~sub:x y >= 0 then
        (e, s+1, f)
      else
        (e, s, f)
    )
    (0, 0, 0)
    t.original_phrase
    t.found_phrase
  in
  let exact_matches = Int.to_float exact_matches in
  let sub_matches = Int.to_float sub_matches in
  let fuzzy_matches = Int.to_float fuzzy_matches in
  let (total_distance, _) =
    List.fold_left (fun (n, last_loc) (_, d) ->
      match last_loc with
      | None -> (n, Some d)
      | Some last_loc -> (n + (d - last_loc), Some d)
    )
    (0, None)
    t.found_phrase
  in
  let average_distance =
    (Int.to_float total_distance) /. (Int.to_float (List.length t.found_phrase))
  in
  1.0 /. (average_distance +. 1.0)
  *. (2.0 *. exact_matches +. 1.0 *. sub_matches +. 0.5 *. fuzzy_matches)

let compare t1 t2 =
  Float.compare (score t1) (score t2)
