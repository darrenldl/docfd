open Cmdliner
open Lwd_infix
open Docfd_lib
open Debug_utils
open Misc_utils
open File_utils

let compute_paths_from_globs globs =
  Seq.iter (fun s ->
      match Glob.make s with
      | Some _ -> ()
      | None -> (
          exit_with_error_msg
            (Fmt.str "failed to parse glob pattern: \"%s\"" s)
        )
    ) globs;
  list_files_recursive_filter_by_globs globs

type file_constraints = {
  paths_were_originally_specified_by_user : bool;
  exts : string list;
  single_line_exts : string list;
  directly_specified_paths : String_set.t;
  globs : String_set.t;
  single_line_globs : String_set.t;
}

let make_file_constraints
    ~(exts : string list)
    ~(single_line_exts : string list)
    ~(paths : string list)
    ~(paths_from_file : string list option)
    ~(globs : string list)
    ~(single_line_globs : string list)
  : file_constraints =
  match
    paths,
    paths_from_file,
    globs,
    single_line_globs
  with
  | [], None, [], [] -> (
      {
        paths_were_originally_specified_by_user = false;
        exts;
        single_line_exts;
        directly_specified_paths = String_set.of_list [ "." ];
        globs = String_set.empty;
        single_line_globs = String_set.empty;
      }
    )
  | _, _, _, _ -> (
      let paths_from_file = Option.value ~default:[] paths_from_file in
      let directly_specified_paths = String_set.of_list (paths @ paths_from_file) in
      let globs = String_set.of_list globs in
      let single_line_globs = String_set.of_list single_line_globs in
      {
        paths_were_originally_specified_by_user = true;
        exts;
        single_line_exts;
        directly_specified_paths;
        globs;
        single_line_globs;
      }
    )

let files_satisfying_constraints (cons : file_constraints) : Document_src.file_collection =
  let single_line_search_mode_applies file =
    List.mem (extension_of_file file) cons.single_line_exts
  in
  let single_line_search_mode_paths_by_exts, default_search_mode_paths_by_exts =
    cons.directly_specified_paths
    |> String_set.to_seq 
    |> list_files_recursive_filter_by_exts
      ~exts:(cons.exts @ cons.single_line_exts)
    |> String_set.partition single_line_search_mode_applies
  in
  let paths_from_single_line_globs =
    cons.single_line_globs
    |> String_set.to_seq
    |> compute_paths_from_globs
  in
  let single_line_search_mode_paths_from_globs, default_search_mode_paths_from_globs =
    cons.globs
    |> String_set.to_seq
    |> compute_paths_from_globs
    |> String_set.partition single_line_search_mode_applies
  in
  let single_line_search_mode_files =
    single_line_search_mode_paths_by_exts
    |> String_set.union paths_from_single_line_globs
    |> String_set.union single_line_search_mode_paths_from_globs
  in
  let default_search_mode_files =
    default_search_mode_paths_by_exts
    |> String_set.union default_search_mode_paths_from_globs
    |> (fun s -> String_set.diff s single_line_search_mode_files)
  in
  do_if_debug (fun oc ->
      Printf.fprintf oc "Checking if single line search mode files and default search mode files are disjoint\n";
      if String_set.is_empty
          (String_set.inter
             single_line_search_mode_files
             default_search_mode_files)
      then (
        Printf.fprintf oc "Check successful\n"
      ) else (
        failwith "check failed"
      );
      let all_files =
        single_line_search_mode_paths_by_exts
        |> String_set.union default_search_mode_paths_by_exts
        |> String_set.union paths_from_single_line_globs
        |> String_set.union single_line_search_mode_paths_from_globs
        |> String_set.union default_search_mode_paths_from_globs
      in
      let single_line_search_mode_files', default_search_mode_files' =
        String_set.partition (fun s ->
            single_line_search_mode_applies s
            ||
            String_set.mem s paths_from_single_line_globs
          )
          all_files
      in
      Printf.fprintf oc "Checking if efficiently computed and naively computed results for single line search mode files are consistent\n";
      if String_set.equal
          single_line_search_mode_files
          single_line_search_mode_files'
      then (
        Printf.fprintf oc "Check successful\n"
      ) else (
        failwith "check failed"
      );
      Printf.fprintf oc "Checking if efficiently computed and naively computed results for default search mode files are consistent\n";
      if String_set.equal
          default_search_mode_files
          default_search_mode_files'
      then (
        Printf.fprintf oc "Check successful\n"
      ) else (
        failwith "check failed"
      )
    );
  {
    default_search_mode_files;
    single_line_search_mode_files;
  }

let document_store_of_document_src ~env pool (document_src : Document_src.t) =
  let bar ~file_count =
    let open Progress.Line in
    list
      [ brackets (elapsed ())
      ; bar ~width:(`Fixed 20) file_count
      ; percentage_of file_count
      ; rate (Progress.Printer.create ~to_string:(Fmt.str "%6.1f file") ~string_len:11 ())
      (* ; sum ~width:10 () ++ const (Fmt.str "/%d" file_count) *)
      ; const "ETA: " ++ eta file_count
      ]
  in
  let all_documents : Document.t list list =
    match document_src with
    | Document_src.Stdin path -> (
        match Document.of_path ~env pool !Params.default_search_mode path with
        | Ok x -> [ [ x ] ]
        | Error msg ->  (
            exit_with_error_msg msg
          )
      )
    | Files { default_search_mode_files; single_line_search_mode_files } -> (
        let total_file_count, files =
          Seq.append
            (Seq.map (fun path -> (!Params.default_search_mode, path))
               (String_set.to_seq default_search_mode_files))
            (Seq.map (fun path -> (`Single_line, path))
               (String_set.to_seq single_line_search_mode_files))
          |> Misc_utils.length_and_list_of_seq
        in
        Printf.eprintf "File count: %d\n" total_file_count;
        let progress_with_reporter ~file_count f =
          Progress.with_reporter (bar ~file_count) (fun report_progress ->
              let report_progress =
                let lock = Eio.Mutex.create () in
                fun x ->
                  Eio.Mutex.use_rw lock ~protect:false (fun () ->
                      report_progress x
                    )
              in
              f report_progress
            )
        in
        let files_with_index, files_without_index =
          files
          |> (fun l ->
              Printf.eprintf "Hashing\n";
              progress_with_reporter ~file_count:total_file_count
                (fun report_progress ->
                   Task_pool.filter_map_list pool (fun (search_mode, path) ->
                       do_if_debug (fun oc ->
                           Printf.fprintf oc "Hashing document: %s\n" (Filename.quote path);
                         );
                       report_progress 1;
                       match BLAKE2B.hash_of_file ~env ~path with
                       | Ok hash -> Some (search_mode, path, hash)
                       | Error msg -> (
                           do_if_debug (fun oc ->
                               Printf.fprintf oc "Error: %s\n" msg
                             );
                           None
                         )
                     )
                     l
                )
            )
          |> (fun l ->
              Printf.eprintf "Finding indices\n";
              progress_with_reporter ~file_count:total_file_count
                (fun report_progress ->
                   Task_pool.map_list pool (fun (search_mode, path, hash) ->
                       do_if_debug (fun oc ->
                           Printf.fprintf oc "Finding index for document: %s, hash: %s\n" (Filename.quote path) hash;
                         );
                       if Random.int 20 = 0 then (
                         Gc.full_major ();
                       );
                       let res = (search_mode, path, hash, Document.find_index ~env ~hash) in
                       report_progress 1;
                       res
                     )
                     l
                )
            )
          |> List.partition_map (fun (search_mode, path, hash, index) ->
              match index with
              | Some index -> Left (search_mode, path, hash, index)
              | None -> Right (search_mode, path, hash)
            )
        in
        let load_document ~env pool search_mode ~hash ?index path =
          do_if_debug (fun oc ->
              Printf.fprintf oc "Loading document: %s\n" (Filename.quote path);
            );
          do_if_debug (fun oc ->
              Printf.fprintf oc "Using %s search mode for document %s\n"
                (match search_mode with
                 | `Single_line -> "single line"
                 | `Multiline -> "multiline"
                )
                (Filename.quote path)
            );
          match Document.of_path ~env pool search_mode ~hash ?index path with
          | Ok x -> (
              do_if_debug (fun oc ->
                  Printf.fprintf oc "Document %s loaded successfully\n" (Filename.quote path);
                );
              Some x
            )
          | Error msg -> (
              do_if_debug (fun oc ->
                  Printf.fprintf oc "Error: %s\n" msg
                );
              None
            )
        in
        Printf.eprintf "Processing files with index\n";
        let files_with_index_count = List.length files_with_index in
        let files_with_index =
          progress_with_reporter ~file_count:files_with_index_count
            (fun report_progress ->
               files_with_index
               |> List.filter_map (fun (search_mode, path, hash, index) ->
                   let res = load_document ~env pool search_mode ~hash ~index path in
                   report_progress 1;
                   res
                 )
            )
        in
        Printf.eprintf "Indexing remaining files\n";
        let files_without_index =
          progress_with_reporter
            ~file_count:(total_file_count - files_with_index_count)
            (fun report_progress ->
               files_without_index
               |> Eio.Fiber.List.filter_map ~max_fibers:Task_pool.size
                 (fun (search_mode, path, hash) ->
                    let res = load_document ~env pool search_mode ~hash path in
                    report_progress 1;
                    res
                 )
            )
        in
        [ files_with_index; files_without_index ]
      )
  in
  let store =
    all_documents
    |> List.to_seq
    |> Seq.flat_map List.to_seq
    |> Document_store.of_seq pool
  in
  Gc.compact ();
  store

let run
    ~(env : Eio_unix.Stdenv.base)
    ~sw
    (debug_log : string option)
    (max_depth : int)
    (max_fuzzy_edit_dist : int)
    (max_token_search_dist : int)
    (max_linked_token_search_dist : int)
    (index_chunk_token_count : int)
    (exts : string)
    (single_line_exts : string)
    (additional_exts : string)
    (single_line_additional_exts : string)
    (cache_dir : string)
    (cache_size : int)
    (no_cache : bool)
    (index_only : bool)
    (start_with_search : string option)
    (sample_search_exp : string option)
    (sample_count_per_doc : int)
    (search_exp : string option)
    (print_color_mode : Params.style_mode)
    (print_underline_mode : Params.style_mode)
    (search_result_print_text_width : int)
    (search_result_print_snippet_min_size : int)
    (search_result_print_max_add_lines : int)
    (paths_from : string list)
    (globs : string list)
    (single_line_globs : string list)
    (single_line_search_mode_by_default : bool)
    (print_files_with_match : bool)
    (print_files_without_match : bool)
    (paths : string list)
  =
  Args.check
    ~max_depth
    ~max_fuzzy_edit_dist
    ~max_token_search_dist
    ~max_linked_token_search_dist
    ~index_chunk_token_count
    ~cache_size
    ~sample_count_per_doc
    ~search_result_print_text_width
    ~search_result_print_snippet_min_size
    ~search_result_print_max_add_lines
    ~print_files_with_match
    ~print_files_without_match;
  Params.debug_output := (match debug_log with
      | None -> None
      | Some "-" -> Some stderr
      | Some debug_log -> (
          try
            Some (
              open_out_gen
                [ Open_append; Open_creat; Open_wronly; Open_text ]
                0o644
                debug_log
            )
          with
          | _ -> (
              exit_with_error_msg
                (Fmt.str "failed to open debug log file %s" (Filename.quote debug_log))
            )
        )
    );
  Params.max_file_tree_scan_depth := max_depth;
  Params.max_fuzzy_edit_dist := max_fuzzy_edit_dist;
  Params.max_token_search_dist := max_token_search_dist;
  Params.max_linked_token_search_dist := max_linked_token_search_dist;
  Params.index_chunk_token_count := index_chunk_token_count;
  Params.cache_size := cache_size;
  Params.print_color_mode := print_color_mode;
  Params.print_underline_mode := print_underline_mode;
  Params.search_result_print_text_width := search_result_print_text_width;
  Params.search_result_print_snippet_min_size := search_result_print_snippet_min_size;
  Params.search_result_print_snippet_max_additional_lines_each_direction :=
    search_result_print_max_add_lines;
  Params.sample_count_per_document := sample_count_per_doc;
  Params.cache_dir := (
    if no_cache then (
      None
    ) else (
      mkdir_recursive cache_dir;
      Some cache_dir
    )
  );
  Params.default_search_mode := (
    if single_line_search_mode_by_default then (
      `Single_line
    ) else (
      `Multiline
    )
  );
  (match Sys.getenv_opt "VISUAL", Sys.getenv_opt "EDITOR" with
   | None, None -> (
       exit_with_error_msg
         (Fmt.str "environment variable VISUAL or EDITOR needs to be set")
     )
   | Some editor, _
   | None, Some editor -> (
       Params.text_editor := editor;
     )
  );
  let recognized_exts =
    compute_total_recognized_exts ~exts ~additional_exts
  in
  let recognized_single_line_exts =
    compute_total_recognized_exts ~exts:single_line_exts ~additional_exts:single_line_additional_exts
  in
  (match recognized_exts, recognized_single_line_exts, globs, single_line_globs with
   | [], [], [], [] -> (
       exit_with_error_msg
         (Fmt.str "no usable file extensions or glob patterns")
     )
   | _, _, _, _ -> ()
  );
  let question_marks, paths =
    List.partition (fun s -> CCString.trim s = "?") paths
  in
  let paths_from_file =
    match paths_from with
    | [] -> None
    | l -> (
        l
        |> CCList.flat_map (fun paths_from ->
            try
              CCIO.with_in paths_from CCIO.read_lines_l
            with
            | _ -> (
                exit_with_error_msg
                  (Fmt.str "failed to read list of paths from %s" (Filename.quote paths_from))
              )
          )
        |> Option.some
      )
  in
  let file_constraints =
    make_file_constraints
      ~exts:recognized_exts
      ~single_line_exts:recognized_single_line_exts
      ~paths
      ~paths_from_file
      ~globs
      ~single_line_globs
  in
  let pool = Task_pool.make ~sw (Eio.Stdenv.domain_mgr env) in
  Ui_base.Vars.pool := Some pool;
  do_if_debug (fun oc ->
      Printf.fprintf oc "Scanning for documents\n"
    );
  let compute_init_ui_mode_and_document_src : unit -> Ui_base.ui_mode * Document_src.t =
    let stdin_tmp_file = ref None in
    (fun () ->
       String_set.iter (fun path ->
           if not (Sys.file_exists path) then (
             exit_with_error_msg
               (Fmt.str "path %s does not exist" (Filename.quote path))
           )
         )
         file_constraints.directly_specified_paths;
       let file_collection = files_satisfying_constraints file_constraints in
       let file_collection =
         match question_marks with
         | [] -> file_collection
         | _ -> (
             let selection =
               Document_src.seq_of_file_collection file_collection
               |> Proc_utils.pipe_to_fzf_for_selection
               |> String_set.of_list
             in
             let default_search_mode_files =
               String_set.inter selection file_collection.default_search_mode_files
             in
             let single_line_search_mode_files =
               String_set.inter selection file_collection.single_line_search_mode_files
             in
             { default_search_mode_files;
               single_line_search_mode_files;
             }
           )
       in
       if file_constraints.paths_were_originally_specified_by_user
       || stdin_is_atty ()
       then (
         let ui_mode =
           let open Ui_base in
           match Document_src.file_collection_size file_collection with
           | 0 -> Ui_multi_file
           | 1 -> Ui_single_file
           | _ -> Ui_multi_file
         in
         (ui_mode, Files file_collection)
       ) else (
         match !stdin_tmp_file with
         | None -> (
             match read_in_channel_to_tmp_file stdin with
             | Ok tmp_file -> (
                 stdin_tmp_file := Some tmp_file;
                 Ui_base.(Ui_single_file, Stdin tmp_file)
               )
             | Error msg -> (
                 exit_with_error_msg msg
               )
           )
         | Some tmp_file -> (
             Ui_base.(Ui_single_file, Stdin tmp_file)
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
  let clean_up () =
    match init_document_src with
    | Stdin tmp_file -> (
        try
          Sys.remove tmp_file
        with
        | _ -> ()
      )
    | Files _ -> ()
  in
  do_if_debug (fun oc ->
      Printf.fprintf oc "Scanning completed\n"
    );
  do_if_debug (fun oc ->
      match init_document_src with
      | Stdin _ -> Printf.fprintf oc "Document source: stdin\n"
      | Files file_collection -> (
          Printf.fprintf oc "Document source: files\n";
          Document_src.seq_of_file_collection file_collection
          |> Seq.iter (fun file ->
              Printf.fprintf oc "File: %s\n" (Filename.quote file);
            )
        )
    );
  (match init_document_src with
   | Stdin _ -> ()
   | Files file_collection -> (
       let pdftotext_exists = Proc_utils.command_exists "pdftotext" in
       let pandoc_exists = Proc_utils.command_exists "pandoc" in
       let formats = Document_src.seq_of_file_collection file_collection
                     |> Seq.map format_of_file
                     |> Seq.fold_left (fun acc x -> File_format_set.add x acc) File_format_set.empty
       in
       if not pdftotext_exists && File_format_set.mem `PDF formats then (
         exit_with_error_msg
           (Fmt.str "command pdftotext not found")
       );
       if File_format_set.mem `Pandoc_supported_format formats then (
         if not pandoc_exists then (
           exit_with_error_msg
             (Fmt.str "command pandoc not found")
         );
       );
       let file_count = Document_src.file_collection_size file_collection in
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
  Ui_base.Vars.init_ui_mode := init_ui_mode;
  let init_document_store =
    document_store_of_document_src ~env pool init_document_src
  in
  if index_only then (
    clean_up ();
    exit 0
  );
  (match sample_search_exp, search_exp with
   | None, None -> ()
   | Some _, Some _ -> (
       exit_with_error_msg
         (Fmt.str "%s and %s cannot be used together" Args.sample_arg_name Args.search_arg_name)
     )
   | Some search_exp_string, None
   | None, Some search_exp_string -> (
       (* Non-interactive mode *)
       let print_limit =
         match sample_search_exp with
         | Some _ -> Some sample_count_per_doc
         | None -> None
       in
       match
         Search_exp.make search_exp_string
       with
       | None -> (
           exit_with_error_msg "failed to parse search exp"
         )
       | Some search_exp -> (
           do_if_debug (fun oc ->
               Fmt.pf
                 (Format.formatter_of_out_channel oc)
                 "Search expression: @[<v>%a@]@." Search_exp.pp search_exp
             );
           let document_store =
             Document_store.update_search_exp
               pool
               (Stop_signal.make ())
               search_exp_string
               search_exp
               init_document_store
           in
           let out = `Stdout in
           if print_files_with_match then (
             Document_store.usable_documents_paths document_store
             |> String_set.iter (Printers.path_image out)
           ) else if print_files_without_match then (
             Document_store.unusable_documents_paths document_store
             |> Seq.iter (Printers.path_image out)
           ) else (
             let document_info_s =
               Document_store.usable_documents document_store
             in
             Array.iteri (fun i (document, search_results) ->
                 if Array.length search_results > 0 then (
                   if i > 0 then (
                     Printers.newline_image out;
                   );
                   Array.to_seq search_results
                   |> (fun s ->
                       match print_limit with
                       | None -> s
                       | Some end_exc -> OSeq.take end_exc s)
                   |> Printers.search_results out document
                 )
               ) document_info_s;
           );
           clean_up ();
           exit 0
         )
     )
  );
  Document_store_manager.submit_update_req `Multi_file_view init_document_store;
  (match init_ui_mode with
   | Ui_base.Ui_single_file ->
     Document_store_manager.submit_update_req `Single_file_view init_document_store;
   | _ -> ()
  );
  Ui_base.Vars.eio_env := Some env;
  Lwd.set Ui_base.Vars.ui_mode init_ui_mode;
  let root : Nottui.ui Lwd.t =
    let$* (term_width, term_height) = Lwd.get Ui_base.Vars.term_width_height in
    if term_width <= 40 || term_height <= 20 then (
      let msg = Nottui.Ui.atom (Notty.I.strf "Terminal size too small") in
      let keyboard_handler (key : Nottui.Ui.key) =
        match key with
        | (`Escape, [])
        | (`ASCII 'Q', [`Ctrl])
        | (`ASCII 'C', [`Ctrl]) -> (
            Lwd.set Ui_base.Vars.quit true;
            Ui_base.Vars.action := None;
            `Handled
          )
        | _ -> `Unhandled
      in
      Lwd.return (Nottui.Ui.keyboard_area keyboard_handler msg)
    ) else (
      let$* ui_mode : Ui_base.ui_mode = Lwd.get Ui_base.Vars.ui_mode in
      match ui_mode with
      | Ui_multi_file -> (
          Multi_file_view.main
        )
      | Ui_single_file -> (
          Single_file_view.main
        )
    )
  in
  let get_term, close_term =
    let term_and_tty_fd = ref None in
    ((fun () ->
        match !term_and_tty_fd with
        | None -> (
            if stdin_is_atty () then (
              let term = Notty_unix.Term.create () in
              term_and_tty_fd := Some (term, None);
              term
            ) else (
              let input =
                Unix.(openfile "/dev/tty" [ O_RDONLY ] 0o444)
              in
              let term = Notty_unix.Term.create ~input () in
              term_and_tty_fd := Some (term, Some input);
              term
            )
          )
        | Some (term, _tty_fd) -> term
      ),
     (fun () ->
        match !term_and_tty_fd with
        | None -> ()
        | Some (term, tty_fd) -> (
            Notty_unix.Term.release term;
            (match tty_fd with
             | None -> ()
             | Some fd -> Unix.close fd);
            term_and_tty_fd := None
          )
     )
    )
  in
  let rec loop () =
    Sys.command "clear -x" |> ignore;
    let term = get_term () in
    Ui_base.Vars.term := Some term;
    Ui_base.Vars.action := None;
    Lwd.set Ui_base.Vars.quit false;
    Ui_base.ui_loop
      ~quit:Ui_base.Vars.quit
      ~term
      root;
    match !Ui_base.Vars.action with
    | None -> ()
    | Some action -> (
        match action with
        | Ui_base.Recompute_document_src -> (
            let document_src = compute_document_src () in
            let old_document_store =
              Lwd.peek Document_store_manager.multi_file_view_document_store
            in
            let file_path_filter_glob_string = Document_store.file_path_filter_glob_string old_document_store in
            let file_path_filter_glob = Document_store.file_path_filter_glob old_document_store in
            let search_exp_string = Document_store.search_exp_string old_document_store in
            let search_exp = Document_store.search_exp old_document_store in
            let document_store =
              document_store_of_document_src ~env pool document_src
              |> Document_store.update_file_path_filter_glob
                pool
                (Stop_signal.make ())
                file_path_filter_glob_string
                file_path_filter_glob
              |> Document_store.update_search_exp
                pool
                (Stop_signal.make ())
                search_exp_string
                search_exp
            in
            Document_store_manager.submit_update_req `Multi_file_view document_store;
            loop ()
          )
        | Open_file_and_search_result (doc, search_result) -> (
            let index = Document.index doc in
            let path = Document.path doc in
            let old_stats = Unix.stat path in
            (match File_utils.format_of_file path with
             | `PDF -> (
                 Path_open.pdf
                   index
                   ~path
                   ~search_result
               )
             | `Pandoc_supported_format -> (
                 Path_open.pandoc_supported_format ~path
               )
             | `Text -> (
                 close_term ();
                 Path_open.text
                   index
                   init_document_src
                   ~editor:!Params.text_editor
                   ~path
                   ~search_result
               ));
            let new_stats = Unix.stat path in
            if
              Float.abs
                (new_stats.st_mtime -. old_stats.st_mtime) >= Params.float_compare_margin
            then (
              (match Lwd.peek Ui_base.Vars.ui_mode with
               | Ui_single_file -> Single_file_view.reload_document doc
               | Ui_multi_file -> Multi_file_view.reload_document doc
              );
            );
            loop ()
          )
      )
  in
  Eio.Fiber.any [
    (fun () ->
       Eio.Domain_manager.run (Eio.Stdenv.domain_mgr env)
         (fun () -> Document_store_manager.worker_fiber pool));
    Document_store_manager.manager_fiber;
    Ui_base.Key_binding_info.grid_light_fiber;
    Printers.Worker.fiber;
    (fun () ->
       (match start_with_search with
        | None -> ()
        | Some start_with_search -> (
            let start_with_search_len = String.length start_with_search in
            match init_ui_mode with
            | Ui_base.Ui_multi_file -> (
                Lwd.set Multi_file_view.Vars.search_field (start_with_search, start_with_search_len);
                Multi_file_view.update_search_phrase ();
              )
            | Ui_single_file -> (
                Lwd.set Ui_base.Vars.Single_file.search_field (start_with_search, start_with_search_len);
                Single_file_view.update_search_phrase ();
              )
          ));
       loop ();
       Printers.Worker.stop ();
    );
  ];
  close_term ();
  clean_up ();
  (match debug_log with
   | Some "-" -> ()
   | _ -> (
       match !Params.debug_output with
       | None -> ()
       | Some oc -> (
           close_out oc
         )
     )
  )

let cmd ~env ~sw =
  let open Term in
  let open Args in
  let doc = "TUI multiline fuzzy document finder" in
  let version = Version_string.s in
  Cmd.v (Cmd.info "docfd" ~version ~doc)
    (const (run ~env ~sw)
     $ debug_log_arg
     $ max_depth_arg
     $ max_fuzzy_edit_dist_arg
     $ max_token_search_dist_arg
     $ max_linked_token_search_dist_arg
     $ index_chunk_token_count_arg
     $ exts_arg
     $ single_line_exts_arg
     $ add_exts_arg
     $ single_line_add_exts_arg
     $ cache_dir_arg
     $ cache_size_arg
     $ no_cache_arg
     $ index_only_arg
     $ start_with_search_arg
     $ sample_arg
     $ sample_count_per_doc_arg
     $ search_arg
     $ color_arg
     $ underline_arg
     $ search_result_print_text_width_arg
     $ search_result_print_snippet_min_size_arg
     $ search_result_print_snippet_max_add_lines_arg
     $ paths_from_arg
     $ glob_arg
     $ single_line_glob_arg
     $ single_line_arg
     $ files_with_match_arg
     $ files_without_match_arg
     $ paths_arg)

let () =
  if Sys.win32 then (
    exit_with_error_msg "Windows is not supported"
  );
  Random.self_init ();
  Eio_main.run (fun env ->
      Eio.Switch.run (fun sw ->
          exit (Cmd.eval (cmd ~env ~sw))
        ))
