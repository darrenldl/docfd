open Result_syntax
open Docfd_lib

type t = {
  search_mode : Search_mode.t;
  path : string;
  path_parts : string list;
  path_date : Timedesc.Date.t option;
  mod_time : Timedesc.t;
  title : string option;
  doc_id : int64;
  doc_hash : string;
  word_ids : Int_set.t;
  search_scope : Diet.Int.t option;
  links : Link.t array;
  link_index_of_start_pos : int Int_map.t;
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
  let path_parts = Tokenization.tokenize ~drop_spaces:false path
    |> List.of_seq
  in
  (path_parts)

let compute_link_index_of_start_pos links =
  CCArray.foldi (fun acc i link ->
      Int_map.add link.Link.start_pos i acc
    )
    Int_map.empty
    links

let search_mode (t : t) = t.search_mode

let path (t : t) = t.path

let path_parts (t : t) = t.path_parts

let path_date (t : t) = t.path_date

let mod_time (t : t) = t.mod_time

let title (t : t) = t.title

let word_ids (t : t) = t.word_ids

let doc_hash (t : t) = t.doc_hash

let doc_id (t : t) = t.doc_id

let search_scope (t : t) = t.search_scope

let last_scan (t : t) = t.last_scan

let links (t : t) = t.links

let link_index_of_start_pos (t : t) = t.link_index_of_start_pos

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
  type order = [
    | `Asc
    | `Desc
  ]

  let mod_time order d0 d1 =
    match order with
    | `Asc ->
      Timedesc.compare_chrono_min (mod_time d0) (mod_time d1)
    | `Desc ->
      Timedesc.compare_chrono_min (mod_time d1) (mod_time d0)

  let path order d0 d1 =
    match order with
    | `Asc ->
      String.compare (path d0) (path d1)
    | `Desc ->
      String.compare (path d1) (path d0)

  let path_date order d0 d1 =
    let fallback () = path order d0 d1 in
    match path_date d0, path_date d1 with
    | None, None -> fallback ()
    | None, Some _ -> (
        (* Always shuffle document with no path date to the back. *)
        1
      )
    | Some _, None -> (
        (* Always shuffle document with no path date to the back. *)
        -1
      )
    | Some x0, Some x1 -> (
        match order with
        | `Asc -> (
            match Timedesc.Date.compare x0 x1 with
            | 0 -> fallback ()
            | n -> n
          )
        | `Desc -> (
            match Timedesc.Date.compare x1 x0 with
            | 0 -> fallback ()
            | n -> n
          )
      )
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
    | `Text | `Other -> (
        of_path_to_text ~env ~doc_id ~doc_hash search_mode last_scan path
      )
end

module Date_extraction = struct
  let yyyy = "(\\d{4})"

  let mm = "([01]\\d)"

  let mmm = "(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)"

  let mmmm = "(january|february|march|april|may|june|july|august|september|october|november|december)"

  let dd = "([0-3]\\d)"

  let int_of_month_string s =
    match String.lowercase_ascii (String.sub s 0 3) with
    | "jan" -> 1
    | "feb" -> 2
    | "mar" -> 3
    | "apr" -> 4
    | "may" -> 5
    | "jun" -> 6
    | "jul" -> 7
    | "aug" -> 8
    | "sep" -> 9
    | "oct" -> 10
    | "nov" -> 11
    | "dec" -> 12
    | _ -> failwith "unexpected case"

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

  let yyyy_month_dd ~month ~reverse =
    let re =
      let g1, g3 =
        if not reverse then (
          (yyyy, dd)
        ) else (
          (dd, yyyy)
        )
      in
      Fmt.str
        "(?:^|.*[^\\d])%s[^A-Za-z\\d]?%s[^A-Za-z\\d]?%s(?:$|[^\\d])"
        g1
        month
        g3
      |> Re.Pcre.re
      |> Re.no_case
      |> Re.compile
    in
    fun s ->
      try
        let g = Re.exec re s in
        let start = Re.Group.start g 1 in
        let y_group_index, d_group_index =
          if not reverse then (
            (1, 3)
          ) else (
            (3, 1)
          )
        in
        let y = Re.Group.get g y_group_index |> int_of_string in
        let m = int_of_month_string (Re.Group.get g 2) in
        let d = Re.Group.get g d_group_index |> int_of_string in
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
        yyyy_month_dd ~month:mmm ~reverse:true;
        yyyy_month_dd ~month:mmm ~reverse:false;
        yyyy_month_dd ~month:mmmm ~reverse:true;
        yyyy_month_dd ~month:mmmm ~reverse:false;
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
    path_date : Timedesc.Date.t option;
    mod_time : Timedesc.t;
    title : string option;
    raw : Index.Raw.t;
    links : Link.t array;
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
    let path_parts = compute_path_parts path in
    let path_date = Date_extraction.extract path in
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
    let links = Index.Raw.links raw in
    {
      search_mode;
      path;
      path_parts;
      path_date;
      mod_time;
      doc_id;
      doc_hash;
      title;
      raw;
      links;
      last_scan;
    }
end

let of_ir2 db ~already_in_transaction (ir : Ir2.t) : t =
  let
    {
      Ir2.search_mode;
      path;
      path_parts;
      path_date;
      mod_time;
      title;
      doc_id;
      doc_hash;
      raw;
      links;
      last_scan;
    } = ir in
  Word_db.write_to_db db ~already_in_transaction;
  Index.write_raw_to_db db ~already_in_transaction ~doc_id raw;
  let link_index_of_start_pos = compute_link_index_of_start_pos links in
  {
    search_mode;
    path;
    path_parts;
    path_date;
    mod_time;
    title;
    doc_id;
    doc_hash;
    word_ids = Index.Raw.word_ids raw;
    search_scope = None;
    links;
    link_index_of_start_pos;
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
    let path_parts = compute_path_parts path in
    let path_date = Date_extraction.extract path in
    let stats = Unix.stat path in
    let mod_time = Timedesc.of_timestamp_float_s_exn stats.Unix.st_mtime in
    let links = Index.links ~doc_id in
    Ok
      {
        search_mode;
        path;
        path_parts;
        path_date;
        mod_time;
        title;
        doc_id;
        doc_hash;
        word_ids = Index.word_ids ~doc_id;
        search_scope = None;
        links;
        link_index_of_start_pos = compute_link_index_of_start_pos links;
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

let satisfies_filter_exp pool ~global_first_word_candidates_lookup (exp : Filter_exp.t) (t : t) : bool =
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
                List.exists (fun path_part ->
                    Search_phrase.Enriched_token.compatible_with_word token path_part
                  )
                  t.path_parts
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
            ~global_first_word_candidates_lookup
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
