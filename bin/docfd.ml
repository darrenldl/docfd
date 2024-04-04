open Cmdliner
open Lwd_infix
open Docfd_lib
open Debug_utils
open Misc_utils

let compute_paths_from_globs globs =
  match globs with
  | [] -> None
  | _ -> (
      let globs =
        List.map (fun s ->
            match compile_glob_re s with
            | Some re -> (s, re)
            | None -> (
                exit_with_error_msg
                  (Fmt.str "failed to parse glob pattern: \"%s\"" s)
              )
          ) globs
      in
      Some (File_utils.list_files_recursive_filter_by_globs globs)
    )

let document_store_of_document_src ~env pool ~single_line_search_paths document_src =
  let all_documents : Document.t list =
    match document_src with
    | Ui_base.Stdin path -> (
        match Document.of_path ~env pool !Params.default_search_mode path with
        | Ok x -> [ x ]
        | Error msg ->  (
            exit_with_error_msg msg
          )
      )
    | Files files -> (
        Eio.Fiber.List.filter_map ~max_fibers:Task_pool.size (fun path ->
            do_if_debug (fun oc ->
                Printf.fprintf oc "Loading document: %s\n" (Filename.quote path);
              );
            let search_mode =
              if String_set.mem path single_line_search_paths then (
                `Single_line
              ) else (
                `Multiline
              )
            in
            match Document.of_path ~env pool search_mode path with
            | Ok x -> (
                do_if_debug (fun oc ->
                    Printf.fprintf oc "Document %s loaded successfully\n" (Filename.quote path);
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
  |> Document_store.of_seq pool

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
    (search_exp : string option)
    (search_result_count_per_doc : int)
    (search_result_print_text_width : int)
    (paths_from : string option)
    (globs : string list)
    (single_line_globs : string list)
    (paths : string list)
  =
  Args.check
    ~max_depth
    ~max_fuzzy_edit_dist
    ~max_token_search_dist
    ~max_linked_token_search_dist
    ~index_chunk_token_count
    ~cache_size
    ~search_result_count_per_doc
    ~search_result_print_text_width;
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
  Params.max_file_tree_depth := max_depth;
  Params.max_fuzzy_edit_dist := max_fuzzy_edit_dist;
  Params.max_token_search_dist := max_token_search_dist;
  Params.max_linked_token_search_dist := max_linked_token_search_dist;
  Params.index_chunk_token_count := index_chunk_token_count;
  Params.cache_size := cache_size;
  Params.cache_dir := (
    if no_cache then (
      None
    ) else (
      File_utils.mkdir_recursive cache_dir;
      Some cache_dir
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
  Params.recognized_exts := recognized_exts;
  Params.recognized_single_line_exts := recognized_single_line_exts;
  let question_marks, paths =
    List.partition (fun s -> CCString.trim s = "?") paths
  in
  let paths_from_file =
    Option.map (fun paths_from ->
        try
          CCIO.with_in paths_from CCIO.read_lines_l
        with
        | _ -> (
            exit_with_error_msg
              (Fmt.str "failed to read list of paths from %s" (Filename.quote paths_from))
          )
      )
      paths_from
  in
  let paths_from_globs = compute_paths_from_globs globs in
  let paths_from_single_line_globs = compute_paths_from_globs single_line_globs in
  let
    paths,
    paths_from_globs,
    paths_from_single_line_globs,
    paths_were_originally_specified_by_user
    =
    match
      paths,
      paths_from_file,
      paths_from_globs,
      paths_from_single_line_globs
    with
    | [], None, None, None -> ([ "." ], String_set.empty, String_set.empty, false)
    | _, _, _, _ -> (
        let paths_from_file = Option.value paths_from_file ~default:[] in
        let paths_from_globs =
          Option.value paths_from_globs ~default:String_set.empty
        in
        let paths_from_single_line_globs =
          Option.value paths_from_single_line_globs ~default:String_set.empty
        in
        (List.flatten [ paths; paths_from_file ],
         paths_from_globs,
         paths_from_single_line_globs,
         true)
      )
  in
  List.iter (fun path ->
      if not (Sys.file_exists path) then (
        exit_with_error_msg
          (Fmt.str "path %s does not exist" (Filename.quote path))
      )
    )
    paths;
  let single_line_search_paths =
    String_set.union
      (File_utils.list_files_recursive_filter_by_exts ~exts:!Params.recognized_single_line_exts paths)
      paths_from_single_line_globs
  in
  let files =
    File_utils.list_files_recursive_filter_by_exts ~exts:!Params.recognized_exts paths
    |> String_set.union paths_from_globs
    |> String_set.union single_line_search_paths
    |> String_set.to_list
  in
  let files =
    match question_marks with
    | [] -> files
    | _ -> (
        if not (Proc_utils.command_exists "fzf") then (
          exit_with_error_msg
            (Fmt.str "command fzf not found")
        );
        let stdin_for_fzf, write_to_fzf = Unix.pipe ~cloexec:true () in
        let read_from_fzf, stdout_for_fzf = Unix.pipe ~cloexec:true () in
        let write_to_fzf_oc = Unix.out_channel_of_descr write_to_fzf in
        let read_from_fzf_ic = Unix.in_channel_of_descr read_from_fzf in
        List.iter (fun file ->
            output_string write_to_fzf_oc file;
            output_string write_to_fzf_oc "\n";
          ) files;
        Out_channel.close write_to_fzf_oc;
        let pid =
          Unix.create_process "fzf" [| "fzf"; "--multi" |]
            stdin_for_fzf stdout_for_fzf Unix.stderr
        in
        let _, process_status = Unix.waitpid [] pid in
        Unix.close stdin_for_fzf;
        Unix.close stdout_for_fzf;
        let selection = CCIO.read_lines_l (Unix.in_channel_of_descr read_from_fzf) in
        In_channel.close read_from_fzf_ic;
        (match process_status with
         | WEXITED n -> (
             if n <> 0 then (
               exit n
             )
           )
         | WSIGNALED _ | WSTOPPED _ -> (
             exit 1
           )
        );
        selection
      )
  in
  let pool = Task_pool.make ~sw (Eio.Stdenv.domain_mgr env) in
  Ui_base.Vars.pool := Some pool;
  do_if_debug (fun oc ->
      Printf.fprintf oc "Scanning for documents\n"
    );
  let compute_init_ui_mode_and_document_src : unit -> Ui_base.ui_mode * Ui_base.document_src =
    let stdin_tmp_file = ref None in
    fun () ->
      if paths_were_originally_specified_by_user
      || stdin_is_atty ()
      then (
        match files with
        | [] -> (
            Ui_base.(Ui_multi_file, Files [])
          )
        | [ f ] -> (
            Ui_base.(Ui_single_file, Files [ f ])
          )
        | _ -> (
            Ui_base.(Ui_multi_file, Files files)
          )
      ) else (
        match !stdin_tmp_file with
        | None -> (
            match File_utils.read_in_channel_to_tmp_file stdin with
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
      | Files files -> (
          Printf.fprintf oc "Document source: files\n";
          List.iter (fun file ->
              Printf.fprintf oc "File: %s\n" (Filename.quote file);
            )
            files
        )
    );
  (match init_document_src with
   | Stdin _ -> ()
   | Files files -> (
       let pdftotext_exists = Proc_utils.command_exists "pdftotext" in
       let pandoc_exists = Proc_utils.command_exists "pandoc" in
       let formats = List.map Misc_utils.format_of_file files in
       if not pdftotext_exists && List.mem `PDF formats then (
         exit_with_error_msg
           (Fmt.str "command pdftotext not found")
       );
       if not pandoc_exists && List.mem `Pandoc_supported_format formats then (
         exit_with_error_msg
           (Fmt.str "command pandoc not found")
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
  Ui_base.Vars.init_ui_mode := init_ui_mode;
  let init_document_store =
    document_store_of_document_src ~env pool ~single_line_search_paths init_document_src
  in
  if index_only then (
    clean_up ();
    exit 0
  );
  (match search_exp with
   | None -> ()
   | Some search_exp -> (
       (* Non-interactive mode *)
       match
         Search_exp.make
           ~fuzzy_max_edit_dist:!Params.max_fuzzy_edit_dist
           search_exp
       with
       | None -> (
           exit_with_error_msg "failed to parse search exp"
         )
       | Some search_exp -> (
           let document_store =
             Document_store.update_search_exp pool (Stop_signal.make ()) search_exp init_document_store
           in
           let document_info_s =
             Document_store.usable_documents document_store
           in
           Array.iteri (fun i (document, search_results) ->
               let out = `Stdout in
               if i > 0 then (
                 Search_result_print.newline_image ~out;
               );
               let images =
                 Content_and_search_result_render.search_results
                   ~render_mode:(Ui_base.render_mode_of_document document)
                   ~start:0
                   ~end_exc:search_result_count_per_doc
                   ~width:search_result_print_text_width
                   (Document.index document)
                   search_results
               in
               Search_result_print.search_result_images ~out ~document images;
             ) document_info_s;
           clean_up ();
           exit 0
         )
     )
  );
  Lwd.set Ui_base.Vars.document_store init_document_store;
  (match init_ui_mode with
   | Ui_base.Ui_single_file -> Lwd.set Ui_base.Vars.Single_file.document_store init_document_store
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
                Unix.(openfile "/dev/tty" [ O_RDWR ] 0666)
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
            let old_document_store = Lwd.peek Ui_base.Vars.document_store in
            let search_exp = Document_store.search_exp old_document_store in
            let document_store =
              document_store_of_document_src ~env pool ~single_line_search_paths document_src
              |> Document_store.update_search_exp pool (Stop_signal.make ()) search_exp
            in
            Lwd.set Ui_base.Vars.document_store document_store;
            loop ()
          )
        | Open_file_and_search_result (doc, search_result) -> (
            let index = Document.index doc in
            let path = Document.path doc in
            let old_stats = Unix.stat path in
            (match Misc_utils.format_of_file path with
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
        | Print_file_path_and_search_result (document, search_result) -> (
            close_term ();
            let images =
              match search_result with
              | None -> []
              | Some search_result -> (
                  [ Content_and_search_result_render.search_result
                      ~render_mode:(Ui_base.render_mode_of_document document)
                      ~width:search_result_print_text_width
                      (Document.index document)
                      search_result
                  ]
                )
            in
            Search_result_print.search_result_images ~out:`Stderr ~document images;
          )
      )
  in
  Eio.Fiber.any [
    (fun () ->
       Eio.Domain_manager.run (Eio.Stdenv.domain_mgr env)
         (fun () -> Search_manager.search_fiber pool));
    Search_manager.manager_fiber;
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
       loop ()
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
     $ search_arg
     $ search_result_count_per_doc_arg
     $ search_result_print_text_width_arg
     $ paths_from_arg
     $ glob_arg
     $ single_line_glob_arg
     $ paths_arg)

let () = Eio_main.run (fun env ->
    Eio.Switch.run (fun sw ->
        exit (Cmd.eval (cmd ~env ~sw))
      ))
