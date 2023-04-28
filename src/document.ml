type t = {
  path : string option;
  title : string option;
  index : Index.t;
  search_results : Search_result.t array;
}

let make_empty () : t =
  {
    path = None;
    title = None;
    index = Index.empty;
    search_results = [||];
  }

let copy (t : t) =
  {
    path = t.path;
    title = t.title;
    index = t.index;
    search_results = Array.copy t.search_results;
  }

module Parsers = struct
  open Angstrom
  open Parser_components

  let word_p ~delim =
    take_while1 (fun c ->
        (not (is_space c))
        &&
        (not (String.contains delim c))
      )

  let words_p ~delim = many (word_p ~delim <* spaces)
end

type work_stage =
  | Title
  | Content

let parse (s : (int * string) Seq.t) : t =
  let rec aux (stage : work_stage) title s =
    match stage with
    | Content -> (
        let s = 
          match title with
          | None -> s
          | Some title ->
            Seq.cons (0, title) s
        in
        let index = Index.of_seq s in
        let empty = make_empty () in
        {
          empty with
          title;
          index;
        }
      )
    | Title -> (
        match s () with
        | Seq.Nil -> aux Content title Seq.empty
        | Seq.Cons ((_line_num, x), xs) -> (
            aux Content (Some x) xs
          )
      )
  in
  aux Title None s

let of_in_channel ~path ic : t =
  let s = CCIO.read_lines_seq ic
          |> Seq.mapi (fun i line -> (i, line))
  in
  let document = parse s in
  { document with path }

let of_path path : (t, string) result =
  try
    CCIO.with_in path (fun ic ->
        Ok (of_in_channel ~path:(Some path) ic)
      )
  with
  | _ -> Error (Printf.sprintf "Failed to read file: %s" path)

let search
    (constraints : Search_constraints.t)
    (t : t)
  : Search_result.t Seq.t =
  let find_possible_combinations_within_range
      (word_dfa_pairs : (string * Spelll.automaton) list)
    : int list Seq.t
    =
    let rec aux (last_pos : int option) (l : (string * Spelll.automaton) list) =
      match l with
      | [] -> Seq.return []
      | (search_word, dfa) :: rest -> (
          let word_ci_and_positions_to_consider =
            match last_pos with
            | None -> Index.word_ci_and_pos_s t.index
            | Some last_pos ->
              let start = last_pos - (!Params.max_word_search_range+1) in
              let end_inc = last_pos + (!Params.max_word_search_range+1) in
              Index.word_ci_and_pos_s ~range_inc:(start, end_inc) t.index
          in
          let search_word_ci =
            String.lowercase_ascii search_word
          in
          let usable_positions =
            word_ci_and_positions_to_consider
            |> Seq.filter (fun (indexed_word, _pos_s) ->
                String.equal search_word_ci indexed_word
                || CCString.find ~sub:search_word_ci indexed_word >= 0
                || (Misc_utils.first_n_chars_of_string_contains ~n:5 indexed_word search_word_ci.[0]
                    && Spelll.match_with dfa indexed_word)
              )
            |> Seq.flat_map (fun (_indexed_word, pos_s) -> Int_set.to_seq pos_s)
          in
          usable_positions
          |> Seq.flat_map (fun pos ->
              aux (Some pos) rest
              |> Seq.map (fun l -> (pos :: l))
            )
        )
    in
    aux None word_dfa_pairs
  in
  find_possible_combinations_within_range
    (List.combine constraints.phrase constraints.fuzzy_index)
  |> Seq.map (fun l ->
      ({ search_phrase = constraints.phrase;
         found_phrase = List.map
             (fun pos ->
                let word_ci = 
                  Index.word_ci_of_pos pos t.index
                in
                let word =
                  Index.word_of_pos pos t.index
                in
                (pos, word_ci, word)
             ) l;
       } : Search_result.t)
    )
