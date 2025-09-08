open Result_syntax
open Docfd_lib

type t = {
  search_mode : Search_mode.t;
  path : string;
  path_parts : string list;
  path_parts_ci : string list;
  path_date : Timedesc.Date.t option;
  mod_time : Timedesc.t;
  title : string option;
  doc_id : int64;
  doc_hash : string;
  word_ids : Int_set.t;
  search_scope : Diet.Int.t option;
  last_scan : Timedesc.t;
}

let equal (x : t) (y : t) =
  x.search_mode = y.search_mode
  &&
  String.equal x.path y.path
  &&
  String.equal x.doc_hash y.doc_hash
  &&
  Option.equal Diet.Int.equal x.search_scope y.search_scope

let compute_path_parts (path : string) =
  let path_parts = Tokenize.tokenize ~drop_spaces:false path
                   |> List.of_seq
  in
  let path_parts_ci = List.map String.lowercase_ascii path_parts in
  (path_parts, path_parts_ci)

let search_mode (t : t) = t.search_mode

let path (t : t) = t.path

let path_parts (t : t) = t.path_parts

let path_parts_ci (t : t) = t.path_parts_ci

let path_date (t : t) = t.path_date

let mod_time (t : t) = t.mod_time

let title (t : t) = t.title

let word_ids (t : t) = t.word_ids

let doc_hash (t : t) = t.doc_hash

let doc_id (t : t) = t.doc_id

let search_scope (t : t) = t.search_scope

let last_scan (t : t) = t.last_scan

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

module Compare = struct
  let mod_time d0 d1 =
    Timedesc.compare_chrono_min (mod_time d0) (mod_time d1)

  let path_date d0 d1 =
    match path_date d0, path_date d1 with
    | None, None -> mod_time d0 d1
    | None, Some _ -> -1
    | Some _, None -> 1
    | Some x0, Some x1 -> Timedesc.Date.compare x0 x1

  let path d0 d1 =
    String.compare (path d0) (path d1)
end

module Ir0 = struct
  type t = {
    search_mode : Search_mode.t;
    doc_id : int64;
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
    let doc_id = Doc_id_db.doc_id_of_doc_hash doc_hash in
    Ok {
      search_mode;
      doc_id;
      doc_hash;
      path;
      last_scan = Timedesc.now ~tz_of_date_time:Params.tz ();
    }
end

module Ir1 = struct
  type t = {
    search_mode : Search_mode.t;
    doc_id : int64;
    doc_hash : string;
    path : string;
    data : [ `Lines of string Dynarray.t | `Pages of string list Dynarray.t ];
    last_scan : Timedesc.t;
  }

  let of_path_to_text ~env ~doc_id ~doc_hash search_mode last_scan path : (t, string) result =
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
        doc_id;
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

  let of_path_to_pdf ~env ~doc_id ~doc_hash search_mode last_scan path : (t, string) result =
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
        doc_id;
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

  let of_path_to_pandoc_supported_format ~env ~doc_id ~doc_hash search_mode last_scan path : (t, string) result =
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
          doc_id;
          doc_hash;
          path;
          data;
          last_scan;
        }
      )

  let of_ir0 ~(env : Eio_unix.Stdenv.base) (ir0 : Ir0.t) : (t, string) result =
    let { Ir0.search_mode; doc_id; doc_hash; path; last_scan } = ir0 in
    match File_utils.format_of_file path with
    | `PDF -> (
        of_path_to_pdf ~env ~doc_id ~doc_hash search_mode last_scan path
      )
    | `Pandoc_supported_format -> (
        of_path_to_pandoc_supported_format ~env ~doc_id ~doc_hash search_mode last_scan path
      )
    | `Text -> (
        of_path_to_text ~env ~doc_id ~doc_hash search_mode last_scan path
      )
end

module Date_extract = struct
  let yyyy = "(\\d{4})"

  let mm = "([01]\\d)"

  let dd = "([0-3]\\d)"

  let yyyy_mm_dd =
    let re =
      Fmt.str
        "(?:^|.*[^\\d])%s[^\\d]%s[^\\d]%s(?:$|[^\\d])"
        yyyy
        mm
        dd
      |> Re.Pcre.re
      |> Re.compile
    in
    fun s ->
      try
        let g = Re.exec re s in
        let start = Re.Group.start g 1 in
        let y = Re.Group.get g 1 |> int_of_string in
        let m = Re.Group.get g 2 |> int_of_string in
        let d = Re.Group.get g 3 |> int_of_string in
        Some (start, (y, m, d))
      with
      | _ -> None

  let yyyymmdd =
    let re =
      Fmt.str
        "(?:^|.*[^\\d])%s%s%s"
        yyyy
        mm
        dd
      |> Re.Pcre.re
      |> Re.compile
    in
    fun s ->
      try
        let g = Re.exec re s in
        let start = Re.Group.start g 1 in
        let y = Re.Group.get g 1 |> int_of_string in
        let m = Re.Group.get g 2 |> int_of_string in
        let d = Re.Group.get g 3 |> int_of_string in
        Some (start, (y, m, d))
      with
      | _ -> None

  let extract s =
    let rec aux acc l =
      match l with
      | [] -> (
          match acc with
          | None -> None
          | Some (_start_match_pos, (year, month, day)) -> (
              match Timedesc.Date.Ymd.make ~year ~month ~day with
              | Ok date -> Some date
              | Error _ -> None
            )
        )
      | f :: fs -> (
          let acc =
            match acc, f s with
            | None, x -> x
            | Some x, None -> Some x
            | Some (start_match_pos, ymd),
              Some (start_match_pos', ymd') -> (
                if start_match_pos' > start_match_pos then (
                  Some (start_match_pos', ymd')
                ) else (
                  Some (start_match_pos, ymd)
                )
              )
          in
          aux acc fs
        )
    in
    aux
      None
      [
        yyyy_mm_dd;
        yyyymmdd;
      ]
end

module Ir2 = struct
  type t = {
    search_mode : Search_mode.t;
    doc_id : int64;
    doc_hash : string;
    path : string;
    path_parts : string list;
    path_parts_ci : string list;
    path_date : Timedesc.Date.t option;
    mod_time : Timedesc.t;
    title : string option;
    raw : Index.Raw.t;
    last_scan : Timedesc.t;
  }

  type work_stage =
    | Title
    | Content

  let parse_lines pool (s : string Seq.t) : string option * Index.Raw.t =
    let rec aux (stage : work_stage) title s =
      match stage with
      | Content -> (
          let raw = Index.Raw.of_lines pool s in
          (title, raw)
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

  let parse_pages pool (s : string list Seq.t) : string option * Index.Raw.t =
    let rec aux (stage : work_stage) title s =
      match stage with
      | Content -> (
          let raw = Index.Raw.of_pages pool s in
          (title, raw)
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
    let { Ir1.search_mode; doc_id; doc_hash; path; data; last_scan } = ir in
    let path_parts, path_parts_ci = compute_path_parts path in
    let path_date = Date_extract.extract path in
    let stats = Unix.stat path in
    let mod_time = Timedesc.of_timestamp_float_s_exn stats.Unix.st_mtime in
    let title, raw =
      match data with
      | `Lines x -> (
          parse_lines pool (Dynarray.to_seq x)
        )
      | `Pages x -> (
          parse_pages pool (Dynarray.to_seq x)
        )
    in
    {
      search_mode;
      path;
      path_parts;
      path_parts_ci;
      path_date;
      mod_time;
      doc_id;
      doc_hash;
      title;
      raw;
      last_scan;
    }
end

let of_ir2 db ~already_in_transaction (ir : Ir2.t) : t =
  let
    {
      Ir2.search_mode;
      path;
      path_parts;
      path_parts_ci;
      path_date;
      mod_time;
      title;
      doc_id;
      doc_hash;
      raw;
      last_scan;
    } = ir in
  Word_db.write_to_db db ~already_in_transaction;
  Index.write_raw_to_db db ~already_in_transaction ~doc_id raw;
  {
    search_mode;
    path;
    path_parts;
    path_parts_ci;
    path_date;
    mod_time;
    title;
    doc_id;
    doc_hash;
    word_ids = Index.Raw.word_ids raw;
    search_scope = None;
    last_scan;
  }

let of_path
    ~(env : Eio_unix.Stdenv.base)
    pool
    ~already_in_transaction
    search_mode
    ?doc_hash
    path
  : (t, string) result =
  let open Sqlite3_utils in
  let* doc_hash =
    match doc_hash with
    | Some x -> Ok x
    | None -> BLAKE2B.hash_of_file ~env ~path
  in
  if Index.is_indexed ~doc_hash then (
    let doc_id = Doc_id_db.doc_id_of_doc_hash doc_hash in
    let title =
      if Index.global_line_count ~doc_id = 0 then
        None
      else
        Some (Index.line_of_global_line_num ~doc_id 0)
    in
    let path_parts, path_parts_ci = compute_path_parts path in
    let path_date = Date_extract.extract path in
    let stats = Unix.stat path in
    let mod_time = Timedesc.of_timestamp_float_s_exn stats.Unix.st_mtime in
    Ok
      {
        search_mode;
        path;
        path_parts;
        path_parts_ci;
        path_date;
        mod_time;
        title;
        doc_id;
        doc_hash;
        word_ids = Index.word_ids ~doc_id;
        search_scope = None;
        last_scan = Timedesc.now ~tz_of_date_time:Params.tz ()
      }
  ) else (
    let* ir0 = Ir0.of_path ~env search_mode ~doc_hash path in
    let* ir1 = Ir1.of_ir0 ~env ir0 in
    let ir2 = Ir2.of_ir1 pool ir1 in
    let res =
      with_db (fun db ->
          Ok (of_ir2 db ~already_in_transaction ir2)
        )
    in
    res
  )

module ET = Search_phrase.Enriched_token

let satisfies_filter_exp pool ~first_word_candidates_lookup (exp : Filter_exp.t) (t : t) : bool =
  let open Filter_exp in
  let date_f (op : Filter_exp.compare_op) =
    match op with
    | Eq -> Timedesc.Date.equal
    | Le -> Timedesc.Date.le
    | Ge -> Timedesc.Date.ge
    | Lt -> Timedesc.Date.lt
    | Gt -> Timedesc.Date.gt
  in
  let rec aux exp =
    match exp with
    | Empty -> true
    | Path_date (op, date) -> (
        match t.path_date with
        | None -> false
        | Some path_date -> (
            date_f op path_date date
          )
      )
    | Mod_date (op, date) -> (
        date_f op (Timedesc.date t.mod_time) date
      )
    | Path_fuzzy exp -> (
        List.exists (fun phrase ->
            List.for_all (fun token ->
                match ET.data token with
                | `Explicit_spaces -> (
                    List.exists (fun path_part ->
                        Parser_components.is_space path_part.[0]
                      )
                      t.path_parts
                  )
                | `String token_word -> (
                    let token_word_ci = String.lowercase_ascii token_word in
                    let use_ci_match = String.equal token_word token_word_ci in
                    List.exists2 (fun path_part path_part_ci ->
                        match ET.match_typ token with
                        | `Fuzzy -> (
                            String.equal path_part_ci token_word_ci
                            || CCString.find ~sub:token_word_ci path_part_ci >= 0
                            || (Misc_utils.first_n_chars_of_string_contains ~n:5 path_part_ci token_word_ci.[0]
                                && Spelll.match_with (ET.automaton token) path_part_ci)
                          )
                        | `Exact -> (
                            if use_ci_match then (
                              String.equal token_word_ci path_part_ci
                            ) else (
                              String.equal token_word path_part
                            )
                          )
                        | `Prefix -> (
                            if use_ci_match then (
                              CCString.prefix ~pre:token_word_ci path_part_ci
                            ) else (
                              CCString.prefix ~pre:token_word path_part
                            )
                          )
                        | `Suffix -> (
                            if use_ci_match then (
                              CCString.suffix ~suf:token_word_ci path_part_ci
                            ) else (
                              CCString.suffix ~suf:token_word path_part
                            )
                          )
                      )
                      t.path_parts
                      t.path_parts_ci
                  )
              )
              (Search_phrase.enriched_tokens phrase)
          )
          (Search_exp.flattened exp)
      )
    | Path_glob glob -> (
        Glob.is_empty glob || Glob.match_ glob t.path
      )
    | Ext ext -> (
        File_utils.extension_of_file t.path = ext
      )
    | Content exp -> (
        try
          Index.search
            pool
            (Stop_signal.make ())
            ~terminate_on_result_found:true
            ~doc_id:t.doc_id
            ~doc_word_ids:(word_ids t)
            ~first_word_candidates_lookup
            ~within_same_line:false
            ~search_scope:None
            exp
          |> ignore;
          false
        with
        | Index.Search_job.Result_found -> true
      )
    | Binary_op (op, e1, e2) -> (
        match op with
        | And -> aux e1 && aux e2
        | Or -> aux e1 || aux e2
      )
    | Unary_op (op, e) -> (
        match op with
        | Not -> not (aux e)
      )
  in
  aux exp
