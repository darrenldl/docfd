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

type input_mode =
  | Navigate
  | Content

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

type document_src =
  | Stdin
  | Files of string list

let run
    (debug : bool)
    (max_depth : int)
    (fuzzy_max_edit_distance : int)
    (max_word_search_range : int)
    (files : string list)
  =
  Params.debug := debug;
  Params.max_file_tree_depth := max_depth;
  Params.max_word_search_range := max_word_search_range;
  Printf.printf "Scanning for text files\n";
  let ui_mode, document_src =
    if not (stdin_is_atty ()) then
      (Ui_single_file, Stdin)
    else (
      match files with
      | [] -> Fmt.pr "Error: No files provided"; exit 1
      | [ f ] -> (
          if Sys.is_directory f then
            (Ui_all_files, Files (list_files_recursively f))
          else
            (Ui_single_file, Files [ f ])
        )
      | _ -> (
          (Ui_all_files,
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
           )
          )
        )
    )
  in
  Printf.printf "Scanning completed\n";
  let files = List.sort_uniq String.compare files in
  if !Params.debug then (
    match document_src with
    | Stdin -> Printf.printf "Document source: stdin\n"
    | Files _ -> (
        Printf.printf "Document source: file\n";
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
      let term =
        match document_src with
        | Stdin ->
          let input =
            Unix.(openfile "/dev/tty" [ O_RDWR ] 0666)
          in
          Notty_unix.Term.create ~input ()
        | Files _ ->
          Notty_unix.Term.create ()
      in
      let renderer = Nottui.Renderer.make () in
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
      let documents = Lwd.map ~f:(fun content_constraints ->
          all_documents
          |> List.filter_map (fun doc ->
              if Content_search_constraints.is_empty content_constraints then
                Some doc
              else (
                match Document.content_search_results content_constraints doc () with
                | Seq.Nil -> None
                | Seq.Cons _ as s ->
                  let content_search_results = (fun () -> s)
                                               |> OSeq.take Params.content_search_result_limit
                                               |> Array.of_seq
                  in
                  Array.sort Content_search_result.compare content_search_results;
                  Some { doc with content_search_results }
              )
            )
          |> (fun l ->
              if Content_search_constraints.is_empty content_constraints then
                l
              else
                List.sort (fun (doc1 : Document.t) (doc2 : Document.t) ->
                    Content_search_result.compare
                      (doc1.content_search_results.(0))
                      (doc2.content_search_results.(0))
                  ) l
            )
          |> Array.of_list
        )
          (Lwd.get content_constraints)
      in
      let bound_selection ~choice_count (x : int) : int =
        max 0 (min (choice_count - 1) x)
      in
      let set_document_selected n =
        Lwd.set document_selected n;
        Lwd.set content_search_result_selected 0
      in
      let empty_content_field = ("", 0) in
      let content_field =
        Lwd.var empty_content_field
      in
      let content_focus_handle = Nottui.Focus.make () in
      let update_content_search_constraints () =
        let constraints' =
          (Content_search_constraints.make
             ~fuzzy_max_edit_distance
             ~phrase:(fst @@ Lwd.peek content_field)
          )
        in
        set_document_selected 0;
        Lwd.set content_constraints constraints'
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
          set_document_selected
            (bound_selection ~choice_count:document_choice_count (document_current_choice+1));
          `Handled
        | `Scroll `Up ->
          set_document_selected
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
          Array.length documents.(document_current_choice).content_search_results
        in
        match Lwd.peek input_mode with
        | Navigate -> (
            match key, ui_mode with
            | ((`Escape, []), _)
            | ((`ASCII 'q', []), _)
            | ((`ASCII 'C', [`Ctrl]), _) -> Lwd.set quit true; `Handled
            | ((`ASCII 'j', []), Ui_all_files)
            | ((`Arrow `Down, []), Ui_all_files) ->
              set_document_selected
                (bound_selection
                   ~choice_count:document_choice_count
                   (document_current_choice+1));
              `Handled
            | ((`ASCII 'k', []), Ui_all_files)
            | ((`Arrow `Up, []), Ui_all_files) ->
              set_document_selected
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
            | ((`ASCII 'x', []), _) ->
              Lwd.set content_field empty_content_field;
              update_content_search_constraints ();
              `Handled
            | ((`Enter, []), _) -> (
                match document_src with
                | Stdin -> `Handled
                | Files _ -> (
                    Lwd.set quit true;
                    file_to_open := Some documents.(document_current_choice);
                    `Handled
                  )
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
                  Render.documents documents
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
              let (_term_width, term_height) = Notty_unix.Term.size term in
              let render_seq s =
                s
                |> OSeq.take term_height
                |> Seq.map Misc_utils.sanitize_string_for_printing
                |> Seq.map (fun s -> Nottui.Ui.atom Notty.(I.string A.empty s))
                |> List.of_seq
                |> Nottui.Ui.vcat
              in
              let doc = documents.(i) in
              let content =
                Content_index.lines doc.content_index
                |> render_seq
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
              let result_count =
                Array.length documents.(i).content_search_results
              in
              if result_count = 0 then (
                Nottui.Ui.empty
              ) else (
                let (_term_width, term_height) = Notty_unix.Term.size term in
                let images =
                  Render.content_search_results
                    ~start:search_result_i
                    ~end_exc:(min (search_result_i + term_height / 2) result_count)
                    documents.(i)
                in
                let pane =
                  images
                  |> Array.map (fun img ->
                      Nottui.Ui.atom (Notty.I.(img <-> strf ""))
                    )
                  |> Array.to_list
                  |> Nottui.Ui.vcat
                in
                Nottui.Ui.join_z (full_term_sized_background ()) pane
                |> Nottui.Ui.mouse_area
                  (content_search_result_list_mouse_handler
                     ~content_search_result_choice_count:result_count
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
      let content_search_control_label =
        let attr = Notty.A.(st bold ++ fg lightyellow) in
        Notty.(I.hcat
                 [ I.string attr  "/"
                 ; I.string A.empty " to input search phrase, "
                 ; I.string attr "Enter"
                 ; I.string A.empty " to confirm, "
                 ; I.string attr "x"
                 ; I.string A.empty " to clear"
                 ]
              )
        |> Nottui.Ui.atom
        |> Lwd.return
      in
      let content_search_label_str = "Content search:" in
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
          Content
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
          content_search_control_label;
          Nottui_widgets.hbox
            [
              content_search_label;
              make_search_field
                ~edit_field:content_field
                ~focus_handle:content_focus_handle
                ~f:update_content_search_constraints;
            ];
        ]
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
                term_height - (List.length bottom_pane_components)
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
          (top_pane
           ::
           bottom_pane_components)
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
