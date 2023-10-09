open Result_syntax
open Docfd_lib

type t = {
  path : string;
  title : string option;
  index : Index.t;
}

let make ~path : t =
  {
    path;
    title = None;
    index = Index.make ();
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

let parse_lines ~path (s : string Seq.t) : t =
  let rec aux (stage : work_stage) title s =
    match stage with
    | Content -> (
        let index = Index.of_lines s in
        let empty = make ~path in
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

let parse_pages ~path (s : string list Seq.t) : t =
  let rec aux (stage : work_stage) title s =
    match stage with
    | Content -> (
        let index = Index.of_pages s in
        let empty = make ~path in
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

let refresh_modification_time ~path =
  let time = Unix.time () in
  Unix.utimes path time time

let clean_up_index_dir ~index_dir =
  let all_files =
    Sys.readdir index_dir
    |> Array.to_list
    |> List.map (fun x ->
        Filename.concat index_dir x)
    |> List.filter (fun x ->
        not (Sys.is_directory x) && Filename.extension x = Params.index_file_ext)
  in
  let files_to_keep =
    all_files
    |> List.map (fun x ->
        let stat = Unix.stat x in
        let modification_time = stat.st_mtime in
        (x, modification_time)
      )
    |> List.sort_uniq (fun (_x1, x2) (_y1, y2) -> Float.compare y2 x2)
    |> List.map fst
    |> CCList.take Params.max_index_file_count
  in
  List.iter (fun x ->
      if not (List.mem x files_to_keep) then (
        Sys.remove x
      )
    ) all_files

let save_index ~env ~hash index : (unit, string) result =
  let fs = Eio.Stdenv.fs env in
  (try
     Eio.Path.(mkdir ~perm:0o755 (fs / !Params.index_dir));
   with _ -> ());
  let path =
    Eio.Path.(fs /
              Filename.concat !Params.index_dir (Fmt.str "%s%s" hash Params.index_file_ext))
  in
  let json = Index.to_json index in
  try
    Eio.Path.save ~create:(`Or_truncate 0o644) path (Yojson.Safe.to_string json);
    clean_up_index_dir ~index_dir:!Params.index_dir;
    Ok ()
  with
  | _ -> Error (Fmt.str "Failed to save index to %s" hash)

let find_index ~env ~hash : Index.t option =
  let fs = Eio.Stdenv.fs env in
  try
    let path_str =
      Filename.concat !Params.index_dir (Fmt.str "%s.index" hash)
    in
    let path =
      Eio.Path.(fs / path_str)
    in
    refresh_modification_time ~path:path_str;
    let json = Yojson.Safe.from_string (Eio.Path.load path) in
    Index.of_json json
  with
  | _ -> None

let of_text_path ~env path : (t, string) result =
  let fs = Eio.Stdenv.fs env in
  try
    Eio.Path.(with_lines (fs / path))
      (fun lines ->
         Ok (parse_lines ~path lines)
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
        parse_pages ~path (acc |> List.rev |> List.to_seq)
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
        if Index.global_line_count index = 0 then
          None
        else
          Some (Index.line_of_global_line_num 0 index)
      in
      Ok { path; title; index }
    )
  | None -> (
      let* t =
        if Misc_utils.path_is_pdf path then
          of_pdf_path ~env path
        else
          of_text_path ~env path
      in
      let+ () = save_index ~env ~hash t.index in
      t
    )
