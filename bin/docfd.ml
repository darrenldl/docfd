open Cmdliner
open Lwd_infix
open Docfd_lib

let stdin_is_atty () =
  Unix.isatty Unix.stdin

let stdout_is_atty () =
  Unix.isatty Unix.stdout

let max_depth_arg_name = "max-depth"

let max_depth_arg =
  let doc =
    "Scan up to N levels in the file tree."
  in
  Arg.(
    value
    & opt int Params.default_max_file_tree_depth
    & info [ max_depth_arg_name ] ~doc ~docv:"N"
  )

let exts_arg_name = "exts"

let exts_arg =
  let doc =
    "File extensions to use, comma separated."
  in
  Arg.(
    value
    & opt string Params.default_recognized_exts
    & info [ exts_arg_name ] ~doc ~docv:"EXTS"
  )

let add_exts_arg_name = "add-exts"

let add_exts_arg =
  let doc =
    "Additional file extensions to use, comma separated."
  in
  Arg.(
    value
    & opt string ""
    & info [ add_exts_arg_name ] ~doc ~docv:"EXTS"
  )

let max_fuzzy_edit_dist_arg_name = "max-fuzzy-edit"

let max_fuzzy_edit_dist_arg =
  let doc =
    "Maximum edit distance for fuzzy matches."
  in
  Arg.(
    value
    & opt int Params.default_max_fuzzy_edit_distance
    & info [ max_fuzzy_edit_dist_arg_name ] ~doc ~docv:"N"
  )

let max_word_search_dist_arg_name = "max-word-search-dist"

let max_word_search_dist_arg =
  let doc =
    "Maximum distance to look for the next matching word/symbol in search phrase. If two words are adjacent words, then they are 1 distance away from each other. Note that contiguous spaces count as one word/symbol as well."
  in
  Arg.(
    value
    & opt int Params.default_max_word_search_distance
    & info [ max_word_search_dist_arg_name ] ~doc ~docv:"N"
  )

let index_chunk_word_count_arg_name = "index-chunk-word-count"

let index_chunk_word_count_arg =
  let doc =
    "Number of words to send as a task unit to the thread pool for indexing."
  in
  Arg.(
    value
    & opt int Params.default_index_chunk_word_count
    & info [ index_chunk_word_count_arg_name ] ~doc ~docv:"N"
  )

let cache_dir_arg =
  let doc =
    "Index cache directory."
  in
  let home_dir =
    match Sys.getenv_opt "HOME" with
    | None -> (
        Fmt.pr "Error: Environment variable HOME is not set\n";
        exit 1
      )
    | Some home -> home
  in
  let cache_home =
    match Sys.getenv_opt "XDG_CACHE_HOME" with
    | None -> Filename.concat home_dir ".cache"
    | Some x -> x
  in
  Arg.(
    value
    & opt string (Filename.concat cache_home "docfd")
    & info [ "cache-dir" ] ~doc ~docv:"DIR"
  )

let cache_size_arg_name = "cache-size"

let cache_size_arg =
  let doc =
    "Maximum number of indices to cache. One index corresponds to one file."
  in
  Arg.(
    value
    & opt int Params.default_cache_size
    & info [ cache_size_arg_name ] ~doc ~docv:"N"
  )

let no_cache_arg =
  let doc =
    Fmt.str "Disable caching."
  in
  Arg.(value & flag & info [ "no-cache" ] ~doc)

let index_only_arg =
  let doc =
    Fmt.str "Exit after indexing."
  in
  Arg.(value & flag & info [ "index-only" ] ~doc)

let debug_log_arg =
  let doc =
    Fmt.str "Specify debug log file and enable debug mode where additional info is displayed on UI. If FILE is -, then debug info is printed to stdout instead. Otherwise FILE is opened in append mode."
  in
  Arg.(
    value
    & opt string ""
    & info [ "debug-log" ] ~doc ~docv:"FILE"
  )

let list_files_recursively (dir : string) : string list =
  let l = ref [] in
  let add x =
    l := x :: !l
  in
  let rec aux depth path =
    if depth <= !Params.max_file_tree_depth then (
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
    ) else ()
  in
  aux 0 dir;
  !l

let open_pdf_path index ~path ~search_result =
  let path = Filename.quote path in
  let fallback = Fmt.str "xdg-open %s" path in
  let cmd =
    match search_result with
    | None -> fallback
    | Some search_result -> (
        let found_phrase = Search_result.found_phrase search_result in
        let page_nums = found_phrase
                        |> List.map (fun word ->
                            word.Search_result.found_word_pos
                            |> (fun pos -> Index.loc_of_pos pos index)
                            |> Index.Loc.line_loc
                            |> Index.Line_loc.page_num
                          )
                        |> List.sort_uniq Int.compare
        in
        let frequency_of_word_of_page : int String_map.t Int_map.t =
          List.fold_left (fun acc page_num ->
              let m = Misc_utils.frequencies_of_words
                  (Index.words_of_page_num page_num index)
              in
              Int_map.add page_num m acc
            )
            Int_map.empty
            page_nums
        in
        let (most_unique_word, most_unique_word_page_num) =
          found_phrase
          |> List.map (fun word ->
              let page_num =
                Index.loc_of_pos word.Search_result.found_word_pos index
                |> Index.Loc.line_loc
                |> Index.Line_loc.page_num
              in
              let freq =
                Int_map.find page_num frequency_of_word_of_page
                |> String_map.find word.Search_result.found_word
              in
              (word, page_num, freq)
            )
          |> List.fold_left (fun acc x ->
              let (_x_word, _x_page_num, x_freq) = x in
              match acc with
              | None -> Some x
              | Some (_acc_word, _acc_page_num, acc_freq) -> (
                  if x_freq > acc_freq then
                    Some x
                  else
                    acc
                )
            )
            None
          |> Option.get
          |> (fun (word, page_num, _freq) ->
              (word.found_word, page_num))
        in
        match Xdg_utils.default_pdf_viewer_desktop_file_path () with
        | None -> fallback
        | Some viewer_desktop_file_path -> (
            let flatpak_package_name =
              let s = Filename.basename viewer_desktop_file_path in
              Option.value ~default:s
                (CCString.chop_suffix ~suf:".desktop" s)
            in
            let viewer_desktop_file_path_lowercase_ascii =
              String.lowercase_ascii viewer_desktop_file_path
            in
            let contains sub =
              CCString.find ~sub viewer_desktop_file_path_lowercase_ascii >= 0
            in
            let make_command name args =
              if contains "flatpak" then
                Fmt.str "flatpak run %s %s" flatpak_package_name args
              else
                Fmt.str "%s %s" name args
            in
            let page_num = most_unique_word_page_num + 1 in
            if contains "okular" then
              make_command "okular"
                (Fmt.str "--page %d --find %s %s" page_num most_unique_word path)
            else if contains "evince" then
              make_command "evince"
                (Fmt.str "--page-index %d --find %s %s" page_num most_unique_word path)
            else if contains "xreader" then
              make_command "xreader"
                (Fmt.str "--page-index %d --find %s %s" page_num most_unique_word path)
            else if contains "atril" then
              make_command "atril"
                (Fmt.str "--page-index %d --find %s %s" page_num most_unique_word path)
            else if contains "mupdf" then
              make_command "mupdf" (Fmt.str "%s %d" path page_num)
            else
              fallback
          )
      )
  in
  Proc_utils.run_in_background cmd |> ignore

let open_text_path index document_src ~editor ~path ~search_result =
  let path = Filename.quote path in
  let fallback = Fmt.str "%s %s" editor path in
  let cmd =
    match search_result with
    | None -> fallback
    | Some search_result -> (
        let first_word = List.hd @@ Search_result.found_phrase search_result in
        let first_word_loc = Index.loc_of_pos first_word.Search_result.found_word_pos index in
        let line_num = first_word_loc
                       |> Index.Loc.line_loc
                       |> Index.Line_loc.line_num_in_page
                       |> (fun x -> x + 1)
        in
        match Filename.basename editor with
        | "nano" ->
          Fmt.str "%s +%d %s" editor line_num path
        | "nvim" | "vim" | "vi" ->
          Fmt.str "%s +%d %s" editor line_num path
        | "kak" ->
          Fmt.str "%s +%d %s" editor line_num path
        | "hx" ->
          Fmt.str "%s %s:%d" editor path line_num
        | "emacs" ->
          Fmt.str "%s +%d %s" editor line_num path
        | "micro" ->
          Fmt.str "%s %s:%d" editor path line_num
        | _ ->
          fallback
      )
  in
  let cmd =
    match document_src with
    | Ui_base.Stdin _ -> Fmt.str "</dev/tty %s" cmd
    | _ -> cmd
  in
  Sys.command cmd |> ignore

let do_if_debug (f : out_channel -> unit) =
  match !Params.debug_output with
  | None -> ()
  | Some oc -> (
      f oc
    )

let run
    ~(env : Eio_unix.Stdenv.base)
    (debug_log : string)
    (max_depth : int)
    (max_fuzzy_edit_dist : int)
    (max_word_search_dist : int)
    (index_chunk_word_count : int)
    (exts : string)
    (additional_exts : string)
    (cache_dir : string)
    (cache_size : int)
    (no_cache : bool)
    (index_only : bool)
    (files : string list)
  =
  if max_depth < 1 then (
    Fmt.pr "Error: Invalid %s: cannot be < 1\n" max_depth_arg_name;
    exit 1
  );
  if max_fuzzy_edit_dist < 0 then (
    Fmt.pr "Error: Invalid %s: cannot be < 0\n" max_fuzzy_edit_dist_arg_name;
    exit 1
  );
  if max_word_search_dist < 1 then (
    Fmt.pr "Error: Invalid %s: cannot be < 1\n" max_word_search_dist_arg_name;
    exit 1
  );
  if index_chunk_word_count < 1 then (
    Fmt.pr "Error: Invalid %s: cannot be < 1\n" index_chunk_word_count_arg_name;
    exit 1
  );
  if cache_size < 1 then (
    Fmt.pr "Error: Invalid %s: cannot be < 1\n" cache_size_arg_name;
    exit 1
  );
  Params.debug_output := (match debug_log with
      | "" -> None
      | "-" -> Some stdout
      | _ -> (
          try
            Some (
              open_out_gen
                [ Open_append; Open_creat; Open_wronly; Open_text ]
                0o644
                debug_log
            )
          with
          | _ -> (
              Printf.printf "Error: Failed to open debug log file %s" debug_log;
              exit 1
            )
        )
    );
  Params.max_file_tree_depth := max_depth;
  Params.max_fuzzy_edit_distance := max_fuzzy_edit_dist;
  Params.max_word_search_distance := max_word_search_dist;
  Params.index_chunk_word_count := index_chunk_word_count;
  Params.cache_size := cache_size;
  Params.cache_dir := (
    if no_cache then (
      None
    ) else (
      if Sys.file_exists cache_dir then (
        if not (Sys.is_directory cache_dir) then (
          Fmt.pr "Error: \"%s\" is not a directory\n" cache_dir;
          exit 1
        ) else (
          Some cache_dir
        )
      ) else (
        (try
           Sys.mkdir cache_dir 0o755
         with
         | _ -> (
             Fmt.pr "Error: Failed to create directory \"%s\"\n" cache_dir;
             exit 1
           )
        );
        Some cache_dir
      )
    )
  );
  (match Sys.getenv_opt "VISUAL", Sys.getenv_opt "EDITOR" with
   | None, None -> (
       Printf.printf "Error: Environment variable VISUAL or EDITOR needs to be set\n";
       exit 1
     )
   | Some editor, _
   | None, Some editor -> (
       Params.text_editor := editor;
     )
  );
  let recognized_exts =
    Fmt.str "%s,%s" exts additional_exts
    |> String.split_on_char ','
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
  do_if_debug (fun oc ->
      Printf.fprintf oc "Scanning for documents\n"
    );
  let compute_init_ui_mode_and_document_src () : Ui_base.ui_mode * Ui_base.document_src =
    if not (stdin_is_atty ()) then (
      match File_utils.read_in_channel_to_tmp_file stdin with
      | Ok tmp_file -> (
          Ui_base.(Ui_single_file, Stdin tmp_file)
        )
      | Error msg -> (
          Fmt.pr "Error: %s" msg;
          exit 1
        )
    ) else (
      match files with
      | [] -> Ui_base.(Ui_multi_file, Files [])
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
  let compute_document_src () =
    snd (compute_init_ui_mode_and_document_src ())
  in
  let init_ui_mode, init_document_src =
    compute_init_ui_mode_and_document_src ()
  in
  do_if_debug (fun oc ->
      Printf.fprintf oc "Scanning completed\n"
    );
  do_if_debug (fun oc ->
      match init_document_src with
      | Stdin _ -> Printf.fprintf oc "Document source: stdin\n"
      | Files files -> (
          Printf.fprintf oc "Document source: files\n";
          List.iter (fun file ->
              Printf.fprintf oc "File: %s\n" file;
            )
            files
        )
    );
  (match init_document_src with
   | Stdin _ -> ()
   | Files files -> (
       if List.exists Misc_utils.path_is_pdf files then (
         if not (Proc_utils.command_exists "pdftotext") then (
           Fmt.pr "Error: Command pdftotext not found\n";
           exit 1
         )
       );
       let file_count = List.length files in
       if file_count > !Params.cache_size then (
         do_if_debug (fun oc ->
             Printf.fprintf oc "File count %d exceeds cache size %d, caching disabled\n"
               file_count
               !Params.cache_size
           );
         Params.cache_dir := None
       )
     )
  );
  let document_store_of_document_src document_src =
    let all_documents =
      match document_src with
      | Ui_base.Stdin path -> (
          match Document.of_path ~env path with
          | Ok x -> [ x ]
          | Error msg ->  (
              Fmt.pr "Error: %s" msg;
              exit 1
            )
        )
      | Files files -> (
          Eio.Fiber.List.filter_map ~max_fibers:Task_pool.size (fun path ->
              do_if_debug (fun oc ->
                  Printf.fprintf oc "Loading document: %s\n" path;
                );
              match Document.of_path ~env path with
              | Ok x -> (
                  do_if_debug (fun oc ->
                      Printf.fprintf oc "Document %s loaded successfully\n" path;
                    );
                  Some x
                )
              | Error msg -> (
                  do_if_debug (fun oc ->
                      Printf.fprintf oc "%s\n" msg
                    );
                  None
                )
            ) files
        )
    in
    all_documents
    |> List.to_seq
    |> Document_store.of_seq
  in
  Ui_base.Vars.init_ui_mode := init_ui_mode;
  let init_document_store = document_store_of_document_src init_document_src in
  if index_only then (
    exit 0
  );
  Lwd.set Ui_base.Vars.document_store init_document_store;
  (match init_ui_mode with
   | Ui_base.Ui_single_file -> Lwd.set Ui_base.Vars.Single_file.document_store init_document_store
   | _ -> ()
  );
  Ui_base.Vars.eio_env := Some env;
  Lwd.set Ui_base.Vars.ui_mode init_ui_mode;
  let root : Nottui.ui Lwd.t =
    let$* ui_mode : Ui_base.ui_mode = Lwd.get Ui_base.Vars.ui_mode in
    match ui_mode with
    | Ui_multi_file -> Multi_file_view.main
    | Ui_single_file -> Single_file_view.main
  in
  let rec loop () =
    Sys.command "clear" |> ignore;
    let (term, tty_fd) =
      match init_document_src with
      | Stdin _ -> (
          let input =
            Unix.(openfile "/dev/tty" [ O_RDWR ] 0666)
          in
          (Notty_unix.Term.create ~input (), Some input)
        )
      | Files _ -> (
          (Notty_unix.Term.create (), None)
        )
    in
    Ui_base.Vars.term := Some term;
    Ui_base.Vars.action := None;
    Lwd.set Ui_base.Vars.quit false;
    Ui_base.ui_loop
      ~quit:Ui_base.Vars.quit
      ~term
      root;
    (match tty_fd with
     | None -> ()
     | Some fd -> Unix.close fd
    );
    Notty_unix.Term.release term;
    match !Ui_base.Vars.action with
    | None -> ()
    | Some action -> (
        match action with
        | Ui_base.Recompute_document_src -> (
            let document_src = compute_document_src () in
            let old_document_store = Lwd.peek Ui_base.Vars.document_store in
            let content_reqs = Document_store.content_reqs old_document_store in
            let search_phrase = Document_store.search_phrase old_document_store in
            let document_store =
              document_store_of_document_src document_src
              |> Document_store.update_content_reqs content_reqs
              |> Document_store.update_search_phrase search_phrase
            in
            Lwd.set Ui_base.Vars.document_store document_store;
            loop ()
          )
        | Open_file_and_search_result (doc, search_result) -> (
            if Misc_utils.path_is_pdf doc.path then (
              open_pdf_path
                doc.index
                ~path:doc.path
                ~search_result
            ) else (
              let old_stats = Unix.stat doc.path in
              open_text_path
                doc.index
                init_document_src
                ~editor:!Params.text_editor
                ~path:doc.path
                ~search_result;
              let new_stats = Unix.stat doc.path in
              if Float.abs (new_stats.st_mtime -. old_stats.st_mtime) >= Params.float_compare_margin then (
                (match Lwd.peek Ui_base.Vars.ui_mode with
                 | Ui_single_file -> Single_file_view.reload_document doc
                 | Ui_multi_file -> Multi_file_view.reload_document doc
                );
              );
            );
            loop ()
          )
      )
  in
  loop ();
  (match init_document_src with
   | Stdin tmp_file -> (
       try
         Sys.remove tmp_file
       with
       | _ -> ()
     )
   | Files _ -> ()
  );
  (match debug_log with
   | "-" -> ()
   | _ -> (
       match !Params.debug_output with
       | None -> ()
       | Some oc -> (
           close_out oc
         )
     )
  )

let files_arg = Arg.(value & pos_all string [ "." ] & info [])

let cmd ~env =
  let doc = "TUI multiline fuzzy document finder" in
  let version = Version_string.s in
  Cmd.v (Cmd.info "docfd" ~version ~doc)
    Term.(const (run ~env)
          $ debug_log_arg
          $ max_depth_arg
          $ max_fuzzy_edit_dist_arg
          $ max_word_search_dist_arg
          $ index_chunk_word_count_arg
          $ exts_arg
          $ add_exts_arg
          $ cache_dir_arg
          $ cache_size_arg
          $ no_cache_arg
          $ index_only_arg
          $ files_arg)

let () = Eio_main.run (fun env ->
    exit (Cmd.eval (cmd ~env))
  )
