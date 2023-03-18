type t = {
  path : string;
  title : string option;
  tags : string list;
  tag_matched : bool list;
  content_index : Content_index.t;
  content_search_results : Content_search_result.t list;
  preview_lines : string list;
}

let empty : t =
  {
    path = "";
    title = None;
    tags = [];
    tag_matched = [];
    content_index = Content_index.empty;
    content_search_results = [];
    preview_lines = [];
  }

type line_typ =
  | Line of string
  | Tags of string list

module Parsers = struct
  open Angstrom

  let is_space c =
    match c with
    | ' '
    | '\t'
    | '\n'
    | '\r' -> true
    | _ -> false

  let spaces = skip_while is_space

  let spaces1 = take_while1 is_space *> return ()

  let any_string : string t = take_while1 (fun _ -> true)

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
        let content_index = Content_index.(union (index title_seq) (index s)) in
        {
          empty with
          title = Some (String.concat " " (List.map snd title));
          tags = String_set.to_list tags;
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
    List.map String.lowercase_ascii tags
  in
  let tag_arr = Array.of_list tags in
  let tag_matched = Array.make (Array.length tag_arr) true in
  let tag_lowercase_arr = Array.of_list tags_lowercase in
  List.iter
    (fun dfa ->
       Array.iteri (fun i x ->
           tag_matched.(i) <- tag_matched.(i) && (Spelll.match_with dfa x)
         )
         tag_lowercase_arr
    )
    (Tag_search_constraints.fuzzy_index constraints);
  String_set.iter
    (fun s ->
       Array.iteri (fun i x ->
           tag_matched.(i) <- tag_matched.(i) && (String.equal x s)
         )
         tag_lowercase_arr
    )
    (Tag_search_constraints.ci_full constraints);
  String_set.iter
    (fun sub ->
       Array.iteri (fun i x ->
           tag_matched.(i) <- tag_matched.(i) && (CCString.find ~sub x >= 0)
         )
         tag_lowercase_arr
    )
    (Tag_search_constraints.ci_sub constraints);
  String_set.iter
    (fun s ->
       Array.iteri (fun i x ->
           tag_matched.(i) <- tag_matched.(i) && (String.equal x s)
         )
         tag_arr
    )
    (Tag_search_constraints.exact constraints);
  if Tag_search_constraints.is_empty constraints
  || Array.exists (fun x -> x) tag_matched
  then (
    Some { t with tag_matched = Array.to_list tag_matched }
  ) else (
    None
  )

let content_search_results
    (constraints : Content_search_constraints.t)
    (t : t)
  : Content_search_result.t Seq.t =
  let locations_of_word_ci' =
    String_map.bindings t.content_index.locations_of_word_ci
    |> List.to_seq
  in
  List.map2 (fun word dfa ->
      locations_of_word_ci'
      |> Seq.filter (fun (s, _locations) ->
          String.equal word s
          || CCString.find ~sub:s word >= 0
          || (word.[0] = s.[0] && Spelll.match_with dfa s)
        )
      |> Seq.flat_map (fun (_, locations) ->
          Int_set.to_seq locations
        )
    )
    constraints.phrase
    constraints.fuzzy_index
  |> List.to_seq
  |> OSeq.cartesian_product
  |> Seq.map (fun l ->
      ({ original_phrase = constraints.phrase;
         found_phrase = List.map
             (fun i -> (Int_map.find i t.content_index.word_of_location_ci, i)) l;
       } : Content_search_result.t)
    )
