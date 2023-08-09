open Cmdliner
open Lwd_infix

let stdin_is_atty () =
  Unix.isatty Unix.stdin

let stdout_is_atty () =
  Unix.isatty Unix.stdout

let max_depth_arg =
  let doc =
    "Scan up to N levels in the file tree."
  in
  Arg.(value & opt int Params.default_max_file_tree_depth & info [ "max-depth" ] ~doc ~docv:"N")

let exts_arg =
  let doc =
    "File extensions to use, comma separated."
  in
  Arg.(value & opt string Params.default_recognized_exts & info [ "exts" ] ~doc ~docv:"EXTS")

let max_fuzzy_edit_distance_arg =
  let doc =
    "Maximum edit distance for fuzzy matches."
  in
  Arg.(value & opt int Params.default_max_fuzzy_edit_distance & info [ "max-fuzzy-edit" ] ~doc ~docv:"N")

let max_word_search_range_arg =
  let doc =
    "Maximum range to look for the next matching word/symbol in content search. Note that contiguous spaces count as one word/symbol as well."
  in
  Arg.(value & opt int Params.default_max_word_search_range
       & info [ "max-word-search-range" ] ~doc ~docv:"N")

let index_chunk_word_count_arg =
  let doc =
    "Number of words to send as a task unit to the thread pool for indexing."
  in
  Arg.(value & opt int Params.default_index_chunk_word_count & info [ "index-chunk-word-count" ] ~doc ~docv:"N")

let debug_arg =
  let doc =
    Fmt.str "Display debug info."
  in
  Arg.(value & flag & info [ "debug" ] ~doc)

let list_files_recursively (dir : string) : string list =
  let l = ref [] in
  let add x =
    l := x :: !l
  in
  let rec aux depth path =
    if depth >= !Params.max_file_tree_depth then ()
    else (
      match Sys.is_directory path with
      | is_dir -> (
          if is_dir then (
            let next_choices =
              try
                Sys.readdir path
              with
              | _ -> [||]
            in
            Array.iter (fun f ->
                aux (depth + 1) (Filename.concat path f)
              )
              next_choices
          ) else (
            let ext = Filename.extension path in
            if List.mem ext !Params.recognized_exts then (
              add path
            )
          )
        )
      | exception _ -> ()
    )
  in
  aux 0 dir;
  !l

let run
    ~(env : Eio_unix.Stdenv.base)
    (debug : bool)
    (max_depth : int)
    (max_fuzzy_edit_distance : int)
    (max_word_search_range : int)
    (index_chunk_word_count : int)
    (exts : string)
    (files : string list)
  =
  Params.debug := debug;
  Params.max_file_tree_depth := max_depth;
  Params.max_fuzzy_edit_distance := max_fuzzy_edit_distance;
  Params.max_word_search_range := max_word_search_range;
  Params.index_chunk_word_count := index_chunk_word_count;
  let recognized_exts =
    String.split_on_char ',' exts
    |> List.map (fun s ->
        s
        |> Misc_utils.remove_leading_dots
        |> CCString.trim
      )
    |> List.filter (fun s -> s <> "")
    |> List.map (fun s -> Printf.sprintf ".%s" s)
  in
  (match recognized_exts with
   | [] -> (
       Fmt.pr "Error: No usable file extensions\n";
       exit 1
     )
   | _ -> ()
  );
  Params.recognized_exts := recognized_exts;
  List.iter (fun file ->
      if not (Sys.file_exists file) then (
        Fmt.pr "Error: File \"%s\" does not exist\n" file;
        exit 1
      )
    )
    files;
  if !Params.debug then (
    Printf.printf "Scanning for documents\n"
  );
  (match Sys.getenv_opt "HOME" with
   | None -> (
       Fmt.pr "Env variable HOME is not set\n";
       exit 1
     )
   | Some home -> (
       Params.index_dir := Filename.concat home Params.index_dir_name;
     )
  );
  let init_ui_mode, document_src =
    if not (stdin_is_atty ()) then
      Ui_base.(Ui_single_file, Stdin)
    else (
      match files with
      | [] -> Fmt.pr "Error: No files provided\n"; exit 1
      | [ f ] -> (
          if Sys.is_directory f then
            Ui_base.(Ui_multi_file, Files (list_files_recursively f))
          else
            Ui_base.(Ui_single_file, Files [ f ])
        )
      | _ -> (
          Ui_base.(Ui_multi_file,
                   Files (
                     files
                     |> List.to_seq
                     |> Seq.flat_map (fun f ->
                         if Sys.is_directory f then
                           List.to_seq (list_files_recursively f)
                         else
                           Seq.return f
                       )
                     |> List.of_seq
                     |> List.sort_uniq String.compare
                   )
                  )
        )
    )
  in
  if !Params.debug then (
    Printf.printf "Scanning completed\n"
  );
  if !Params.debug then (
    match document_src with
    | Stdin -> Printf.printf "Document source: stdin\n"
    | Files files -> (
        Printf.printf "Document source: files\n";
        List.iter (fun file ->
            Printf.printf "File: %s\n" file;
          )
          files
      )
  );
  (match document_src with
   | Stdin -> ()
   | Files files -> (
       if List.exists Misc_utils.path_is_pdf files then (
         if not (Proc_utils.command_exists "pdftotext") then (
           Fmt.pr "Error: Command pdftotext not found\n";
           exit 1
         )
       )
     )
  );
  let all_documents =
    match document_src with
    | Stdin ->
      [ Document.of_in_channel stdin ]
    | Files files ->
      Eio.Fiber.List.filter_map (fun path ->
          match Document.of_path ~env path with
          | Ok x -> Some x
          | Error _ -> None) files
  in
  match all_documents with
  | [] -> Printf.printf "No suitable documents found\n"
  | _ -> (
      Ui_base.Vars.init_ui_mode := init_ui_mode;
      let document_store = all_documents
                           |> List.to_seq
                           |> Document_store.of_seq
      in
      Lwd.set Ui_base.Vars.document_store document_store;
      (match init_ui_mode with
       | Ui_base.Ui_single_file -> Lwd.set Ui_base.Vars.Single_file.document_store document_store
       | _ -> ()
      );
      Ui_base.Vars.total_document_count := List.length all_documents;
      (match document_src with
       | Stdin -> (
           let input =
             Unix.(openfile "/dev/tty" [ O_RDWR ] 0666)
           in
           Ui_base.Vars.term := Some (Notty_unix.Term.create ~input ())
         )
       | Files _ -> (
           Ui_base.Vars.term := Some (Notty_unix.Term.create ());
         )
      );
      Ui_base.Vars.eio_env := Some env;
      Lwd.set Ui_base.Vars.ui_mode init_ui_mode;
      let root : Nottui.ui Lwd.t =
        let$* ui_mode : Ui_base.ui_mode = Lwd.get Ui_base.Vars.ui_mode in
        match ui_mode with
        | Ui_multi_file -> Multi_file_view.main
        | Ui_single_file -> Single_file_view.main
      in
      let term = Ui_base.term () in
      let rec loop () =
        Ui_base.Vars.file_to_open := None;
        Lwd.set Ui_base.Vars.quit false;
        Ui_base.ui_loop
          ~quit:Ui_base.Vars.quit
          ~term
          root;
        match !Ui_base.Vars.file_to_open with
        | None -> ()
        | Some doc -> (
            (match doc.path with
             | None -> ()
             | Some path ->
               if Misc_utils.path_is_pdf path then (
                 Proc_utils.run_in_background (Fmt.str "xdg-open %s" (Filename.quote path)) |> ignore;
               ) else (
                 match Sys.getenv_opt "VISUAL", Sys.getenv_opt "EDITOR" with
                 | None, None ->
                   Printf.printf "Error: Both env variables VISUAL and EDITOR are unset\n"; exit 1
                 | Some editor, _
                 | None, Some editor -> (
                     let old_stats = Unix.stat path in
                     Sys.command (Fmt.str "%s %s" editor (Filename.quote path)) |> ignore;
                     let new_stats = Unix.stat path in
                     if Float.abs (new_stats.st_mtime -. old_stats.st_mtime) >= 0.000_001 then (
                       (match Lwd.peek Ui_base.Vars.ui_mode with
                        | Ui_single_file -> Single_file_view.reload_document doc
                        | Ui_multi_file -> Multi_file_view.reload_document doc
                       );
                     );
                   )
               )
            );
            loop ()
          )
      in
      loop ();
      Notty_unix.Term.release term
    )

let files_arg = Arg.(value & pos_all string [ "." ] & info [])

let cmd ~env =
  let doc = "TUI fuzzy document finder" in
  let version = Version_string.s in
  Cmd.v (Cmd.info "docfd" ~version ~doc)
    Term.(const (run ~env)
          $ debug_arg
          $ max_depth_arg
          $ max_fuzzy_edit_distance_arg
          $ max_word_search_range_arg
          $ index_chunk_word_count_arg
          $ exts_arg
          $ files_arg)

let () = Eio_main.run (fun env ->
    exit (Cmd.eval (cmd ~env))
  )
