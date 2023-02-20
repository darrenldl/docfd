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
             String_set.add_list tags l
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

let list_tags_arg =
  let doc =
    Fmt.str "List all tags used."
  in
  Arg.(value & flag & info [ "tags" ] ~doc)

let list_tags_lowercase_arg =
  let doc =
    Fmt.str "List all tags used in lowercase."
  in
  Arg.(value & flag & info [ "ltags" ] ~doc)

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

let unwrap_header (f : header -> unit) (header : (header, string) result) =
  match header with
  | Ok header -> f header
  | Error msg -> Fmt.pr "Error: %s\n" msg

let print_tags (tags : String_set.t) =
  String_set.to_seq tags
  |> Seq.iter (fun s ->
      Fmt.pr "%s@ " s
    )

let run
    (fuzzy_max_edit_distance : int)
    (ci_fuzzy_tag_matches_required : string list)
    (ci_full_tag_matches_required : string list)
    (ci_sub_tag_matches_required : string list)
    (exact_tag_matches_required : string list)
    (list_tags : bool)
    (list_tags_lowercase : bool)
    (dir : string)
  =
  if list_tags_lowercase && list_tags then (
    Fmt.pr "Error: Please select only --tags or --ltags\n";
    exit 1
  );
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
  if list_tags_lowercase then (
    let tags_used = ref String_set.empty in
    List.iter (unwrap_header (fun header ->
        let tags_lowercase =
          String_set.map String.lowercase_ascii header.tags
        in
        tags_used := String_set.(union tags_lowercase !tags_used)
      )) headers;
    print_tags !tags_used
  )
  else (
    if list_tags then (
      let tags_used = ref String_set.empty in
      List.iter (
        unwrap_header (fun header ->
            tags_used := String_set.(union header.tags !tags_used))
      ) headers;
      print_tags !tags_used
    ) else (
      List.iter (unwrap_header (fun header ->
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
        ) headers
    )
  )

let dir_arg = Arg.(value & pos 0 dir "." & info [])

let cmd =
  let doc = "Tag any text file with a simple header" in
  let version = Version_string.s in
  Cmd.v (Cmd.info "notefd" ~version ~doc)
    (Term.(const run
           $ fuzzy_max_edit_distance_arg
           $ tag_ci_fuzzy_arg
           $ tag_ci_full_arg
           $ tag_ci_sub_arg
           $ tag_exact_arg
           $ list_tags_arg
           $ list_tags_lowercase_arg
           $ dir_arg))

let () = exit (Cmd.eval cmd)
