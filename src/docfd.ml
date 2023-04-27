open Cmdliner

let stdin_is_atty () =
  Unix.isatty Unix.stdin

let stdout_is_atty () =
  Unix.isatty Unix.stdout

let max_depth_arg =
  let doc =
    "Scan up to N levels in the file tree."
  in
  Arg.(value & opt int Params.default_max_file_tree_depth & info [ "max-depth" ] ~doc ~docv:"N")

let max_fuzzy_edit_distance_arg =
  let doc =
    "Maximum edit distance for fuzzy matches."
  in
  Arg.(value & opt int Params.default_max_fuzzy_edit_distance & info [ "max-fuzzy-edit" ] ~doc ~docv:"N")

let max_word_search_range_arg =
  let doc =
    "Maximum range to look for the next matching word/symbol in content search."
  in
  Arg.(value & opt int Params.default_max_word_search_range
       & info [ "max-word-search-range" ] ~doc ~docv:"N")

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
      if Sys.is_directory path then (
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
        if List.mem ext Params.recognized_exts then (
          add path
        )
      )
    )
  in
  (
    try
      aux 0 dir
    with
    | _ -> ()
  );
  !l

let run
    (debug : bool)
    (max_depth : int)
    (max_fuzzy_edit_distance : int)
    (max_word_search_range : int)
    (files : string list)
  =
  Params.debug := debug;
  Params.max_file_tree_depth := max_depth;
  Params.max_fuzzy_edit_distance := max_fuzzy_edit_distance;
  Params.max_word_search_range := max_word_search_range;
  List.iter (fun file ->
      if not (Sys.file_exists file) then (
        Fmt.pr "Error: File \"%s\" does not exist\n" file;
        exit 1
      )
    )
    files;
  if !Params.debug then (
    Printf.printf "Scanning for text files\n"
  );
  let init_ui_mode, document_src =
    if not (stdin_is_atty ()) then
      Ui.(Ui_single_file, Stdin)
    else (
      match files with
      | [] -> Fmt.pr "Error: No files provided\n"; exit 1
      | [ f ] -> (
          if Sys.is_directory f then
            Ui.(Ui_multi_file, Files (list_files_recursively f))
          else
            Ui.(Ui_single_file, Files [ f ])
        )
      | _ -> (
          Ui.(Ui_multi_file,
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
  Ui.Vars.init_ui_mode := init_ui_mode;
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
  let all_documents =
    match document_src with
    | Stdin ->
      [ Document.of_in_channel ~path:None stdin ]
    | Files files ->
      List.filter_map (fun path ->
          match Document.of_path path with
          | Ok x -> Some x
          | Error _ -> None) files
  in
  match all_documents with
  | [] -> Printf.printf "No suitable text files found\n"
  | _ -> (
      Lwd.set Ui.Vars.all_documents all_documents;
      let total_document_count = List.length all_documents in
      let term =
        match document_src with
        | Stdin ->
          let input =
            Unix.(openfile "/dev/tty" [ O_RDWR ] 0666)
          in
          Ui.Vars.term := (Notty_unix.Term.create ~input ())
        | Files _ -> ()
      in
      let renderer = Nottui.Renderer.make () in
      Lwd.set Ui.Vars.ui_mode init_ui_mode;
      let right_pane () =
        Nottui_widgets.v_pane
          Ui.Content_view.main
          Ui.Content_search_result_list.main
      in
      let content_search_label_str = "Search:" in
      let label_strs =
        [ content_search_label_str ]
      in
      let max_label_len =
        List.fold_left (fun x s ->
            max x (String.length s))
          0
          label_strs
      in
      let label_widget_len = max_label_len + 1 in
      let content_search_label =
        make_label_widget
          ~s:content_search_label_str
          ~len:label_widget_len
          Search
          input_mode
      in
      let make_search_field ~edit_field ~focus_handle ~f =
        Nottui_widgets.edit_field (Lwd.get edit_field)
          ~focus:focus_handle
          ~on_change:(fun (text, x) -> Lwd.set edit_field (text, x))
          ~on_submit:(fun _ ->
              f ();
              Nottui.Focus.release focus_handle;
              Lwd.set input_mode Navigate
            )
      in
      let bottom_pane_components =
        [
          status_bar;
          key_binding_info;
          (Nottui_widgets.hbox
             [
               content_search_label;
               make_search_field
                 ~edit_field:search_field
                 ~focus_handle:content_focus_handle
                 ~f:update_content_search_constraints;
             ],
           1
          );
        ]
      in
      let top_pane_no_keyboard_control : Nottui.ui Lwd.t =
        Lwd.map ~f:(fun (ui_mode, results) ->
            match ui_mode with
            | Ui_multi_file ->
              Nottui_widgets.h_pane
                (left_pane ())
                (right_pane ())
            | Ui_single_file -> (
                right_pane ()
              )
          )
          (Lwd.pair (Lwd.get ui_mode) content_search_results)
        |> Lwd.join
      in
      let top_pane =
        Lwd.map2 ~f:(fun
                      (pane, documents)
                      (document_current_choice,
                       content_search_result_current_choice)
                      ->
                        let image_count = Array.length documents in
                        pane
                        |> Nottui.Ui.keyboard_area
                          (keyboard_handler
                             ~document_choice_count:image_count
                             ~document_current_choice
                             ~content_search_result_current_choice
                             documents)
                    )
          (Lwd.pair top_pane_no_keyboard_control documents)
          (Lwd.pair
             (Lwd.get document_selected)
             (Lwd.get content_search_result_selected))
      in
      let screen =
        Nottui_widgets.vbox
          (top_pane
           ::
           (List.map fst bottom_pane_components))
      in
      let rec loop () =
        file_to_open := None;
        Lwd.set quit false;
        Nottui.Ui_loop.run
          ~term
          ~renderer
          ~quit
          screen;
        match !file_to_open with
        | None -> ()
        | Some doc ->
          match doc.path with
          | None -> ()
          | Some path ->
            match Sys.getenv_opt "VISUAL", Sys.getenv_opt "EDITOR" with
            | None, None ->
              Printf.printf "Error: Both env variables VISUAL and EDITOR are unset\n"; exit 1
            | Some editor, _
            | None, Some editor -> (
                Sys.command (Fmt.str "%s \'%s\'" editor path) |> ignore;
                loop ()
              )
      in
      loop ()
    )

let files_arg = Arg.(value & pos_all string [ "." ] & info [])

let cmd =
  let doc = "TUI fuzzy document finder" in
  let version = Version_string.s in
  Cmd.v (Cmd.info "docfd" ~version ~doc)
    Term.(const run
          $ debug_arg
          $ max_depth_arg
          $ max_fuzzy_edit_distance_arg
          $ max_word_search_range_arg
          $ files_arg)

let () = exit (Cmd.eval cmd)
