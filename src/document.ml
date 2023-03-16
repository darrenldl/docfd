type content_index = {
  locations_of_word_ci : Int_set.t String_map.t;
  line_of_location_ci : int Int_map.t;
  word_of_location_ci : string Int_map.t;
}

let empty_content_index : content_index = {
  locations_of_word_ci = String_map.empty;
  line_of_location_ci = Int_map.empty;
  word_of_location_ci = Int_map.empty;
}

type t = {
  path : string;
  title : string option;
  tags : string list;
  tag_matched : bool list;
  content_index : content_index;
}

let empty : t =
  {
    path = "";
    title = None;
    tags = [];
    tag_matched = [];
    content_index = empty_content_index;
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

let words_of_lines (s : string Seq.t) : (int * int * string) Seq.t =
  s
    |> Seq.mapi (fun line_num s -> (line_num, s))
  |> Seq.flat_map (fun (line_num, s) ->
      String.split_on_char ' ' s
  |> List.to_seq
  |> Seq.map (fun s -> (line_num, s)))
  |> Seq.filter (fun (_line_num, s) -> s <> "")
  |> Seq.mapi (fun i (line_num, s) ->
      (i, line_num, s))

let index_content (s : string Seq.t) : content_index =
  s
  |> words_of_lines
  |> Seq.fold_left (fun {locations_of_word_ci; line_of_location_ci; word_of_location_ci } (loc, line, word) ->
      let word_ci = String.lowercase_ascii word in
      let locations_ci = Option.value ~default:Int_set.empty
        (String_map.find_opt word locations_of_word_ci)
  |> Int_set.add loc
      in
      { locations_of_word_ci = String_map.add word_ci locations_ci locations_of_word_ci;
      line_of_location_ci = Int_map.add loc line line_of_location_ci;
      word_of_location_ci = Int_map.add loc word_ci word_of_location_ci;
        }
      )
  empty_content_index

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
      let content_index = index_content s in
      {
        empty with
        title = Some (String.concat " " title);
        tags = String_set.to_list tags;
        content_index;
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
      let content_index = index_content s in
      {
        empty with
        title = title;
        content_index;
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
      if Misc_utils.path_is_note path then
        Ok (parse_note s)
      else
        Ok (parse_text s)
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

let ranked_content_search_results
(constraints : Content_search_constraints.t)
(t : t)
: Content_search_result.t list =
  let locations_of_word_ci' =
    String_map.bindings t.content_index.locations_of_word_ci
      |> List.to_seq
  in
  List.map2 (fun word dfa ->
locations_of_word_ci'
    |> Seq.filter (fun (s, locations) ->
        String.equal word s
    || CCString.find ~sub:s word >= 0
    || Spelll.match_with dfa s
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
    |> List.of_seq
