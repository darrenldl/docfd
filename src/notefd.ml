open Cmdliner

let ( let* ) = Result.bind

let ( let+ ) r f = Result.map f r

let file_read_limit = 2048

let first_n_lines_to_parse = 5

let get_first_few_lines (path : string) : (string list, string) result =
  try
    CCIO.with_in path (fun ic ->
        let s =
          match CCIO.read_chunks_seq ~size:file_read_limit ic () with
          | Seq.Nil -> ""
          | Seq.Cons (s, _) -> s
        in
        CCString.lines_seq s
        |> Seq.take first_n_lines_to_parse
        |> List.of_seq
        |> Result.ok
      )
  with
  | _ -> Error (Printf.sprintf "Failed to read file: %s" path)

type header = {
  path : string;
  title : string option;
  tags : String_set.t;
}

type line_typ =
  | Title of string
  | Tags of string list

module Parsers = struct
  open Angstrom

  let is_space c =
    match c with
    | ' ' -> true
    | '\t' -> true
    | '\n' -> true
    | _ -> false

  let spaces = skip_while is_space

  let spaces1 = take_while1 is_space *> return ()

  let any_string : string t = take_while1 (fun _ -> true)

  let word_p =
    take_while1 (fun c ->
        not (is_space c)
        &&
        (match c with
         | '['
         | ']' -> false
         | _ -> true)
      )

  let p =
    ( spaces *> char '[' *> spaces *> sep_by spaces1 word_p >>=
      (fun l ->
         spaces *> char ']' *>
         return (Tags l)
      )
    )
    <|>
    ( spaces *> any_string >>=
      (fun s -> return (Title (CCString.rtrim s)))
    )
end

let parse (l : string list) : string list * String_set.t =
  let rec aux title tags l =
    match l with
    | [] -> (List.rev title, tags)
    | x :: xs ->
      match Angstrom.(parse_string ~consume:Consume.Prefix) Parsers.p x with
      | Ok x ->
        (match x with
         | Title x -> aux (x :: title) tags xs
         | Tags l ->
           let tags =
             List.map String.lowercase_ascii l
             |> String_set.add_list tags
           in
           aux title tags []
        )
      | Error _ -> aux title tags xs
  in
  aux [] String_set.empty l

let process path : (header, string) result =
  let+ lines = get_first_few_lines path in
  let (title_lines, tags) = parse lines in
  {
    path;
    title = (match title_lines with
        | [] -> None
        | l -> Some (String.concat " " l));
    tags;
  }

let fuzzy_max_edit_distance_arg =
  let doc =
    "Maximum edit distance for fuzzy matches."
  in
  Arg.(value & opt int 3 & info [ "fuzzy-max-edit" ] ~doc ~docv:"N")

let tag_ci_fuzzy_arg =
  let doc =
    Fmt.str "[F]uzzy case-insensitive tag match, up to fuzzy-max-edit edit distance."
  in
  Arg.(value & opt_all string [] & info [ "f" ] ~doc ~docv:"STRING")

let tag_ci_full_arg =
  let doc =
    Fmt.str "Case-[i]nsensitive full tag match."
  in
  Arg.(value & opt_all string [] & info [ "i" ] ~doc ~docv:"STRING")

let tag_ci_sub_arg =
  let doc =
    Fmt.str "Case-insensitive [s]ubstring tag match."
  in
  Arg.(value & opt_all string [] & info [ "s" ] ~doc ~docv:"SUBSTRING")

let tag_exact_arg =
  let doc =
    Fmt.str "[E]exact tag match."
  in
  Arg.(value & opt_all string [] & info [ "e" ] ~doc ~docv:"TAG")

let list_files_recursively (dir : string) : string list =
  let rec aux path =
    match Sys.is_directory path with
    | false ->
      let words =
        Filename.basename path
        |> String.lowercase_ascii
        |> String.split_on_char '.'
      in
      if List.mem "note" words then
        [ path ]
      else
        []
    | true -> (
        try
          let l = Array.to_list (Sys.readdir path) in
          List.map (Filename.concat path) l
          |> CCList.flat_map aux
        with
        | _ -> []
      )
    | exception _ -> []
  in
  aux dir

let ci_string_set_of_list (l : string list) =
  l
  |> List.map String.lowercase_ascii
  |> String_set.of_list

let run
    (fuzzy_max_edit_distance : int)
    (ci_fuzzy_tag_matches_required : string list)
    (ci_full_tag_matches_required : string list)
    (ci_sub_tag_matches_required : string list)
    (exact_tag_matches_required : string list)
    (dir : string)
  =
  let ci_fuzzy_tag_matches_required =
    ci_string_set_of_list ci_fuzzy_tag_matches_required
  in
  let ci_full_tag_matches_required =
    ci_string_set_of_list ci_full_tag_matches_required
  in
  let ci_sub_tag_matches_required =
    ci_string_set_of_list ci_sub_tag_matches_required
  in
  let exact_tag_matches_required =
    String_set.of_list exact_tag_matches_required
  in
  let files =
    list_files_recursively dir
  in
  let files = List.sort_uniq String.compare files in
  let headers =
    List.map process files
  in
  List.iter (fun header ->
      (match header with
       | Ok header -> (
           let tags_lowercase =
             String_set.map String.lowercase_ascii header.tags
           in
           let index = tags_lowercase
                       |> String_set.to_list
                       |> List.map (fun s -> (s, ()))
                       |> Spelll.Index.of_list
           in
           let ci_fuzzy_tag_matches_fulfilled () =
             String_set.for_all
               (fun s ->
                  match
                    Spelll.Index.retrieve_l ~limit:fuzzy_max_edit_distance index s
                  with
                  | [] -> false
                  | _ -> true
               )
               ci_fuzzy_tag_matches_required
           in
           let ci_full_tag_matches_fulfilled () =
             String_set.(is_empty @@
                         diff ci_full_tag_matches_required tags_lowercase)
           in
           let ci_sub_tag_matches_fulfilled () =
             String_set.for_all
               (fun sub ->
                  String_set.exists (fun s ->
                      CCString.find ~sub s >= 0
                    )
                    tags_lowercase
               )
               ci_sub_tag_matches_required
           in
           let exact_tag_matches_fulfilled () =
             String_set.(is_empty @@
                         diff exact_tag_matches_required header.tags)
           in
           if exact_tag_matches_fulfilled ()
           && ci_full_tag_matches_fulfilled ()
           && ci_sub_tag_matches_fulfilled ()
           && ci_fuzzy_tag_matches_fulfilled ()
           then (
             Fmt.pr "@[<v>%@ @[<v>%s@,>%s@,@[<h>[ %a ]@]@]@,@]" header.path
               (match header.title with
                | None -> ""
                | Some s -> Printf.sprintf " %s" s)
               Fmt.(list ~sep:sp string) (String_set.to_list header.tags)
           )
         )
       | Error msg ->
         Fmt.pr "Error: %s\n" msg
      )
    ) headers

let dir_arg = Arg.(value & pos 0 dir "." & info [])

let cmd =
  let doc = "Tag any text file with a simple header. All search constraints are chained together by \"and\"." in
  let version = Version_string.s in
  Cmd.v (Cmd.info "notefd" ~version ~doc)
    (Term.(const run
           $ fuzzy_max_edit_distance_arg
           $ tag_ci_fuzzy_arg
           $ tag_ci_full_arg
           $ tag_ci_sub_arg
           $ tag_exact_arg
           $ dir_arg))

let () = exit (Cmd.eval cmd)
