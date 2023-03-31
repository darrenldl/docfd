type t = {
  path : string;
  title : string option;
  tags : string array;
  tag_matched : bool array;
  content_index : Content_index.t;
  content_search_results : Content_search_result.t array;
  preview_lines : string list;
}

let make_empty () : t =
  {
    path = "";
    title = None;
    tags = [||];
    tag_matched = [||];
    content_index = Content_index.empty;
    content_search_results = [||];
    preview_lines = [];
  }

type line_typ =
  | Line of string
  | Tags of string list

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

  let tags_p ~delim_start ~delim_end =
    let delim =
      if delim_start = delim_end then
        Printf.sprintf "%c" delim_start
      else
        Printf.sprintf "%c%c" delim_start delim_end
    in
    spaces *> char delim_start *> spaces *> words_p ~delim >>=
    (fun l -> char delim_end *> spaces *> return (Tags l))

  let header_p =
    choice
      [
        tags_p ~delim_start:'[' ~delim_end:']';
        tags_p ~delim_start:'|' ~delim_end:'|';
        tags_p ~delim_start:'@' ~delim_end:'@';
        spaces *> any_string >>=
        (fun s -> return (Line (CCString.rtrim s)));
      ]
end

type note_work_stage = [
  | `Parsing_title
  | `Parsing_tag_section
  | `Header_completed
]

type text_work_stage = [
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

let parse_note (s : (int * string) Seq.t) : t =
  let rec aux (last_stage : note_work_stage) (stage : note_work_stage) title tags s =
    match stage with
    | `Header_completed -> (
        let title_seq, s =
          match last_stage with
          | `Parsing_title -> (
              match title with
              | [] -> (Seq.empty, s)
              | x :: xs -> (Seq.return x, Seq.append (List.to_seq xs) s)
            )
          | _ ->
            (List.to_seq title, s)
        in
        let (preview_lines, s) = peek_for_preview_lines s in
        let content_index = Content_index.index (Seq.append title_seq s) in
        let empty = make_empty () in
        {
          empty with
          title = Some (String.concat " " (List.map snd title));
          tags = Array.of_list @@ String_set.to_list tags;
          content_index;
          preview_lines;
        }
      )
    | `Parsing_title | `Parsing_tag_section -> (
        match s () with
        | Seq.Nil -> aux stage `Header_completed title tags Seq.empty
        | Seq.Cons ((line_num, x), xs) -> (
            match Angstrom.(parse_string ~consume:Consume.All) Parsers.header_p x with
            | Ok x ->
              (match x with
               | Line x -> (
                   match stage with
                   | `Parsing_title ->
                     aux stage `Parsing_title ((line_num, x) :: title) tags xs
                   | `Parsing_tag_section | `Header_completed ->
                     aux stage `Header_completed title tags (Seq.cons (line_num, x) xs)
                 )
               | Tags l -> (
                   let tags = String_set.add_list tags l in
                   aux stage `Parsing_tag_section title tags xs
                 )
              )
            | Error _ -> aux last_stage stage title tags xs
          )
      )
  in
  aux `Parsing_title `Parsing_title [] String_set.empty s

let parse_text (s : (int * string) Seq.t) : t =
  let rec aux (stage : text_work_stage) title s =
    match stage with
    | `Header_completed -> (
        let (preview_lines, s) = peek_for_preview_lines s in
        let s = 
          match title with
          | None -> s
          | Some title ->
            Seq.cons (0, title) s
        in
        let content_index = Content_index.index s in
        let empty = make_empty () in
        {
          empty with
          title;
          content_index;
          preview_lines;
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

let of_path path : (t, string) result =
  try
    CCIO.with_in path (fun ic ->
        let s = CCIO.read_lines_seq ic
                |> Seq.mapi (fun i line -> (i, line))
        in
        let document =
          if Misc_utils.path_is_note path then
            parse_note s
          else
            parse_text s
        in
        Ok { document with path }
      )
  with
  | _ -> Error (Printf.sprintf "Failed to read file: %s" path)

let satisfies_tag_search_constraints
    (constraints : Tag_search_constraints.t)
    (t : t)
  : t option =
  let tags = t.tags in
  let tags_lowercase =
    Array.map String.lowercase_ascii tags
  in
  let tag_matched = Array.make (Array.length tags) true in
  List.iter
    (fun dfa ->
       Array.iteri (fun i x ->
           tag_matched.(i) <- tag_matched.(i) && (Spelll.match_with dfa x)
         )
         tags_lowercase
    )
    (Tag_search_constraints.fuzzy_index constraints);
  String_set.iter
    (fun s ->
       Array.iteri (fun i x ->
           tag_matched.(i) <- tag_matched.(i) && (String.equal x s)
         )
         tags_lowercase
    )
    (Tag_search_constraints.ci_full constraints);
  String_set.iter
    (fun sub ->
       Array.iteri (fun i x ->
           tag_matched.(i) <- tag_matched.(i) && (CCString.find ~sub x >= 0)
         )
         tags_lowercase
    )
    (Tag_search_constraints.ci_sub constraints);
  String_set.iter
    (fun s ->
       Array.iteri (fun i x ->
           tag_matched.(i) <- tag_matched.(i) && (String.equal x s)
         )
         tags
    )
    (Tag_search_constraints.exact constraints);
  if Tag_search_constraints.is_empty constraints
  || Array.exists (fun x -> x) tag_matched
  then (
    Some { t with tag_matched }
  ) else (
    None
  )

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
                  t.content_index.word_of_pos_ci
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
          let usable_positions =
            word_ci_and_positions_to_consider
            |> Seq.filter (fun (indexed_word, _pos_s) ->
                String.equal search_word indexed_word
                || CCString.find ~sub:search_word indexed_word >= 0
                || (Misc_utils.first_n_chars_of_string_contains ~n:5 indexed_word search_word.[0]
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
             (fun i -> (Int_map.find i t.content_index.word_of_pos_ci, i)) l;
       } : Content_search_result.t)
    )
