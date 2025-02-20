open Result_syntax
open Docfd_lib

type t = {
  search_mode : Search_mode.t;
  path : string;
  title : string option;
  doc_hash : string;
  search_scope : Diet.Int.t option;
  last_scan : Timedesc.t;
}

let search_mode (t : t) = t.search_mode

let path (t : t) = t.path

let title (t : t) = t.title

let doc_hash (t : t) = t.doc_hash

let search_scope (t : t) = t.search_scope

let last_scan (t : t) = t.last_scan

let make ~doc_hash ~path ~title search_mode : t =
  {
    search_mode;
    path;
    title;
    doc_hash;
    search_scope = None;
    last_scan = Timedesc.now ~tz_of_date_time:Params.tz ();
  }

type work_stage =
  | Title
  | Content

let parse_lines pool ~doc_hash search_mode ~path (s : string Seq.t) : t =
  let rec aux (stage : work_stage) title s =
    match stage with
    | Content -> (
        Index.index_lines pool ~doc_hash s;
        make ~doc_hash ~path ~title search_mode
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

let parse_pages pool ~doc_hash search_mode ~path (s : string list Seq.t) : t =
  let rec aux (stage : work_stage) title s =
    match stage with
    | Content -> (
        Index.index_pages pool ~doc_hash s;
        make ~doc_hash ~path ~title search_mode
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

let clean_up_cache_dir ~cache_dir =
  let all_files =
    Sys.readdir cache_dir
    |> Array.to_seq
    |> Seq.map (fun x ->
        Filename.concat cache_dir x)
    |> Seq.filter (fun x ->
        match File_utils.typ_of_path x with
        | Some (`File, _) -> File_utils.extension_of_file x = Params.index_file_ext
        | _ -> false
      )
    |> Array.of_seq
  in
  let file_count = Array.length all_files in
  if file_count > !Params.cache_soft_limit + 100 then (
    let all_files =
      all_files
      |> Array.map (fun x ->
          let stat = Unix.stat x in
          let modification_time = stat.st_mtime in
          (x, modification_time)
        )
    in
    Array.sort (fun (_x1, x2) (_y1, y2) -> Float.compare y2 x2) all_files;
    for i = !Params.cache_soft_limit to file_count - 1 do
      let path, _mtime = all_files.(i) in
      Sys.remove path
    done
  )

let inter_search_scope (x : Diet.Int.t) (t : t) : t =
  let search_scope =
    match t.search_scope with
    | None -> x
    | Some y -> Diet.Int.inter x y
  in
  { t with search_scope = Some search_scope }

module Of_path = struct
  let text ~env pool ~doc_hash search_mode path : (t, string) result =
    let fs = Eio.Stdenv.fs env in
    try
      Eio.Path.(with_lines (fs / path))
        (fun lines ->
           Ok (parse_lines pool ~doc_hash search_mode ~path lines)
        )
    with
    | Failure _
    | End_of_file
    | Eio.Buf_read.Buffer_limit_exceeded -> (
        Error (Printf.sprintf "failed to read file: %s" (Filename.quote path))
      )

  let pdf ~env pool ~doc_hash search_mode path : (t, string) result =
    let proc_mgr = Eio.Stdenv.process_mgr env in
    let fs = Eio.Stdenv.fs env in
    try
      let cmd = [ "pdftotext"; path; "-" ] in
      let pages =
        match Proc_utils.run_return_stdout ~proc_mgr ~fs ~split_mode:`On_form_feed cmd with
        | None -> Seq.empty
        | Some pages -> (
            List.to_seq pages
            |> Seq.map (fun page -> String.split_on_char '\n' page)
          )
      in
      Ok (parse_pages pool ~doc_hash search_mode ~path pages)
    with
    | Failure _
    | End_of_file
    | Eio.Buf_read.Buffer_limit_exceeded -> (
        Error (Printf.sprintf "failed to read file: %s" (Filename.quote path))
      )

  let pandoc_supported_format ~env pool ~doc_hash search_mode path : (t, string) result =
    let proc_mgr = Eio.Stdenv.process_mgr env in
    let fs = Eio.Stdenv.fs env in
    let ext = File_utils.extension_of_file path in
    let from_format = ext
                      |> String_utils.remove_leading_dots
                      |> (fun s ->
                          match s with
                          | "htm" -> "html"
                          | _ -> s
                        )
    in
    let cmd = [ "pandoc"
              ; "--from"
              ; from_format
              ; "--to"
              ; "plain"
              ; "--wrap"
              ; "none"
              ; path
              ]
    in
    let error_msg = Fmt.str "failed to extract text from %s" (Filename.quote path) in
    match
      Proc_utils.run_return_stdout
        ~proc_mgr
        ~fs
        ~split_mode:`On_line_split
        cmd
    with
    | None -> (
        Error error_msg
      )
    | Some lines -> (
        try
          List.to_seq lines
          |> parse_lines pool ~doc_hash search_mode ~path
          |> Result.ok
        with
        | _ -> Error error_msg
      )
end

let of_path ~(env : Eio_unix.Stdenv.base) pool search_mode ?doc_hash path : (t, string) result =
  let* doc_hash =
    match doc_hash with
    | Some x -> Ok x
    | None -> BLAKE2B.hash_of_file ~env ~path
  in
  if Index.is_indexed ~doc_hash then (
    let title =
      if Index.global_line_count ~doc_hash = 0 then
        None
      else
        Some (Index.line_of_global_line_num ~doc_hash 0)
    in
    Ok
      {
        search_mode;
        path;
        title;
        doc_hash;
        search_scope = None;
        last_scan = Timedesc.now ~tz_of_date_time:Params.tz ()
      }
  ) else (
    match File_utils.format_of_file path with
    | `PDF -> (
        Of_path.pdf ~env pool ~doc_hash search_mode path
      )
    | `Pandoc_supported_format -> (
        Of_path.pandoc_supported_format ~env pool ~doc_hash search_mode path
      )
    | `Text -> (
        Of_path.text ~env pool ~doc_hash search_mode path
      )
  )
