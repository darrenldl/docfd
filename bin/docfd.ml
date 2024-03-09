open Cmdliner
open Lwd_infix
open Docfd_lib
open Debug_utils

let stdin_is_atty () =
  Unix.isatty Unix.stdin

let stdout_is_atty () =
  Unix.isatty Unix.stdout

let stderr_is_atty () =
  Unix.isatty Unix.stderr

let exit_with_error_msg (msg : string) =
  Printf.printf "error: %s\n" msg;
  exit 1

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

let max_fuzzy_edit_dist_arg_name = "max-fuzzy-edit-dist"

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
    "Maximum distance to look for the next matching word/symbol in search phrase.
If two words are adjacent words, then they are 1 distance away from each other.
Note that contiguous spaces count as one word/symbol as well."
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
        exit_with_error_msg
          (Fmt.str "environment variable HOME is not set");
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
    Fmt.str "Specify debug log file to use and enable debug mode where additional info is displayed on UI. If FILE is -, then debug log is printed to stderr instead. Otherwise FILE is opened in append mode for log writing."
  in
  Arg.(
    value
    & opt string ""
    & info [ "debug-log" ] ~doc ~docv:"FILE"
  )

let start_with_search_arg =
  let doc =
    Fmt.str "Start interactive mode with search expression EXP."
  in
  Arg.(
    value
    & opt string ""
    & info [ "start-with-search" ] ~doc ~docv:"EXP"
  )

let search_arg =
  let doc =
    Fmt.str "Search with expression EXP in non-interactive mode."
  in
  Arg.(
    value
    & opt string ""
    & info [ "search" ] ~doc ~docv:"EXP"
  )

let search_result_count_per_doc_arg_name = "search-result-count-per-doc"

let search_result_count_per_doc_arg =
  let doc =
    "Number of search results per document to show in non-interactive search mode."
  in
  Arg.(
    value
    & opt int Params.default_non_interactive_search_result_count
    & info [ search_result_count_per_doc_arg_name ] ~doc ~docv:"N"
  )

let search_result_print_text_width_arg_name = "search-result-print-text-width"

let search_result_print_text_width_arg =
  let doc =
    "Text width to use when printing search results."
  in
  Arg.(
    value
    & opt int Params.default_search_result_print_text_width
    & info [ search_result_print_text_width_arg_name ] ~doc ~docv:"N"
  )

let paths_from_arg =
  let doc =
    Fmt.str "Read list of paths from FILE
and add to the final list of paths to be scanned."
  in
  Arg.(
    value
    & opt string ""
    & info [ "paths-from" ] ~doc ~docv:"FILE"
  )

let list_files_recursive (dirs : string list) : string list =
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
            (* We skip file extension checks for top-level user specified files. *)
            if depth = 0 || List.mem ext !Params.recognized_exts then (
              add path
            )
          )
        )
      | exception _ -> ()
    ) else ()
  in
  List.iter (fun x -> aux 0 x) dirs;
  List.sort_uniq String.compare !l

let mkdir_recursive (dir : string) : unit =
  let rec aux acc parts =
    match parts with
    | [] -> ()
    | "" :: xs -> (
        aux Filename.dir_sep xs
      )
    | x :: xs -> (
        let acc = Filename.concat acc x in
        match Sys.is_directory acc with
        | true -> aux acc xs
        | false -> (
            exit_with_error_msg
              (Fmt.str "%s is not a directory" (Filename.quote acc))
          )
        | exception (Sys_error _) -> (
            do_if_debug (fun oc ->
                Printf.fprintf oc "Creating directory: %s\n" (Filename.quote acc)
              );
            (try
               Sys.mkdir acc 0o755
             with
             | _ -> (
                 exit_with_error_msg
                   (Fmt.str "failed to create directory: %s" (Filename.quote acc))
               )
            );
            aux acc xs
          )
      )
  in
  aux "" (CCString.split ~by:Filename.dir_sep dir)

module Open_path = struct
  let docx ~path =
    let path = Filename.quote path in
    let cmd = Fmt.str "xdg-open %s" path in
    Proc_utils.run_in_background cmd |> ignore

  let pdf index ~path ~search_result =
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
          let frequency_of_word_of_page_ci : int String_map.t Int_map.t =
            List.fold_left (fun acc page_num ->
                let m = Misc_utils.frequencies_of_words_ci
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
                let m = Int_map.find page_num frequency_of_word_of_page_ci in
                let freq =
                  String_map.fold (fun word_on_page_ci freq acc_freq ->
                      if
                        CCString.find ~sub:word.Search_result.found_word_ci word_on_page_ci >= 0
                      then (
                        acc_freq + freq
                      ) else (
                        acc_freq
                      )
                    )
                    m
                    0
                in
                (word, page_num, freq)
              )
            |> List.fold_left (fun best x ->
                let (_x_word, _x_page_num, x_freq) = x in
                match best with
                | None -> Some x
                | Some (_best_word, _best_page_num, best_freq) -> (
                    if x_freq < best_freq then
                      Some x
                    else
                      best
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

  let text index document_src ~editor ~path ~search_result =
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
          | "jed" | "xjed" ->
            Fmt.str "%s %s -g %d" editor path line_num
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
end

type print_output = [ `Stdout | `Stderr ]

let out_channel_of_print_output (out : print_output) : out_channel =
  match out with
  | `Stdout -> stdout
  | `Stderr -> stderr

let print_output_is_atty (out : print_output) =
  match out with
  | `Stdout -> stdout_is_atty ()
  | `Stderr -> stderr_is_atty ()

let print_newline_image ~(out : print_output) =
  Notty_unix.eol (Notty.I.void 0 1)
  |> Notty_unix.output_image ~fd:(out_channel_of_print_output out)

let print_search_result_images ~(out : print_output) ~document (images : Notty.image list) =
  let path = Document.path document in
  let oc = out_channel_of_print_output out in
  if print_output_is_atty out then (
    let formatter = Format.formatter_of_out_channel oc in
    Ocolor_format.prettify_formatter formatter;
    Fmt.pf formatter "@[<h>@{<magenta>%s@}@]@." path;
  ) else (
    Printf.fprintf oc "%s\n" path;
  );
  let images = Array.of_list images in
  Array.iteri (fun i img ->
      if i > 0 then (
        print_newline_image ~out
      );
      Notty_unix.eol img
      |> Notty_unix.output_image ~fd:oc;
    ) images

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
    (start_with_search : string)
    (search_exp : string)
    (search_result_count_per_doc : int)
    (search_result_print_text_width : int)
    (paths_from : string)
    (paths : string list)
  =
  if max_depth < 1 then (
    exit_with_error_msg
      (Fmt.str "invalid %s: cannot be < 1" max_depth_arg_name)
  );
  if max_fuzzy_edit_dist < 0 then (
    exit_with_error_msg
      (Fmt.str "invalid %s: cannot be < 0" max_fuzzy_edit_dist_arg_name)
  );
  if max_word_search_dist < 1 then (
    exit_with_error_msg
      (Fmt.str "invalid %s: cannot be < 1" max_word_search_dist_arg_name)
  );
  if index_chunk_word_count < 1 then (
    exit_with_error_msg
      (Fmt.str "invalid %s: cannot be < 1" index_chunk_word_count_arg_name)
  );
  if cache_size < 1 then (
    exit_with_error_msg
      (Fmt.str "invalid %s: cannot be < 1" cache_size_arg_name)
  );
  if search_result_count_per_doc < 1 then (
    exit_with_error_msg
      (Fmt.str "invalid %s: cannot be < 1" search_result_count_per_doc_arg_name)
  );
  if search_result_print_text_width < 1 then (
    exit_with_error_msg
      (Fmt.str "invalid %s: cannot be < 1" search_result_print_text_width_arg_name)
  );
  Params.debug_output := (match debug_log with
      | "" -> None
      | "-" -> Some stderr
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
              exit_with_error_msg
                (Fmt.str "failed to open debug log file %s" (Filename.quote debug_log))
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
      mkdir_recursive cache_dir;
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
       exit_with_error_msg
         (Fmt.str "no usable file extensions")
     )
   | _ -> ()
  );
  Params.recognized_exts := recognized_exts;
  let question_marks, paths =
    List.partition (fun s -> CCString.trim s = "?") paths
  in
  let paths_from_file =
    if paths_from = "" then (
      []
    ) else (
      try
        CCIO.with_in paths_from CCIO.read_lines_l
      with
      | _ -> (
          exit_with_error_msg
            (Fmt.str "failed to read list of paths from %s" (Filename.quote paths_from))
        )
    )
  in
  let paths = match paths, paths_from_file with
    | [], [] -> [ "." ]
    | _, _ -> paths @ paths_from_file
  in
  List.iter (fun path ->
      if not (Sys.file_exists path) then (
        exit_with_error_msg
          (Fmt.str "path %s does not exist" (Filename.quote path))
      )
    )
    paths;
  let files = list_files_recursive paths in
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
  do_if_debug (fun oc ->
      Printf.fprintf oc "Scanning for documents\n"
    );
  let compute_init_ui_mode_and_document_src : unit -> Ui_base.ui_mode * Ui_base.document_src =
    let stdin_tmp_file = ref None in
    fun () ->
      if not (stdin_is_atty ()) then (
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
      ) else (
        match files with
        | [] -> Ui_base.(Ui_multi_file, Files [])
        | [ f ] -> (
            Ui_base.(Ui_single_file, Files [ f ])
          )
        | _ -> (
            Ui_base.(Ui_multi_file, Files files)
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
              Printf.fprintf oc "File: %s\n" (Filename.quote file);
            )
            files
        )
    );
  (match init_document_src with
   | Stdin _ -> ()
   | Files files -> (
       if List.exists Misc_utils.path_is_pdf files then (
         if not (Proc_utils.command_exists "pdftotext") then (
           exit_with_error_msg
             (Fmt.str "command pdftotext not found")
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
              exit_with_error_msg msg
            )
        )
      | Files files -> (
          Eio.Fiber.List.filter_map ~max_fibers:Task_pool.size (fun path ->
              do_if_debug (fun oc ->
                  Printf.fprintf oc "Loading document: %s\n" (Filename.quote path);
                );
              match Document.of_path ~env path with
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
    |> Document_store.of_seq
  in
  Ui_base.Vars.init_ui_mode := init_ui_mode;
  let init_document_store = document_store_of_document_src init_document_src in
  if index_only then (
    exit 0
  );
  if String.length search_exp > 0 then (
    let search_exp =
      Search_exp.make
        ~fuzzy_max_edit_distance:!Params.max_fuzzy_edit_distance
        search_exp
    in
    let document_store =
      Document_store.update_search_exp search_exp init_document_store
    in
    let document_info_s =
      Document_store.usable_documents document_store
    in
    Array.iteri (fun i (document, search_results) ->
        let out = `Stdout in
        if i > 0 then (
          print_newline_image ~out;
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
        print_search_result_images ~out ~document images;
      ) document_info_s;
    exit 0
  );
  Lwd.set Ui_base.Vars.document_store init_document_store;
  (match init_ui_mode with
   | Ui_base.Ui_single_file -> Lwd.set Ui_base.Vars.Single_file.document_store init_document_store
   | _ -> ()
  );
  Ui_base.Vars.eio_env := Some env;
  Lwd.set Ui_base.Vars.ui_mode init_ui_mode;
  (let start_with_search_len = String.length start_with_search in
   match init_ui_mode with
   | Ui_base.Ui_multi_file -> (
       Lwd.set Multi_file_view.Vars.search_field (start_with_search, start_with_search_len);
       Multi_file_view.update_search_phrase ();
     )
   | Ui_single_file -> (
       Lwd.set Ui_base.Vars.Single_file.search_field (start_with_search, start_with_search_len);
       Single_file_view.update_search_phrase ();
     )
  );
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
            match init_document_src with
            | Stdin _ -> (
                let input =
                  Unix.(openfile "/dev/tty" [ O_RDWR ] 0666)
                in
                let term = Notty_unix.Term.create ~input () in
                term_and_tty_fd := Some (term, Some input);
                term
              )
            | Files _ -> (
                let term = Notty_unix.Term.create () in
                term_and_tty_fd := Some (term, None);
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
              document_store_of_document_src document_src
              |> Document_store.update_search_exp search_exp
            in
            Lwd.set Ui_base.Vars.document_store document_store;
            loop ()
          )
        | Open_file_and_search_result (doc, search_result) -> (
            let index = Document.index doc in
            let path = Document.path doc in
            let old_stats = Unix.stat path in
            if Misc_utils.path_is_pdf path then (
              Open_path.pdf
                index
                ~path
                ~search_result
            ) else if Misc_utils.path_is_docx path then (
              Open_path.docx ~path
            ) else (
              close_term ();
              Open_path.text
                index
                init_document_src
                ~editor:!Params.text_editor
                ~path
                ~search_result
            );
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
            print_search_result_images ~out:`Stderr ~document images;
          )
      )
  in
  loop ();
  close_term ();
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

let paths_arg =
  let doc =
    "PATH can be either file or directory.
Directories are scanned for files with matching extensions.
If any PATH is \"?\", then the list of files is passed onto fzf for user selection.
Multiple \"?\" are treated the same as one \"?\".
If no paths are provided or only \"?\" is provided,
then Docfd defaults to scanning the current working directory
unless --paths-from is used."
  in
  Arg.(value & pos_all string [] & info [] ~doc ~docv:"PATH")

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
          $ start_with_search_arg
          $ search_arg
          $ search_result_count_per_doc_arg
          $ search_result_print_text_width_arg
          $ paths_from_arg
          $ paths_arg)

let () = Eio_main.run (fun env ->
    exit (Cmd.eval (cmd ~env))
  )
