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

let refresh_modification_time ~path =
  let time = Unix.time () in
  Unix.utimes path time time

let reset_search_scope_to_full (t : t) : t =
  { t with search_scope = None }

let inter_search_scope (x : Diet.Int.t) (t : t) : t =
  let search_scope =
    match t.search_scope with
    | None -> x
    | Some y -> Diet.Int.inter x y
  in
  { t with search_scope = Some search_scope }

module Ir0 = struct
  type t = {
    search_mode : Search_mode.t;
    doc_hash : string;
    path : string;
    last_scan : Timedesc.t;
  }

  let of_path ~(env : Eio_unix.Stdenv.base) search_mode ?doc_hash path : (t, string) result =
    let* doc_hash =
      match doc_hash with
      | Some x -> Ok x
      | None -> BLAKE2B.hash_of_file ~env ~path
    in
    Ok {
      search_mode;
      doc_hash;
      path;
      last_scan = Timedesc.now ~tz_of_date_time:Params.tz ();
    }
end

module Ir1 = struct
  type t = {
    search_mode : Search_mode.t;
    doc_hash : string;
    path : string;
    data : [ `Lines of string Dynarray.t | `Pages of string list Dynarray.t ];
    last_scan : Timedesc.t;
  }

  let of_path_to_text ~env ~doc_hash search_mode last_scan path : (t, string) result =
    let fs = Eio.Stdenv.fs env in
    try
      let data =
        Eio.Path.(with_lines (fs / path))
          (fun lines ->
             `Lines (Dynarray.of_seq lines)
          )
      in
      Ok {
        search_mode;
        doc_hash;
        path;
        data;
        last_scan;
      }
    with
    | Failure _
    | End_of_file
    | Eio.Buf_read.Buffer_limit_exceeded -> (
        Error (Printf.sprintf "failed to read file: %s" (Filename.quote path))
      )

  let of_path_to_pdf ~env ~doc_hash search_mode last_scan path : (t, string) result =
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
      let data = `Pages (Dynarray.of_seq pages) in
      Ok {
        search_mode;
        doc_hash;
        path;
        data;
        last_scan;
      }
    with
    | Failure _
    | End_of_file
    | Eio.Buf_read.Buffer_limit_exceeded -> (
        Error (Printf.sprintf "failed to read file: %s" (Filename.quote path))
      )

  let of_path_to_pandoc_supported_format ~env ~doc_hash search_mode last_scan path : (t, string) result =
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
        let data = `Lines (Dynarray.of_list lines) in
        Ok {
          search_mode;
          doc_hash;
          path;
          data;
          last_scan;
        }
      )

  let of_ir0 ~(env : Eio_unix.Stdenv.base) (ir0 : Ir0.t) : (t, string) result =
    let { Ir0.search_mode; doc_hash; path; last_scan } = ir0 in
    match File_utils.format_of_file path with
    | `PDF -> (
        of_path_to_pdf ~env ~doc_hash search_mode last_scan path
      )
    | `Pandoc_supported_format -> (
        of_path_to_pandoc_supported_format ~env ~doc_hash search_mode last_scan path
      )
    | `Text -> (
        of_path_to_text ~env ~doc_hash search_mode last_scan path
      )
end

module Ir2 = struct
  type t = {
    search_mode : Search_mode.t;
    doc_hash : string;
    path : string;
    title : string option;
    raw : Index.Raw.t;
    last_scan : Timedesc.t;
  }

  type work_stage =
    | Title
    | Content

  let parse_lines pool ~doc_hash search_mode last_scan ~path (s : string Seq.t) : t =
    let rec aux (stage : work_stage) title s =
      match stage with
      | Content -> (
          let raw = Index.Raw.of_lines pool s in
          { search_mode; path; doc_hash; title; raw; last_scan }
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

  let parse_pages pool ~doc_hash search_mode last_scan ~path (s : string list Seq.t) : t =
    let rec aux (stage : work_stage) title s =
      match stage with
      | Content -> (
          let raw = Index.Raw.of_pages pool s in
          { search_mode; path; doc_hash; title; raw; last_scan }
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

  let of_ir1 pool (ir : Ir1.t) : t =
    let { Ir1.search_mode; doc_hash; path; data; last_scan } = ir in
    match data with
    | `Lines x -> (
        parse_lines pool ~doc_hash search_mode last_scan ~path (Dynarray.to_seq x)
      )
    | `Pages x -> (
        parse_pages pool ~doc_hash search_mode last_scan ~path (Dynarray.to_seq x)
      )
end

let of_ir2 db (ir : Ir2.t) : t =
  let { Ir2.search_mode; path; title; doc_hash; raw; last_scan } = ir in
  Index.load_raw_into_db db ~doc_hash raw;
  {
    search_mode;
    path;
    title;
    doc_hash;
    search_scope = None;
    last_scan;
  }

let of_path ~(env : Eio_unix.Stdenv.base) pool search_mode ?doc_hash path : (t, string) result =
  let open Sqlite3_utils in
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
    let* ir0 = Ir0.of_path ~env search_mode ~doc_hash path in
    let* ir1 = Ir1.of_ir0 ~env ir0 in
    let ir2 = Ir2.of_ir1 pool ir1 in
    with_db (fun db ->
        Ok (of_ir2 db ir2)
      )
  )

let satisfies_query (exp : Query_exp.t) (t : t) : bool =
  let open Query_exp in
  let rec aux exp =
    match exp with
    | Empty -> true
    | Path_date _ -> false
    | Path_fuzzy _ -> false
    | Path_glob glob -> (
        Glob.is_empty glob || Glob.match_ glob t.path
      )
    | Ext ext -> (
        File_utils.extension_of_file t.path = ext
      )
    | Binary_op (op, e1, e2) -> (
        match op with
        | And -> aux e1 && aux e2
        | Or -> aux e1 || aux e2
      )
  in
  aux exp
