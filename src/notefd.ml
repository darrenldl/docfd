open Cmdliner

let ( let* ) = Result.bind

let ( let+ ) r f = Result.map f r

let first_n_lines_to_parse = 5

let get_first_few_lines (path : string) : (string list, string) result =
  let rec aux ic count acc =
    if count = 0 then
      List.rev acc
    else
      match CCIO.read_line ic with
      | None -> List.rev acc
      | Some s -> aux ic (pred count) (s :: acc)
  in
  try
    CCIO.with_in path (fun ic ->
        Ok (aux ic first_n_lines_to_parse [])
      )
  with
  | Sys_error _ -> Error (Printf.sprintf "Failed to read file: %s" path)

type header = {
  path : string;
  title : string option;
  tags : String_set.t;
}

type line_typ =
  | Title of string
  | Tags of string list

module Parsers = struct
  open MParser

  let word_p =
    many1_satisfy (fun c ->
        match c with
        | 'A' .. 'Z'
        | 'a' .. 'z'
        | '0' .. '9'
        | '.' | '-' | '_' | '(' | ')'
        | '+'
          -> true
        | _ -> false
      )

  let p =
    ( attempt
        ( spaces >> char '[' >> spaces >> sep_end_by word_p spaces1 >>=
          (fun l ->
             char ']' >> spaces >>$
             (Tags l)
          )
        )
    )
    <|>
    ( spaces >> many_chars any_char >>=
      (fun s -> return (Title (CCString.rtrim s)))
    )
end

let parse (l : string list) : string list * String_set.t =
  let open MParser in
  let rec aux title tags l =
    match l with
    | [] -> (List.rev title, tags)
    | x :: xs ->
      match parse_string Parsers.p x () with
      | Success x ->
        (match x with
         | Title x -> aux (x :: title) tags xs
         | Tags l ->
           let tags =
             List.map String.lowercase_ascii l
             |> String_set.add_list tags
           in
           aux title tags xs
        )
      | Failed _ -> aux title tags xs
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

let run (dir : string) =
  let files =
    FileUtil.(find Is_file dir)
      (fun acc x ->
         let words =
           Filename.basename x
           |> String.lowercase_ascii
           |> String.split_on_char '.'
         in
         if List.mem "note" words then
           x :: acc
         else
           acc
      ) []
  in
  let files = List.sort_uniq String.compare files in
  let headers =
    List.map process files
  in
  List.iter (fun header ->
      (match header with
       | Ok header ->
         Fmt.pr "@[<v>%s@,  @[<v>%s@,@[<h>[%a]@]@]@,@]" header.path
           (match header.title with
            | None -> "N/A"
            | Some s -> s)
           Fmt.(list ~sep:sp string) (String_set.to_list header.tags)
       | Error msg ->
         Fmt.pr "Error: %s\n" msg
      )
    ) headers

let dir_arg = Arg.(value & pos 0 dir "." & info [])

let cmd =
  let doc = "Find notes" in
  let version =
    match Build_info.V1.version () with
    | None -> "N/A"
    | Some version -> Build_info.V1.Version.to_string version
  in
  Cmd.v (Cmd.info "notefd" ~version ~doc)
    (Term.(const run $ dir_arg))

let () = exit (Cmd.eval cmd)
