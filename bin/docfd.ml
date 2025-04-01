open Cmdliner
open Lwd_infix
open Docfd_lib
open Debug_utils
open Misc_utils
open File_utils

let compute_paths_from_globs ~report_progress globs =
  Seq.iter (fun s ->
      match Glob.make s with
      | Some _ -> ()
      | None -> (
          exit_with_error_msg
            (Fmt.str "failed to parse glob pattern: \"%s\"" s)
        )
    ) globs;
  list_files_recursive_filter_by_globs ~report_progress globs

type file_constraints = {
  no_pdftotext : bool;
  no_pandoc : bool;
  paths_were_originally_specified_by_user : bool;
  exts : string list;
  single_line_exts : string list;
  directly_specified_paths : String_set.t;
  globs : String_set.t;
  single_line_globs : String_set.t;
}

let make_file_constraints
    ~no_pdftotext
    ~no_pandoc
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
        no_pdftotext;
        no_pandoc;
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
        no_pdftotext;
        no_pandoc;
        paths_were_originally_specified_by_user = true;
        exts;
        single_line_exts;
        directly_specified_paths;
        globs;
        single_line_globs;
      }
    )

let files_satisfying_constraints
    ~interactive
    (cons : file_constraints)
  : Document_src.file_collection =
  let bar =
    let open Progress.Line in
    list
      [ const "Scanning"
      ; spinner ()
      ]
  in
  progress_with_reporter
    ~interactive
    bar
    (fun report_progress : Document_src.file_collection ->
       let single_line_search_mode_applies file =
         List.mem (extension_of_file file) cons.single_line_exts
       in
       let single_line_search_mode_paths_by_exts, default_search_mode_paths_by_exts =
         cons.directly_specified_paths
         |> String_set.to_seq
         |> list_files_recursive_filter_by_exts
           ~report_progress
           ~exts:(cons.exts @ cons.single_line_exts)
         |> String_set.partition single_line_search_mode_applies
       in
       let paths_from_single_line_globs =
         cons.single_line_globs
         |> String_set.to_seq
         |> compute_paths_from_globs ~report_progress
       in
       let single_line_search_mode_paths_from_globs, default_search_mode_paths_from_globs =
         cons.globs
         |> String_set.to_seq
         |> compute_paths_from_globs ~report_progress
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
       let filter_for_no_pdftotext_or_no_pandoc (s : String_set.t) =
         if cons.no_pdftotext || cons.no_pandoc then (
           String_set.filter
             (fun s ->
                match File_utils.format_of_file s with
                | `PDF -> not cons.no_pdftotext
                | `Pandoc_supported_format -> not cons.no_pandoc
                | `Text -> true
             )
             s
         ) else (
           s
         )
       in
       let default_search_mode_files =
         filter_for_no_pdftotext_or_no_pandoc default_search_mode_files
       in
       let single_line_search_mode_files =
         filter_for_no_pdftotext_or_no_pandoc single_line_search_mode_files
       in
       {
         default_search_mode_files;
         single_line_search_mode_files;
       }
    )

let document_store_of_document_src ~env ~interactive pool (document_src : Document_src.t) =
  let file_bar ~total_file_count =
    let open Progress.Line in
    list
      [ brackets (elapsed ())
      ; bar ~width:(`Fixed 20) total_file_count
      ; percentage_of total_file_count
      ; const "ETA: " ++ eta total_file_count
      ]
  in
  let byte_bar ~total_byte_count =
    let open Progress.Line in
    list
      [ brackets (elapsed ())
      ; bar ~width:(`Fixed 20) total_byte_count
      ; percentage_of total_byte_count
      ; bytes_per_sec
      ; const "ETA: " ++ eta total_byte_count
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
        let print_stage_stats ~file_count ~total_byte_count =
          Printf.printf "- File count: %6d\n" file_count;
          Printf.printf "- MiB:        %8.1f\n"
            (Misc_utils.mib_of_bytes total_byte_count);
        in
        let total_file_count, files =
          Seq.append
            (Seq.map (fun path -> (!Params.default_search_mode, path))
               (String_set.to_seq default_search_mode_files))
            (Seq.map (fun path -> (`Single_line, path))
               (String_set.to_seq single_line_search_mode_files))
          |> Misc_utils.length_and_list_of_seq
        in
        if interactive then (
          Printf.printf "Collecting file stats\n";
        );
        let documents_total_byte_count, document_sizes =
          progress_with_reporter
            ~interactive
            (file_bar ~total_file_count)
            (fun report_progress ->
               List.fold_left (fun (total_size, m) (_, path) ->
                   let res =
                     match File_utils.file_size path with
                     | None -> (total_size, m)
                     | Some x -> (total_size + x, String_map.add path x m)
                   in
                   report_progress 1;
                   res
                 )
                 (0, String_map.empty)
                 files
            )
        in
        if interactive then (
          print_stage_stats
            ~file_count:total_file_count
            ~total_byte_count:documents_total_byte_count
        );
        if interactive then (
          Printf.printf "Hashing\n"
        );
        let file_and_hash_list =
          match files with
          | [] -> []
          | _ -> (
              files
              |> (fun l ->
                  progress_with_reporter
                    ~interactive
                    (byte_bar ~total_byte_count:documents_total_byte_count)
                    (fun report_progress ->
                       Task_pool.filter_map_list pool (fun (search_mode, path) ->
                           do_if_debug (fun oc ->
                               Printf.fprintf oc "Hashing document: %s\n" (Filename.quote path);
                             );
                           let res =
                             match BLAKE2B.hash_of_file ~env ~path with
                             | Ok hash -> Some (search_mode, path, hash)
                             | Error msg -> (
                                 do_if_debug (fun oc ->
                                     Printf.fprintf oc "Error: %s\n" msg
                                   );
                                 None
                               )
                           in
                           (match String_map.find_opt path document_sizes with
                            | None -> ()
                            | Some x -> report_progress x);
                           res
                         )
                         l
                    )
                )
            )
        in
        let indexed_files, unindexed_files =
          let open Sqlite3_utils in
          with_stmt
            {|
          SELECT 1 FROM doc_info WHERE hash = @doc_hash
          |}
            (fun stmt ->
               List.partition (fun (_, _, doc_hash) ->
                   bind_names stmt [ ("@doc_hash", TEXT doc_hash) ];
                   step stmt;
                   let indexed = data_count stmt > 0 in
                   reset stmt;
                   indexed
                 )
                 file_and_hash_list
            )
        in
        indexed_files
        |> List.to_seq
        |> Seq.map (fun (_, _, doc_hash) ->
            doc_hash
          )
        |> Index.refresh_last_used_batch;
        let load_document ~env pool search_mode ~doc_hash path =
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
          match Document.of_path ~env pool search_mode ~doc_hash path with
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
        if interactive then (
          Printf.printf "Processing files with index\n"
        );
        let indexed_files =
          indexed_files
          |> List.filter_map (fun (search_mode, path, doc_hash) ->
              load_document ~env pool search_mode ~doc_hash path
            )
        in
        if interactive then (
          Printf.printf "Indexing remaining files\n"
        );
        let unindexed_file_count, unindexed_files_byte_count =
          List.fold_left (fun (file_count, byte_count) (_, path, _) ->
              (file_count + 1,
               byte_count + Option.value ~default:0 (String_map.find_opt path document_sizes))
            )
            (0, 0)
            unindexed_files
        in
        if interactive then (
          print_stage_stats
            ~file_count:unindexed_file_count
            ~total_byte_count:unindexed_files_byte_count;
        );
        let pipeline = Document_pipeline.make ~env pool in
        let _, unindexed_files =
          Eio.Fiber.pair
            (fun () ->
               Document_pipeline.run pipeline
            )
            (fun () ->
               (match unindexed_files with
                | [] -> ()
                | _ -> (
                    progress_with_reporter
                      ~interactive
                      (byte_bar ~total_byte_count:unindexed_files_byte_count)
                      (fun report_progress ->
                         unindexed_files
                         |> List.iter (fun (search_mode, path, doc_hash) ->
                             Document_pipeline.feed
                               pipeline
                               search_mode
                               ~doc_hash
                               path;
                             (match String_map.find_opt path document_sizes with
                              | None -> ()
                              | Some x -> report_progress x
                             )
                           )
                      )
                  ));
               Document_pipeline.finalize pipeline
            )
        in
        [ indexed_files; unindexed_files ]
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
    (no_pdftotext : bool)
    (no_pandoc : bool)
    (scan_hidden : bool)
    (max_depth : int)
    (max_fuzzy_edit_dist : int)
    (max_token_search_dist : int)
    (max_linked_token_search_dist : int)
    (tokens_per_search_scope_level : int)
    (index_chunk_size : int)
    (exts : string)
    (single_line_exts : string)
    (additional_exts : string list)
    (single_line_additional_exts : string list)
    (cache_dir : string)
    (cache_limit : int)
    (index_only : bool)
    (start_with_search : string option)
    (sample_search_exp : string option)
    (samples_per_doc : int)
    (search_exp : string option)
    (print_color_mode : Params.style_mode)
    (print_underline_mode : Params.style_mode)
    (search_result_print_text_width : int)
    (search_result_print_snippet_min_size : int)
    (search_result_print_max_add_lines : int)
    (commands_from : string option)
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
    ~tokens_per_search_scope_level
    ~index_chunk_size
    ~cache_limit
    ~samples_per_doc
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
          | Sys_error _ -> (
              exit_with_error_msg
                (Fmt.str "failed to open debug log file %s" (Filename.quote debug_log))
            )
        )
    );
  Params.scan_hidden := scan_hidden;
  Params.max_file_tree_scan_depth := max_depth;
  Params.max_fuzzy_edit_dist := max_fuzzy_edit_dist;
  Params.max_token_search_dist := max_token_search_dist;
  Params.max_linked_token_search_dist := max_linked_token_search_dist;
  Params.tokens_per_search_scope_level := tokens_per_search_scope_level;
  Params.index_chunk_size := index_chunk_size;
  Params.cache_limit := cache_limit;
  Params.search_result_print_text_width := search_result_print_text_width;
  Params.search_result_print_snippet_min_size := search_result_print_snippet_min_size;
  Params.search_result_print_snippet_max_additional_lines_each_direction :=
    search_result_print_max_add_lines;
  Params.samples_per_document := samples_per_doc;
  Params.cache_dir := (
    mkdir_recursive cache_dir;
    Some cache_dir
  );
  Params.default_search_mode := (
    if single_line_search_mode_by_default then (
      `Single_line
    ) else (
      `Multiline
    )
  );
  let db_path = Filename.concat cache_dir Params.db_file_name in
  (match Docfd_lib.init ~db_path ~document_count_limit:cache_limit with
   | None -> ()
   | Some msg -> exit_with_error_msg msg
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
            | Sys_error _ -> (
                exit_with_error_msg
                  (Fmt.str "failed to read list of paths from %s" (Filename.quote paths_from))
              )
          )
        |> Option.some
      )
  in
  let interactive =
    Option.is_none sample_search_exp
    &&
    Option.is_none search_exp
  in
  let file_constraints =
    make_file_constraints
      ~no_pdftotext
      ~no_pandoc
      ~exts:recognized_exts
      ~single_line_exts:recognized_single_line_exts
      ~paths
      ~paths_from_file
      ~globs
      ~single_line_globs
  in
  let pool = Task_pool.make ~sw (Eio.Stdenv.domain_mgr env) in
  Ui_base.Vars.pool := Some pool;
  let file_collection_to_reuse = ref None in
  let compute_if_hide_document_list_initially_and_document_src : unit -> bool * Document_src.t =
    let stdin_tmp_file = ref None in
    (fun () ->
       let file_collection =
         match !file_collection_to_reuse with
         | None -> (
             String_set.iter (fun path ->
                 if not (Sys.file_exists path) then (
                   exit_with_error_msg
                     (Fmt.str "path %s does not exist" (Filename.quote path))
                 )
               )
               file_constraints.directly_specified_paths;
             let file_collection = files_satisfying_constraints ~interactive file_constraints in
             match question_marks with
             | [] -> file_collection
             | _ -> (
                 let selection =
                   Document_src.seq_of_file_collection file_collection
                   |> (fun l ->
                       match Proc_utils.pipe_to_fzf_for_selection l with
                       | `Selection l -> l
                       | `Cancelled n -> exit n)
                   |> String_set.of_list
                 in
                 let default_search_mode_files =
                   String_set.inter selection file_collection.default_search_mode_files
                 in
                 let single_line_search_mode_files =
                   String_set.inter selection file_collection.single_line_search_mode_files
                 in
                 let collection =
                   { Document_src.default_search_mode_files;
                     single_line_search_mode_files;
                   }
                 in
                 file_collection_to_reuse := Some collection;
                 collection
               )
           )
         | Some x -> x
       in
       if file_constraints.paths_were_originally_specified_by_user
       || stdin_is_atty ()
       then (
         let hide_document_list =
           match Document_src.file_collection_size file_collection with
           | 0 -> false
           | 1 -> true
           | _ -> false
         in
         (hide_document_list, Files file_collection)
       ) else (
         match !stdin_tmp_file with
         | None -> (
             match read_in_channel_to_tmp_file stdin with
             | Ok tmp_file -> (
                 stdin_tmp_file := Some tmp_file;
                 (true, Stdin tmp_file)
               )
             | Error msg -> (
                 exit_with_error_msg msg
               )
           )
         | Some tmp_file -> (
             (true, Stdin tmp_file)
           )
       )
    )
  in
  let compute_document_src () =
    snd (compute_if_hide_document_list_initially_and_document_src ())
  in
  let hide_document_list_initially, init_document_src =
    compute_if_hide_document_list_initially_and_document_src ()
  in
  let clean_up () =
    match init_document_src with
    | Stdin tmp_file -> (
        try
          Sys.remove tmp_file
        with
        | Sys_error _ -> ()
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
           (Fmt.str "command pdftotext not found, use --%s to disable use of pdftotext" Args.no_pdftotext_arg_name)
       );
       if File_format_set.mem `Pandoc_supported_format formats then (
         if not pandoc_exists then (
           exit_with_error_msg
             (Fmt.str "command pandoc not found, use --%s to disable use of pandoc" Args.no_pandoc_arg_name)
         );
       );
     )
  );
  Lwd.set Ui_base.Vars.hide_document_list hide_document_list_initially;
  let init_document_store =
    document_store_of_document_src ~env pool ~interactive init_document_src
  in
  if index_only then (
    clean_up ();
    exit 0
  );
  if Option.is_some commands_from then (
    if Option.is_some sample_search_exp then (
      exit_with_error_msg
        (Fmt.str "%s and %s cannot be used together" Args.commands_from_arg_name Args.sample_arg_name)
    );
    if Option.is_some search_exp then (
      exit_with_error_msg
        (Fmt.str "%s and %s cannot be used together" Args.commands_from_arg_name Args.search_arg_name)
    );
    if Option.is_some start_with_search then (
      exit_with_error_msg
        (Fmt.str "%s and %s cannot be used together" Args.commands_from_arg_name Args.start_with_search_arg_name)
    );
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
         | Some _ -> Some samples_per_doc
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
           let oc = stdout in
           let color =
             match print_color_mode with
             | `Never -> false
             | `Always -> true
             | `Auto -> Out_channel.isatty oc
           in
           let underline =
             match print_underline_mode with
             | `Never -> false
             | `Always -> true
             | `Auto -> not (Out_channel.isatty oc)
           in
           let no_results =
             if print_files_with_match then (
               let s =
                 Document_store.usable_documents_paths document_store
               in
               String_set.iter (Printers.path_image ~color oc) s;
               String_set.is_empty s
             ) else if print_files_without_match then (
               let s =
                 Document_store.unusable_documents_paths document_store
               in
               Seq.iter (Printers.path_image ~color oc) s;
               Seq.is_empty s
             ) else (
               let s =
                 Document_store.search_result_groups document_store
                 |> Array.to_seq
                 |> Seq.map (fun (doc, arr) ->
                     let arr =
                       match print_limit with
                       | None -> arr
                       | Some n -> (
                           Array.sub
                             arr
                             0
                             (min (Array.length arr) n)
                         )
                     in
                     (doc, arr)
                   )
               in
               Printers.search_result_groups ~color ~underline oc s;
               Seq.is_empty s
             )
           in
           clean_up ();
           if no_results then (
             exit 1
           ) else (
             exit 0
           )
         )
     )
  );
  Ui_base.Vars.eio_env := Some env;
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
      Ui.main
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
            close_term ();
            let new_starting_snapshot =
              compute_document_src ()
              |> document_store_of_document_src ~env ~interactive pool
              |> Document_store_snapshot.make ~last_command:None
            in
            Ui.update_starting_snapshot_and_recompute_rest
              new_starting_snapshot;
            loop ()
          )
        | Open_file_and_search_result (doc, search_result) -> (
            let doc_hash = Document.doc_hash doc in
            let path = Document.path doc in
            let old_stats = Unix.stat path in
            (match File_utils.format_of_file path with
             | `PDF -> (
                 Path_open.pdf
                   ~doc_hash
                   ~path
                   ~search_result
               )
             | `Pandoc_supported_format -> (
                 Path_open.pandoc_supported_format ~path
               )
             | `Text -> (
                 close_term ();
                 Path_open.text
                   ~doc_hash
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
              Ui.reload_document doc
            );
            loop ()
          )
        | Edit_command_history -> (
            let file = Filename.temp_file "" ".docfd_commands" in
            let snapshots = Ui.Vars.document_store_snapshots in
            let lines =
              Seq.append
                (
                  snapshots
                  |> Dynarray.to_seq
                  |> Seq.filter_map  (fun (snapshot : Document_store_snapshot.t) ->
                      Option.map
                        Command.to_string
                        (Document_store_snapshot.last_command snapshot)
                    )
                )
                (
                  List.to_seq
                    [
                      "";
                      "# You are viewing/editing Docfd command history.";
                      "# If any change is made to this file, Docfd will replay the commands from the start.";
                      "#";
                      "# If a line is not blank and does not start with #,";
                      "# then the line should contain exactly one command.";
                      "# A command cannot be written across multiple lines.";
                      "#";
                      "# Starting point is v0, the full document store.";
                      "# Each command adds one to the version number.";
                      "# Command at the top is oldest, command at bottom is the newest.";
                      "#";
                      "# Note that for commands that accept text, all trailing text is trimmed and then used in full.";
                      "# This means \" and ' are treated literally and are not used to delimit strings.";
                      "#";
                      "# Possible commands:";
                      Fmt.str "# - %a" Command.pp (`Search "search phrase");
                      Fmt.str "# - %a" Command.pp (`Filter "file.*pattern");
                      Fmt.str "# - %a" Command.pp (`Narrow_level 1);
                      Fmt.str "# - %a" Command.pp (`Mark "/path/to/document");
                      Fmt.str "# - %a" Command.pp (`Unmark "/path/to/document");
                      Fmt.str "# - %a" Command.pp `Unmark_all;
                      Fmt.str "# - %a" Command.pp (`Drop "/path/to/document");
                      Fmt.str "# - %a" Command.pp (`Drop_all_except "/path/to/document");
                      Fmt.str "# - %a" Command.pp `Drop_marked;
                      Fmt.str "# - %a" Command.pp `Drop_unmarked;
                      Fmt.str "# - %a" Command.pp `Drop_listed;
                      Fmt.str "# - %a" Command.pp `Drop_unlisted;
                    ]
                )
              |> List.of_seq
            in
            let rec aux rerun lines : [ `No_changes | `Changes_made ] =
              CCIO.with_out file (fun oc ->
                  CCIO.write_lines_l oc lines;
                );
              let old_stats = Unix.stat file in
              close_term ();
              Misc_utils.gen_command_to_open_text_file_to_line_num
                ~editor:!Params.text_editor
                ~quote_path:true
                ~path:file
                ~line_num:(max 1 (Dynarray.length snapshots - 1))
              |> Sys.command
              |> ignore;
              let new_stats = Unix.stat file in
              if
                rerun
                ||
                Float.abs
                  (new_stats.st_mtime -. old_stats.st_mtime) >= Params.float_compare_margin
              then (
                Dynarray.clear snapshots;
                Lwd.set Ui.Vars.document_store_cur_ver 0;
                Dynarray.add_last
                  snapshots
                  (Document_store_snapshot.make
                     ~last_command:None
                     (init_document_store));
                let store = ref init_document_store in
                let rerun = ref false in
                let lines =
                  CCIO.with_in file (fun ic ->
                      CCIO.read_lines_l ic
                      |> CCList.flat_map (fun line ->
                          if
                            String_utils.line_is_blank_or_comment line
                          then (
                            [ line ]
                          ) else (
                            match Command.of_string line with
                            | None -> (
                                rerun := true;
                                [
                                  line;
                                  "# Failed to parse above command"
                                ]
                              )
                            | Some command -> (
                                match Document_store.run_command pool command !store with
                                | None -> (
                                    rerun := true;
                                    [
                                      line;
                                      "# Failed to play above command, check if arguments are correct"
                                    ]
                                  )
                                | Some x -> (
                                    store := x;
                                    let snapshot =
                                      Document_store_snapshot.make
                                        ~last_command:(Some command)
                                        !store
                                    in
                                    Dynarray.add_last
                                      snapshots
                                      snapshot;
                                    [ line ]
                                  )
                              )
                          )
                        )
                    )
                in
                if !rerun then (
                  aux true lines
                ) else (
                  `Changes_made
                )
              ) else (
                `No_changes
              )
            in
            (try
               let res = aux false lines in
               (try
                  Sys.remove file;
                with
                | Sys_error _ -> ()
               );
               (match res with
                | `No_changes -> ()
                | `Changes_made -> (
                    Lwd.set
                      Ui.Vars.document_store_cur_ver
                      (Dynarray.length snapshots - 1);
                    let final_snapshot = Dynarray.get_last snapshots in
                    Document_store_manager.submit_update_req final_snapshot;
                    Ui.reset_document_selected ();
                    Ui.sync_input_fields_from_document_store
                      (Document_store_snapshot.store final_snapshot);
                  )
               );
             with
             | Sys_error _ -> (
                 exit_with_error_msg
                   (Fmt.str "failed to read or write temporary command history file %s" (Filename.quote file))
               ));
            loop ()
          )
        | Filter_files_via_fzf -> (
            close_term ();
            let snapshots = Ui.Vars.document_store_snapshots in
            let latest_snapshot = Dynarray.get_last snapshots in
            let store = Document_store_snapshot.store latest_snapshot in
            let selection =
              Document_store.usable_documents_paths store
              |> String_set.to_seq
              |> Proc_utils.pipe_to_fzf_for_selection
            in
            (match selection with
             | `Selection selection -> (
                 let commands : Command.t list =
                   `Unmark_all
                   ::
                   (List.rev selection
                    |> List.fold_left
                      (fun acc file -> `Mark file :: acc)
                      [ `Drop_unmarked; `Unmark_all ])
                 in
                 let store = ref store in
                 List.iter (fun command ->
                     let next_store =
                       Option.get (Document_store.run_command pool command !store)
                     in
                     let snapshot =
                       Document_store_snapshot.make
                         ~last_command:(Some command)
                         next_store
                     in
                     Dynarray.add_last snapshots snapshot;
                     store := next_store;
                   )
                   commands;
                 Lwd.set
                   Ui.Vars.document_store_cur_ver
                   (Dynarray.length snapshots - 1);
                 let final_snapshot = Dynarray.get_last snapshots in
                 Document_store_manager.submit_update_req final_snapshot;
               )
             | `Cancelled _ -> ()
            );
            loop ()
          )
      )
  in
  (match commands_from with
   | None -> ()
   | Some commands_from -> (
       let snapshots = Ui.Vars.document_store_snapshots in
       let lines =
         try
           CCIO.with_in commands_from CCIO.read_lines_l
         with
         | Sys_error _ -> (
             exit_with_error_msg
               (Fmt.str "failed to read command file %s" (Filename.quote commands_from))
           )
       in
       Dynarray.clear snapshots;
       Dynarray.add_last
         snapshots
         (Document_store_snapshot.make
            ~last_command:None
            init_document_store);
       lines
       |> CCList.foldi (fun store i line ->
           let line_num_in_error_msg = i + 1 in
           if String_utils.line_is_blank_or_comment line then (
             store
           ) else (
             match Command.of_string line with
             | None -> (
                 exit_with_error_msg
                   (Fmt.str "failed to parse command on line %d: %s"
                      line_num_in_error_msg line)
               )
             | Some command -> (
                 match Document_store.run_command pool command store with
                 | None -> (
                     exit_with_error_msg
                       (Fmt.str "failed to run command on line %d: %s"
                          line_num_in_error_msg line)
                   )
                 | Some store -> (
                     let snapshot =
                       Document_store_snapshot.make
                         ~last_command:(Some command)
                         store
                     in
                     Dynarray.add_last snapshots snapshot;
                     store
                   )
               )
           )
         )
         init_document_store
       |> ignore
     )
  );
  Eio.Fiber.any [
    (fun () ->
       Eio.Domain_manager.run (Eio.Stdenv.domain_mgr env)
         (fun () -> Document_store_manager.worker_fiber pool));
    Document_store_manager.manager_fiber;
    Ui_base.Key_binding_info.grid_light_fiber;
    (fun () ->
       let snapshots = Ui.Vars.document_store_snapshots in
       let snapshot =
         if Dynarray.length snapshots = 0 then (
           Document_store_snapshot.make
             ~last_command:None
             init_document_store
         ) else (
           let last_index = Dynarray.length snapshots - 1 in
           Lwd.set Ui.Vars.document_store_cur_ver last_index;
           let snapshot = Dynarray.get snapshots last_index in
           Ui.sync_input_fields_from_document_store
             (Document_store_snapshot.store snapshot);
           snapshot
         )
       in
       Document_store_manager.submit_update_req snapshot;
       (match start_with_search with
        | None -> ()
        | Some start_with_search -> (
            let start_with_search_len = String.length start_with_search in
            Lwd.set Ui.Vars.search_field (start_with_search, start_with_search_len);
            Ui.update_search_phrase ();
          ));
       loop ();
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
     $ no_pdftotext_arg
     $ no_pandoc_arg
     $ hidden_arg
     $ max_depth_arg
     $ max_fuzzy_edit_dist_arg
     $ max_token_search_dist_arg
     $ max_linked_token_search_dist_arg
     $ tokens_per_search_scope_level_arg
     $ index_chunk_size_arg
     $ exts_arg
     $ single_line_exts_arg
     $ add_exts_arg
     $ single_line_add_exts_arg
     $ cache_dir_arg
     $ cache_limit_arg
     $ index_only_arg
     $ start_with_search_arg
     $ sample_arg
     $ samples_per_doc_arg
     $ search_arg
     $ color_arg
     $ underline_arg
     $ search_result_print_text_width_arg
     $ search_result_print_snippet_min_size_arg
     $ search_result_print_snippet_max_add_lines_arg
     $ commands_from_arg
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
  Eio_posix.run (fun env ->
      Eio.Switch.run (fun sw ->
          exit (Cmd.eval (cmd ~env ~sw))
        ))
