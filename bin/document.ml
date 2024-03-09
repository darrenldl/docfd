open Result_syntax
open Docfd_lib

type t = {
  path : string;
  title : string option;
  index : Index.t;
  last_scan : Timedesc.t;
}

let path (t : t) = t.path

let title (t : t) = t.title

let index (t : t) = t.index

let last_scan (t : t) = t.last_scan

let make ~path : t =
  {
    path;
    title = None;
    index = Index.make ();
    last_scan = Timedesc.now ~tz_of_date_time:Params.tz ();
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

let clean_up_cache_dir ~cache_dir =
  let all_files =
    Sys.readdir cache_dir
    |> Array.to_list
    |> List.map (fun x ->
        Filename.concat cache_dir x)
    |> List.filter (fun x ->
        not (Sys.is_directory x) && Filename.extension x = Params.index_file_ext)
  in
  let all_files_arr =
    all_files
    |> List.map (fun x ->
        let stat = Unix.stat x in
        let modification_time = stat.st_mtime in
        (x, modification_time)
      )
    |> Array.of_list
  in
  let file_count = Array.length all_files_arr in
  if file_count > !Params.cache_size then (
    Array.sort (fun (_x1, x2) (_y1, y2) -> Float.compare y2 x2) all_files_arr;
    for i = !Params.cache_size to file_count - 1 do
      let path, _mtime = all_files_arr.(i) in
      Sys.remove path
    done
  )

let save_index ~env ~hash index : (unit, string) result =
  match !Params.cache_dir with
  | None -> Ok ()
  | Some cache_dir -> (
      let fs = Eio.Stdenv.fs env in
      let path =
        Eio.Path.(fs /
                  Filename.concat cache_dir (Fmt.str "%s%s" hash Params.index_file_ext))
      in
      let json = Index.to_json index in
      try
        Eio.Path.save ~create:(`Or_truncate 0o644) path (Yojson.Safe.to_string json);
        clean_up_cache_dir ~cache_dir;
        Ok ()
      with
      | _ -> Error (Fmt.str "failed to save index to %s" hash)
    )

let find_index ~env ~hash : Index.t option =
  match !Params.cache_dir with
  | None -> None
  | Some cache_dir -> (
      let fs = Eio.Stdenv.fs env in
      try
        let path_str =
          Filename.concat cache_dir (Fmt.str "%s.index" hash)
        in
        let path =
          Eio.Path.(fs / path_str)
        in
        refresh_modification_time ~path:path_str;
        let json = Yojson.Safe.from_string (Eio.Path.load path) in
        Index.of_json json
      with
      | _ -> None
    )

module Of_path = struct
  let text ~env path : (t, string) result =
    let fs = Eio.Stdenv.fs env in
    try
      Eio.Path.(with_lines (fs / path))
        (fun lines ->
           Ok (parse_lines ~path lines)
        )
    with
    | _ -> Error (Printf.sprintf "failed to read file: %s" (Filename.quote path))

  let pdf ~env path : (t, string) result =
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
    | _ -> Error (Printf.sprintf "failed to read file: %s" (Filename.quote path))

  (*let docx ~env path : (t, string) result =
    let proc_mgr = Eio.Stdenv.process_mgr env in
    let out_dir = Filename.temp_dir "docfd-" "" in
    let args = [ "--convert-to"; "pdf"; "--outdir"; out_dir; path ]
    let cmd =
    in
    Proc_utils.run ~proc_mgr cmd;
    pdf ~env path
    |> Result.map (fun doc -> { doc with path }) *)
end

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
      Ok { path; title; index; last_scan = Timedesc.now ~tz_of_date_time:Params.tz () }
    )
  | None -> (
      let* t =
        if Misc_utils.path_is `PDF path then
          Of_path.pdf ~env path
        else
          Of_path.text ~env path
      in
      let+ () = save_index ~env ~hash t.index in
      t
    )
