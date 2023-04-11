type t = {
  path : string option;
  title : string option;
  content_index : Content_index.t;
  content_search_results : Content_search_result.t array;
  content_lines : string array;
}

let make_empty () : t =
  {
    path = None;
    title = None;
    content_index = Content_index.empty;
    content_search_results = [||];
    content_lines = [||];
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

type work_stage = [
  | `Parsing_title
  | `Header_completed
]

let peek_for_preview_lines (s : (int * string) Seq.t) : string list * (int * string) Seq.t =
  let cleanup_acc acc =
    acc
    |> List.map snd
    |> List.rev
  in
  let rec aux acc i s =
    match s () with
    | Seq.Nil -> (cleanup_acc acc, acc |> List.rev |> List.to_seq)
    | Seq.Cons ((line_num, x), xs) ->
      let acc = (line_num, x) :: acc in
      if i >= Params.preview_line_count then
        (cleanup_acc acc, Seq.append (acc |> List.rev |> List.to_seq) xs)
      else
        aux acc (i+1) xs
  in
  aux [] 0 s

let parse (s : (int * string) Seq.t) : t =
  let rec aux (stage : work_stage) title s =
    match stage with
    | `Header_completed -> (
        let s = 
          match title with
          | None -> s
          | Some title ->
            Seq.cons (0, title) s
        in
        let content_index, content_lines =
          let arr = Array.of_seq s in
          (Content_index.index (Array.to_seq arr), (Array.map snd arr))
        in
        let empty = make_empty () in
        {
          empty with
          title;
          content_index;
          content_lines;
        }
      )
    | `Parsing_title -> (
        match s () with
        | Seq.Nil -> aux `Header_completed title Seq.empty
        | Seq.Cons ((_line_num, x), xs) -> (
            aux `Header_completed (Some x) xs
          )
      )
  in
  aux `Parsing_title None s

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

let content_search_results
    (constraints : Content_search_constraints.t)
    (t : t)
  : Content_search_result.t Seq.t =
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
            | None -> String_map.to_seq t.content_index.pos_s_of_word_ci
            | Some last_pos ->
              let _, _, m =
                Int_map.split (last_pos - (!Params.max_word_search_range+1))
                  t.content_index.word_ci_of_pos
              in
              let m, _, _ =
                Int_map.split (last_pos + (!Params.max_word_search_range+1))
                  m
              in
              let words_to_consider =
                Int_map.fold (fun _ word s ->
                    String_set.add word s
                  ) m String_set.empty
              in
              String_set.to_seq words_to_consider
              |> Seq.map (fun word ->
                  (word, String_map.find word t.content_index.pos_s_of_word_ci)
                )
              |> Seq.map (fun (word, pos_s) ->
                  let _, _, m =
                    Int_set.split (last_pos - (!Params.max_word_search_range+1)) pos_s
                  in
                  let m, _, _ =
                    Int_set.split (last_pos + (!Params.max_word_search_range+1)) m
                  in
                  (word, m)
                )
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
             (fun i ->
                (i,
                 Int_map.find i t.content_index.word_ci_of_pos,
                 Int_map.find i t.content_index.word_of_pos
                )
             ) l;
       } : Content_search_result.t)
    )
