type t = {
  path : string;
  title : string option;
  tags : string list;
  tag_matched : bool list;
  content_words : Int_set.t String_map.t;
  content_words_ci : Int_set.t String_map.t;
}

let empty : t =
  {
    path = "";
    title = None;
    tags = [];
    tag_matched = [];
    content_words = String_map.empty;
    content_words_ci = String_map.empty;
  }

let path_is_note path =
      let words =
        Filename.basename path
        |> String.lowercase_ascii
        |> String.split_on_char '.'
      in
List.exists (fun s ->
          s = "note" || s = "notes") words

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

let words_of_lines (s : string Seq.t) : string Seq.t =
  s
  |> Seq.flat_map (fun s -> String.split_on_char ' ' s |> List.to_seq)
  |> Seq.filter (fun s -> s <> "")

let index_content (s : string Seq.t) : Int_set.t String_map.t * Int_set.t String_map.t =
  s
  |> words_of_lines
  |> Seq.fold_lefti (fun (words, words_ci) i word ->
      let word_ci = String.lowercase_ascii word in
      let set = Option.value ~default:Int_set.empty
      (String_map.find_opt word words)
  |> Int_set.add i
      in
      let set_ci = Option.value ~default:Int_set.empty
      (String_map.find_opt word_ci words_ci)
  |> Int_set.add i
      in
      (String_map.add word set words,
      String_map.add word_ci set_ci words_ci)
      )
  (String_map.empty, String_map.empty)

  type note_work_stage = [
    | `Parsing_title
    | `Parsing_tag_section
    | `Header_completed
  ]

  type text_work_stage = [
    | `Parsing_title
    | `Header_completed
  ]

let parse_note (s : string Seq.t) : t =
  let rec aux (stage : note_work_stage) title tags s =
    match stage with
    | `Header_completed -> (
      let (content_words, content_words_ci) = index_content s in
      {
        empty with
        title = Some (String.concat " " title);
        tags = String_set.to_list tags;
        content_words;
        content_words_ci;
      }
    )
    | `Parsing_title | `Parsing_tag_section -> (
      match s () with
      | Seq.Nil -> aux `Header_completed title tags Seq.empty
      | Seq.Cons (x, xs) -> (
      match Angstrom.(parse_string ~consume:Consume.All) Parsers.header_p x with
      | Ok x ->
        (match x with
         | Line x -> (
           match stage with
           | `Parsing_title ->
             aux `Parsing_title (x :: title) tags xs
           | `Parsing_tag_section | `Header_completed ->
             aux `Header_completed title tags (Seq.cons x xs)
          )
         | Tags l -> (
           let tags = String_set.add_list tags l in
           aux `Parsing_tag_section title tags xs
         )
        )
      | Error _ -> aux stage title tags xs
      )
    )
  in
  aux `Parsing_title [] String_set.empty s

let parse_text (s : string Seq.t) : t =
  let rec aux (stage : text_work_stage) title s =
    match stage with
    | `Header_completed -> (
      let (content_words, content_words_ci) = index_content s in
      {
        empty with
        title = title;
        content_words;
        content_words_ci;
      }
    )
    | `Parsing_title -> (
      match s () with
      | Seq.Nil -> aux `Header_completed title Seq.empty
      | Seq.Cons (x, xs) -> (
        aux `Header_completed (Some x) xs
      )
    )
  in
  aux `Parsing_title None s

let of_path path : (t, string) result =
  try
    CCIO.with_in path (fun ic ->
      let s = CCIO.read_lines_seq ic in
      if path_is_note path then
        Ok (parse_note s)
      else
        Ok (parse_text s)
      )
  with
  | _ -> Error (Printf.sprintf "Failed to read file: %s" path)
