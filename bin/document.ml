open Result_syntax

type t = {
  path : string option;
  title : string option;
  index : Docfd_lib.Index.t;
}

let make_empty () : t =
  {
    path = None;
    title = None;
    index = Docfd_lib.Index.empty;
  }

let copy (t : t) =
  {
    path = t.path;
    title = t.title;
    index = t.index;
  }

type work_stage =
  | Title
  | Content

let parse_lines (s : string Seq.t) : t =
  let rec aux (stage : work_stage) title s =
    match stage with
    | Content -> (
        let index = Docfd_lib.Index.of_lines s in
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
        | Seq.Cons (x, xs) -> (
            aux Content (Some (Misc_utils.sanitize_string x)) (Seq.cons x xs)
          )
      )
  in
  aux Title None s

let parse_pages (s : string list Seq.t) : t =
  let rec aux (stage : work_stage) title s =
    match stage with
    | Content -> (
        let index = Docfd_lib.Index.of_pages s in
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
        | Seq.Cons (x, xs) -> (
            let title =
              match x with
              | [] -> None
              | x :: _ ->
                Some (Misc_utils.sanitize_string x)
            in
            aux Content title (Seq.cons x xs)
          )
      )
  in
  aux Title None s

let of_in_channel ic : t =
  parse_lines (CCIO.read_lines_seq ic)

let save_index ~env ~hash index =
  let fs = Eio.Stdenv.fs env in
  (try
     Eio.Path.(mkdir ~perm:0644 (fs / !Params.index_dir));
   with _ -> ()
  );
  let path =
    Eio.Path.(fs / Filename.concat !Params.index_dir (Fmt.str "%s.index" hash))
  in
  let json = Docfd_lib.Index.to_json index in
  Eio.Path.save ~create:(`Or_truncate 0644) path (Yojson.Safe.to_string json)

let find_index ~env ~hash : Docfd_lib.Index.t option =
  let fs = Eio.Stdenv.fs env in
  try
    let path =
      Eio.Path.(fs / Filename.concat !Params.index_dir (Fmt.str "%s.index" hash))
    in
    let json = Yojson.Safe.from_string (Eio.Path.load path) in
    Docfd_lib.Index.of_json json
  with
  | _ -> None

let of_text_path ~env path : (t, string) result =
  let fs = Eio.Stdenv.fs env in
  try
    Eio.Path.(with_lines (fs / path))
      (fun lines ->
         let document = parse_lines lines in
         Ok { document with path = Some path }
      )
  with
  | _ -> Error (Printf.sprintf "Failed to read file: %s" path)

let of_pdf_path ~env path : (t, string) result =
  let proc_mgr = Eio.Stdenv.process_mgr env in
  let rec aux acc page_num =
    let page_num_string = Int.to_string page_num in
    let cmd = [ "pdftotext"; "-f"; page_num_string; "-l"; page_num_string; path; "-" ] in
    match Proc_utils.run_return_stdout ~proc_mgr cmd with
    | None -> (
        let document = parse_pages (acc |> List.rev |> List.to_seq) in
        { document with path = Some path }
      )
    | Some page -> (
        aux (page :: acc) (page_num + 1)
      )
  in
  try
    Ok (aux [] 1)
  with
  | _ -> Error (Printf.sprintf "Failed to read file: %s" path)

let of_path ~(env : Eio_unix.Stdenv.base) path : (t, string) result =
  let* hash = BLAKE2B.hash_of_file ~env ~path in
  match find_index ~env ~hash with
  | Some index -> (
      let title =
        if Docfd_lib.Index.global_line_count index = 0 then
          None
        else
          Some (Docfd_lib.Index.line_of_global_line_num 0 index)
      in
      Ok { path = Some path; title; index }
    )
  | None -> (
      let+ t =
        if Misc_utils.path_is_pdf path then
          of_pdf_path ~env path
        else
          of_text_path ~env path
      in
      save_index ~env ~hash t.index;
      t
    )
