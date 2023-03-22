open Cmdliner

let stdout_is_terminal () =
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

let tag_ci_fuzzy_arg =
  let doc =
    Fmt.str "[F]uzzy case-insensitive tag match, up to fuzzy-max-edit edit distance."
  in
  Arg.(value & opt_all string [] & info [ "f" ] ~doc ~docv:"STRING")

let tag_ci_full_arg =
  let doc =
    Fmt.str "Case-[i]nsensitive full tag match."
  in
  Arg.(value & opt_all string [] & info [ "i" ] ~doc ~docv:"STRING")

let tag_ci_sub_arg =
  let doc =
    Fmt.str "Case-insensitive [s]ubstring tag match."
  in
  Arg.(value & opt_all string [] & info [ "s" ] ~doc ~docv:"SUBSTRING")

let tag_exact_arg =
  let doc =
    Fmt.str "[E]exact tag match."
  in
  Arg.(value & opt_all string [] & info [ "e" ] ~doc ~docv:"TAG")

let debug_arg =
  let doc =
    Fmt.str "Display debug info."
  in
  Arg.(value & flag & info [ "debug" ] ~doc)

let list_tags_arg =
  let doc =
    Fmt.str "List all tags used."
  in
  Arg.(value & flag & info [ "tags" ] ~doc)

let list_tags_lowercase_arg =
  let doc =
    Fmt.str "List all tags used in lowercase."
  in
  Arg.(value & flag & info [ "ltags" ] ~doc)

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

let set_of_tags (tags : string list) : String_set.t =
  List.fold_left (fun s x ->
      String_set.add x s
    )
    String_set.empty
    tags

let lowercase_set_of_tags (tags : string list) : String_set.t =
  List.fold_left (fun s x ->
      String_set.add (String.lowercase_ascii x) s
    )
    String_set.empty
    tags

let print_tag_set (tags : String_set.t) =
  let s = String_set.to_seq tags in
  if stdout_is_terminal () then (
    let table = Array.make 256 [] in
    Seq.iter (fun s ->
        let row = Char.code s.[0] in
        table.(row) <- s :: table.(row)
      ) s;
    Array.iteri (fun i l ->
        table.(i) <- List.rev l
      ) table;
    Array.iteri (fun i l ->
        match l with
        | [] -> ()
        | _ -> (
            let c = Char.chr i in
            Fmt.pr "@[<v>%c | @[<hv>%a@]@,@]" c Fmt.(list ~sep:sp string) l
          )
      ) table;
  ) else (
    Fmt.pr "@[<v>%a@]"
      Fmt.(seq ~sep:cut string)
      s
  )

type input_mode =
  | Navigate
  | Content
  | Tag_ci_fuzzy
  | Tag_ci_full
  | Tag_ci_sub
  | Tag_exact

type ui_mode =
  | Ui_single_file
  | Ui_all_files

let make_label_widget ~s ~len (mode : input_mode) (v : input_mode Lwd.var) =
  Lwd.map ~f:(fun mode' ->
      (if mode = mode' then
         Notty.(I.string A.(st bold) s)
       else
         Notty.(I.string A.empty s))
      |> Notty.I.hsnap ~align:`Left len
      |> Nottui.Ui.atom
    ) (Lwd.get v)

let run
    (debug : bool)
    (max_depth : int)
    (fuzzy_max_edit_distance : int)
    (max_word_search_range : int)
    (tag_ci_fuzzy : string list)
    (tag_ci_full : string list)
    (tag_ci_sub : string list)
    (tag_exact : string list)
    (list_tags : bool)
    (list_tags_lowercase : bool)
    (files : string list)
  =
  Params.debug := debug;
  Params.max_file_tree_depth := max_depth;
  Params.max_word_search_range := max_word_search_range;
  if list_tags_lowercase && list_tags then (
    Fmt.pr "Error: Please select only --tags or --ltags\n";
    exit 1
  );
  Printf.printf "Scanning for text files\n";
  let ui_mode, files =
    match files with
    | [] -> Fmt.pr "Error: No files provided"; exit 1
    | [ f ] -> (
        if Sys.is_directory f then
          (Ui_all_files, list_files_recursively f)
        else
          (Ui_single_file, [ f ])
      )
    | _ -> (
        (Ui_all_files,
         files
         |> List.to_seq
         |> Seq.flat_map (fun f ->
             if Sys.is_directory f then
               List.to_seq (list_files_recursively f)
             else
               Seq.return f
           )
         |> List.of_seq
        )
      )
  in
  Printf.printf "Scanning completed\n";
  let files = List.sort_uniq String.compare files in
  if !Params.debug then (
    List.iter (fun file ->
        Printf.printf "File: %s\n" file;
      )
      files
  );
  let all_documents =
    List.filter_map (fun path ->
        match Document.of_path path with
        | Ok x -> Some x
        | Error _ -> None) files
  in
  if list_tags_lowercase then (
    let tags_used = ref String_set.empty in
    List.iter (fun (doc : Document.t) ->
        tags_used := String_set.(union
                                   (lowercase_set_of_tags doc.tags)
                                   !tags_used)
      ) all_documents;
    print_tag_set !tags_used
  ) else (
    if list_tags then (
      let tags_used = ref String_set.empty in
      List.iter (fun (doc : Document.t) ->
          tags_used := String_set.(union
                                     (set_of_tags doc.tags)
                                     !tags_used)
        ) all_documents;
      print_tag_set !tags_used
    ) else (
      match all_documents with
      | [] -> Printf.printf "No suitable text files found\n"
      | _ -> (
          let handle_tag_ui =
            List.exists (fun (doc : Document.t) ->
                Misc_utils.path_is_note doc.path
              )
              all_documents
          in
          let term = Notty_unix.Term.create () in
          let renderer = Nottui.Renderer.make () in
          let tag_constraints =
            Lwd.var (Tag_search_constraints.make
                       ~fuzzy_max_edit_distance
                       ~ci_fuzzy:tag_ci_fuzzy
                       ~ci_full:tag_ci_fuzzy
                       ~ci_sub:tag_ci_fuzzy
                       ~exact:tag_exact)
          in
          let content_constraints =
            Lwd.var (Content_search_constraints.make
                       ~fuzzy_max_edit_distance
                       ~phrase:"")
          in
          let quit = Lwd.var false in
          let document_selected = Lwd.var 0 in
          let content_search_result_selected = Lwd.var 0 in
          let file_to_open = ref None in
          let input_mode : input_mode Lwd.var = Lwd.var Navigate in
          let documents = Lwd.map2 ~f:(fun tag_constraints content_constraints ->
              all_documents
              |> List.filter_map (fun doc ->
                  match Document.satisfies_tag_search_constraints tag_constraints doc with
                  | None -> None
                  | Some doc ->
                    if Content_search_constraints.is_empty content_constraints then
                      Some doc
                    else (
                      match Document.content_search_results content_constraints doc () with
                      | Seq.Nil -> None
                      | Seq.Cons _ as s ->
                        let content_search_results = (fun () -> s)
                                                     |> List.of_seq
                                                     |> List.sort Content_search_result.compare
                        in
                        Some { doc with content_search_results }
                    )
                )
              |> (fun l ->
                  if Content_search_constraints.is_empty content_constraints then
                    l
                  else
                    List.sort (fun (doc1 : Document.t) (doc2 : Document.t) ->
                        Content_search_result.compare
                          (List.hd doc1.content_search_results)
                          (List.hd doc2.content_search_results)
                      ) l
                )
              |> Array.of_list
            )
              (Lwd.get tag_constraints)
              (Lwd.get content_constraints)
          in
          let content_focus_handle = Nottui.Focus.make () in
          let tag_ci_fuzzy_focus_handle = Nottui.Focus.make () in
          let tag_ci_full_focus_handle = Nottui.Focus.make () in
          let tag_ci_sub_focus_handle = Nottui.Focus.make () in
          let tag_exact_focus_handle = Nottui.Focus.make () in
          let bound_selection ~choice_count (x : int) : int =
            max 0 (min (choice_count - 1) x)
          in
          let document_list_mouse_handler
              ~document_choice_count
              ~document_current_choice
              ~x ~y
              (button : Notty.Unescape.button)
            =
            let _ = x in
            let _ = y in
            match button with
            | `Scroll `Down ->
              Lwd.set document_selected
                (bound_selection ~choice_count:document_choice_count (document_current_choice+1));
              `Handled
            | `Scroll `Up ->
              Lwd.set document_selected
                (bound_selection ~choice_count:document_choice_count (document_current_choice-1));
              `Handled
            | _ -> `Unhandled
          in
          let content_search_result_list_mouse_handler
              ~content_search_result_choice_count
              ~content_search_result_current_choice
              ~x ~y
              (button : Notty.Unescape.button)
            =
            let _ = x in
            let _ = y in
            match button with
            | `Scroll `Down ->
              Lwd.set content_search_result_selected
                (bound_selection
                   ~choice_count:content_search_result_choice_count
                   (content_search_result_current_choice+1));
              `Handled
            | `Scroll `Up ->
              Lwd.set content_search_result_selected
                (bound_selection
                   ~choice_count:content_search_result_choice_count
                   (content_search_result_current_choice-1));
              `Handled
            | _ -> `Unhandled
          in
          let keyboard_handler
              ~document_choice_count
              ~document_current_choice
              ~content_search_result_current_choice
              (documents : Document.t array)
              (key : Nottui.Ui.key)
            =
            let content_search_result_choice_count () =
              List.length documents.(document_current_choice).content_search_results
            in
            match Lwd.peek input_mode with
            | Navigate -> (
                match key, ui_mode with
                | ((`Escape, []), _)
                | ((`ASCII 'q', []), _)
                | ((`ASCII 'C', [`Ctrl]), _) -> Lwd.set quit true; `Handled
                | ((`ASCII 'j', []), Ui_all_files)
                | ((`Arrow `Down, []), Ui_all_files) ->
                  Lwd.set document_selected
                    (bound_selection
                       ~choice_count:document_choice_count
                       (document_current_choice+1));
                  `Handled
                | ((`ASCII 'k', []), Ui_all_files)
                | ((`Arrow `Up, []), Ui_all_files) ->
                  Lwd.set document_selected
                    (bound_selection
                       ~choice_count:document_choice_count
                       (document_current_choice-1));
                  `Handled
                | ((`ASCII 'J', []), _)
                | ((`Arrow `Down, [`Shift]), _)
                | ((`ASCII 'j', []), Ui_single_file)
                | ((`Arrow `Down, []), Ui_single_file) ->
                  Lwd.set content_search_result_selected
                    (bound_selection
                       ~choice_count:(content_search_result_choice_count ())
                       (content_search_result_current_choice+1));
                  `Handled
                | ((`ASCII 'K', []), _)
                | ((`Arrow `Up, [`Shift]), _)
                | ((`ASCII 'k', []), Ui_single_file)
                | ((`Arrow `Up, []), Ui_single_file) ->
                  Lwd.set content_search_result_selected
                    (bound_selection
                       ~choice_count:(content_search_result_choice_count ())
                       (content_search_result_current_choice-1));
                  `Handled
                | ((`ASCII '/', []), _) ->
                  Nottui.Focus.request content_focus_handle;
                  Lwd.set input_mode Content;
                  `Handled
                | ((`ASCII 'f', [`Ctrl]), _) when handle_tag_ui ->
                  Nottui.Focus.request tag_ci_fuzzy_focus_handle;
                  Lwd.set input_mode Tag_ci_fuzzy;
                  `Handled
                | ((`ASCII 'i', [`Ctrl]), _) when handle_tag_ui ->
                  Nottui.Focus.request tag_ci_full_focus_handle;
                  Lwd.set input_mode Tag_ci_full;
                  `Handled
                | ((`ASCII 's', [`Ctrl]), _) when handle_tag_ui ->
                  Nottui.Focus.request tag_ci_sub_focus_handle;
                  Lwd.set input_mode Tag_ci_sub;
                  `Handled
                | ((`ASCII 'e', [`Ctrl]), _) when handle_tag_ui ->
                  Nottui.Focus.request tag_exact_focus_handle;
                  Lwd.set input_mode Tag_exact;
                  `Handled
                | ((`Enter, []), _) -> (
                    Lwd.set quit true;
                    file_to_open := Some documents.(document_current_choice);
                    `Handled
                  )
                | _ -> `Handled
              )
            | _ -> `Unhandled
          in
          let full_term_sized_background () =
            let (term_width, term_height) = Notty_unix.Term.size term in
            Notty.I.void term_width term_height
            |> Nottui.Ui.atom
          in
          let left_pane () =
            Lwd.map2 ~f:(fun documents i ->
                let image_count = Array.length documents in
                let pane =
                  if Array.length documents = 0 then (
                    Nottui.Ui.empty
                  ) else (
                    let (images_selected, images_unselected) =
                      Render.documents term documents
                    in
                    let (_term_width, term_height) = Notty_unix.Term.size term in
                    CCInt.range' i (min (i + term_height / 2) image_count)
                    |> CCList.of_iter
                    |> List.map (fun j ->
                        if Int.equal i j then
                          images_selected.(j)
                        else
                          images_unselected.(j)
                      )
                    |> List.map Nottui.Ui.atom
                    |> Nottui.Ui.vcat
                  )
                in
                Nottui.Ui.join_z (full_term_sized_background ()) pane
                |> Nottui.Ui.mouse_area
                  (document_list_mouse_handler
                     ~document_choice_count:image_count
                     ~document_current_choice:i)
              )
              documents
              (Lwd.get document_selected)
          in
          let file_view () =
            Lwd.map2 ~f:(fun documents i ->
                if Array.length documents = 0 then (
                  Nottui.Ui.empty
                ) else (
                  let path = documents.(i).path in
                  let (_term_width, term_height) = Notty_unix.Term.size term in
                  let content =
                    try
                      CCIO.with_in path (fun ic ->
                          CCIO.read_lines_seq ic
                          |> OSeq.take term_height
                          |> Seq.map Misc_utils.sanitize_string_for_printing
                          |> Seq.map (fun s -> Nottui.Ui.atom Notty.(I.string A.empty s))
                          |> List.of_seq
                          |> Nottui.Ui.vcat
                        )
                    with
                    | _ -> Nottui.Ui.atom Notty.(I.strf "Error: Failed to access %s" path)
                  in
                  content
                )
              )
              documents
              (Lwd.get document_selected)
          in
          let content_search_results =
            Lwd.map2 ~f:(fun (documents, i) search_result_i ->
                if Array.length documents = 0 then (
                  Nottui.Ui.empty
                ) else (
                  let images =
                    Render.content_search_results documents.(i)
                  in
                  let image_count = Array.length images in
                  if image_count = 0 then (
                    Nottui.Ui.empty
                  ) else (
                    let (_term_width, term_height) = Notty_unix.Term.size term in
                    let pane =
                      CCInt.range' search_result_i (min (search_result_i + term_height / 2) image_count)
                      |> CCList.of_iter
                      |> List.map (fun i -> Notty.I.(images.(i) <-> strf ""))
                      |> List.map Nottui.Ui.atom
                      |> Nottui.Ui.vcat
                    in
                    Nottui.Ui.join_z (full_term_sized_background ()) pane
                    |> Nottui.Ui.mouse_area
                      (content_search_result_list_mouse_handler
                         ~content_search_result_choice_count:image_count
                         ~content_search_result_current_choice:search_result_i)
                  )
                )
              )
              Lwd.(pair documents (Lwd.get document_selected))
              (Lwd.get content_search_result_selected)
          in
          let right_pane () =
            Nottui_widgets.v_pane
              (file_view ())
              content_search_results
          in
          let content_label_str = "(/) Content search:" in
          let tag_ci_fuzzy_label_str = "(Ctrl+f) [F]uzzy case-insensitive tags:" in
          let tag_ci_full_label_str = "(Ctrl+i) Case-[i]sensitive full tags:" in
          let tag_ci_sub_label_str = "(Ctrl+s) Case-insensitive [s]ubstring tags:" in
          let tag_exact_label_str = "(Ctrl+e) [E]exact tags:" in
          let label_strs =
            content_label_str
            ::
            (if handle_tag_ui then
               [tag_ci_fuzzy_label_str;
                tag_ci_full_label_str;
                tag_ci_sub_label_str;
                tag_exact_label_str;
               ]
             else [])
          in
          let max_label_len =
            List.fold_left (fun x s ->
                max x (String.length s))
              0
              label_strs
          in
          let label_widget_len = max_label_len + 1 in
          let content_label =
            make_label_widget
              ~s:content_label_str
              ~len:label_widget_len
              Content
              input_mode
          in
          let tag_ci_fuzzy_label =
            make_label_widget
              ~s:tag_ci_fuzzy_label_str
              ~len:label_widget_len
              Tag_ci_fuzzy
              input_mode
          in
          let tag_ci_full_label =
            make_label_widget
              ~s:tag_ci_full_label_str
              ~len:label_widget_len
              Tag_ci_full
              input_mode
          in
          let tag_ci_sub_label =
            make_label_widget
              ~s:tag_ci_sub_label_str
              ~len:label_widget_len
              Tag_ci_sub
              input_mode
          in
          let tag_exact_label =
            make_label_widget
              ~s:tag_exact_label_str
              ~len:label_widget_len
              Tag_exact
              input_mode
          in
          let content_field =
            Lwd.var ("", 0)
          in
          let tag_ci_fuzzy_field =
            let s = String.concat " " tag_ci_fuzzy in
            Lwd.var (s, String.length s)
          in
          let tag_ci_full_field =
            let s = String.concat " " tag_ci_full in
            Lwd.var (s, String.length s)
          in
          let tag_ci_sub_field =
            let s = String.concat " " tag_ci_sub in
            Lwd.var (s, String.length s)
          in
          let tag_exact_field =
            let s = String.concat " " tag_exact in
            Lwd.var (s, String.length s)
          in
          let update_content_constraints () =
            let constraints' =
              (Content_search_constraints.make
                 ~fuzzy_max_edit_distance
                 ~phrase:(fst @@ Lwd.peek content_field)
              )
            in
            Lwd.set document_selected 0;
            Lwd.set content_search_result_selected 0;
            Lwd.set content_constraints constraints'
          in
          let update_tag_constraints () =
            let constraints' =
              (Tag_search_constraints.make
                 ~fuzzy_max_edit_distance
                 ~ci_fuzzy:(String.split_on_char ' ' (fst @@ Lwd.peek tag_ci_fuzzy_field))
                 ~ci_full:(String.split_on_char ' ' (fst @@ Lwd.peek tag_ci_full_field))
                 ~ci_sub:(String.split_on_char ' ' (fst @@ Lwd.peek tag_ci_sub_field))
                 ~exact:(String.split_on_char ' ' (fst @@ Lwd.peek tag_exact_field))
              )
            in
            Lwd.set document_selected 0;
            Lwd.set content_search_result_selected 0;
            Lwd.set tag_constraints constraints'
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
          let top_pane_no_keyboard_control =
            match ui_mode with
            | Ui_all_files ->
              Nottui_widgets.h_pane
                (left_pane ())
                (right_pane ())
            | Ui_single_file ->
              Lwd.map ~f:(fun results ->
                  let (_term_width, term_height) = Notty_unix.Term.size term in
                  let h =
                    term_height - (List.length label_strs)
                  in
                  Nottui.Ui.resize ~h results
                )
                content_search_results
          in
          let top_pane =
            Lwd.map2 ~f:(fun
                          (pane, documents)
                          (document_current_choice, content_search_result_current_choice) ->
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
              (List.flatten
                 [
                   [ top_pane ];
                   [ Nottui_widgets.hbox
                       [
                         content_label;
                         make_search_field
                           ~edit_field:content_field
                           ~focus_handle:content_focus_handle
                           ~f:update_content_constraints;
                       ]
                   ];
                   (if handle_tag_ui then
                      [ Nottui_widgets.hbox
                          [
                            tag_ci_fuzzy_label;
                            make_search_field
                              ~edit_field:tag_ci_fuzzy_field
                              ~focus_handle:tag_ci_fuzzy_focus_handle
                              ~f:update_tag_constraints;
                          ];
                        Nottui_widgets.hbox
                          [
                            tag_ci_full_label;
                            make_search_field
                              ~edit_field:tag_ci_full_field
                              ~focus_handle:tag_ci_full_focus_handle
                              ~f:update_tag_constraints;
                          ];
                        Nottui_widgets.hbox
                          [
                            tag_ci_sub_label;
                            make_search_field
                              ~edit_field:tag_ci_sub_field
                              ~focus_handle:tag_ci_sub_focus_handle
                              ~f:update_tag_constraints;
                          ];
                        Nottui_widgets.hbox
                          [
                            tag_exact_label;
                            make_search_field
                              ~edit_field:tag_exact_field
                              ~focus_handle:tag_exact_focus_handle
                              ~f:update_tag_constraints;
                          ];
                      ]
                    else []);
                 ]
              )
          in
          let rec loop () =
            file_to_open := None;
            Lwd.set quit false;
            (try
               Nottui.Ui_loop.run
                 ~term
                 ~renderer
                 ~quit
                 screen;
             with
             | _ -> Printf.printf "Error: TUI crashed\n"; exit 1
            );
            match !file_to_open with
            | None -> ()
            | Some doc ->
              match Sys.getenv_opt "VISUAL", Sys.getenv_opt "EDITOR" with
              | None, None ->
                Printf.printf "Error: Both env variables VISUAL and EDITOR are unset\n"; exit 1
              | Some editor, _
              | None, Some editor -> (
                  Sys.command (Fmt.str "%s \'%s\'" editor doc.path) |> ignore;
                  loop ()
                )
          in
          loop ()
        )
    )
  )

let files_arg = Arg.(value & pos_all file [ "." ] & info [])

let cmd =
  let doc = "TUI fuzzy document finder" in
  let version = Version_string.s in
  Cmd.v (Cmd.info "docfd" ~version ~doc)
    Term.(const run
          $ debug_arg
          $ max_depth_arg
          $ max_fuzzy_edit_distance_arg
          $ max_word_search_range_arg
          $ tag_ci_fuzzy_arg
          $ tag_ci_full_arg
          $ tag_ci_sub_arg
          $ tag_exact_arg
          $ list_tags_arg
          $ list_tags_lowercase_arg
          $ files_arg)

let () = exit (Cmd.eval cmd)
