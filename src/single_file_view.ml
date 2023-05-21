module Vars = struct
  let search_field_focus_handle = Nottui.Focus.make ()
end

let set_search_result_selected ~choice_count n =
  let n = Misc_utils.bound_selection ~choice_count n in
  Lwd.set Ui_base.Vars.Single_file.index_of_search_result_selected n

let reset_search_result_selected () =
  Lwd.set Ui_base.Vars.Single_file.index_of_search_result_selected 0

let update_search_phrase () =
  reset_search_result_selected ();
  let search_phrase =
    Search_phrase.make
      ~fuzzy_max_edit_distance:!Params.max_fuzzy_edit_distance
      ~phrase:(fst @@ Lwd.peek Ui_base.Vars.Single_file.search_field)
  in
  let document_store =
    Lwd.peek Ui_base.Vars.Single_file.document_store
    |> Document_store.update_search_phrase search_phrase
  in
  Lwd.set Ui_base.Vars.Single_file.document_store document_store

let reload_document (doc : Document.t) : unit =
  match doc.path with
  | None -> ()
  | Some path -> (
      match Document.of_path ~env:(Ui_base.eio_env ()) path with
      | Ok doc -> (
          reset_search_result_selected ();
          let global_document_store =
            Lwd.peek Ui_base.Vars.document_store
            |> Document_store.add_document doc
          in
          Lwd.set Ui_base.Vars.document_store global_document_store;
          let document_store =
            Lwd.peek Ui_base.Vars.Single_file.document_store
            |> Document_store.add_document doc
          in
          Lwd.set Ui_base.Vars.Single_file.document_store document_store;
        )
      | Error _ -> ()
    )

module Top_pane = struct
  let main
    : Nottui.ui Lwd.t =
    Lwd.map ~f:(fun (document_store, search_result_selected) ->
        let _, document_info =
          Option.get (Document_store.min_binding document_store)
        in
        Nottui_widgets.v_pane
          (Ui_base.Content_view.main
             ~document_info
             ~search_result_selected)
          (Ui_base.Search_result_list.main
             ~document_info
             ~index_of_search_result_selected:Ui_base.Vars.Single_file.index_of_search_result_selected)
      )
      Lwd.(pair
             (get Ui_base.Vars.Single_file.document_store)
             (get Ui_base.Vars.Single_file.index_of_search_result_selected))
    |> Lwd.join
end

module Bottom_pane = struct
  let status_bar
      ~(document : Document.t)
      ~(input_mode : Ui_base.input_mode)
    =
    let path =
      match document.path with
      | None -> Params.stdin_doc_path_placeholder
      | Some s -> s
    in
    let content =
      Notty.I.hcat
        [
          List.assoc input_mode Ui_base.Status_bar.input_mode_images;
          Ui_base.Status_bar.element_spacer;
          Notty.I.strf ~attr:Ui_base.Status_bar.attr
            "document: %s" path;
        ]
      |> Nottui.Ui.atom
    in
    Nottui.Ui.join_z
      (Ui_base.Status_bar.background_bar ())
      content
    |> Lwd.return

  module Key_binding_info = struct
    let grid_contents : Ui_base.Key_binding_info.grid_contents =
      let open Ui_base.Key_binding_info in
      let navigate_line0 =
        [
          { label = "Enter"; msg = "open document" };
          { label = "/"; msg = "switch to search mode" };
          { label = "x"; msg = "clear search" };
        ]
      in
      let search_grid =
        [
          [
            { label = "Enter"; msg = "confirm and exit search mode" };
          ];
          [
            { label = ""; msg = "" };
          ];
        ]
      in
      [
        ({ input_mode = Navigate; init_ui_mode = Ui_multi_file },
         [
           navigate_line0;
           [
             { label = "Tab";
               msg = "switch to multi-file view" };
             { label = "r"; msg = "reload" };
             { label = "q"; msg = "exit" };
           ];
         ]
        );
        ({ input_mode = Navigate; init_ui_mode = Ui_single_file },
         [
           navigate_line0;
           [
             { label = "r"; msg = "reload" };
             { label = "q"; msg = "exit" };
           ];
         ]
        );
        ({ input_mode = Search; init_ui_mode = Ui_multi_file },
         search_grid
        );
        ({ input_mode = Search; init_ui_mode = Ui_single_file },
         search_grid
        );
      ]

    let grid_lookup = Ui_base.Key_binding_info.make_grid_lookup grid_contents

    let main ~input_mode =
      Ui_base.Key_binding_info.main ~grid_lookup ~input_mode
  end

  let search_bar ~input_mode =
    Ui_base.Search_bar.main ~input_mode
      ~edit_field:Ui_base.Vars.Single_file.search_field
      ~focus_handle:Vars.search_field_focus_handle
      ~f:(fun () -> update_search_phrase ())

  let main
      ~document_info
    : Nottui.ui Lwd.t =
    let document, _search_results = document_info in
    Lwd.map ~f:(fun input_mode ->
        Nottui_widgets.vbox
          [
            status_bar ~document ~input_mode;
            Key_binding_info.main ~input_mode;
            search_bar ~input_mode;
          ]
      )
      (Lwd.get Ui_base.Vars.input_mode)
    |> Lwd.join
end

let keyboard_handler
    ~(document_info : Document_store.value)
    (key : Nottui.Ui.key)
  =
  let document, search_results = document_info in
  let search_result_choice_count =
    Array.length search_results
  in
  let search_result_current_choice =
    Lwd.peek Ui_base.Vars.Single_file.index_of_search_result_selected
  in
  match Lwd.peek Ui_base.Vars.input_mode with
  | Navigate -> (
      match key with
      | (`Escape, [])
      | (`ASCII 'q', [])
      | (`ASCII 'C', [`Ctrl]) -> (
          Lwd.set Ui_base.Vars.quit true;
          `Handled
        )
      | (`ASCII 'r', []) -> (
          reload_document document;
          `Handled
        )
      | (`Tab, []) -> (
          (match !Ui_base.Vars.init_ui_mode with
           | Ui_multi_file ->
             Lwd.set Ui_base.Vars.ui_mode Ui_multi_file
           | Ui_single_file -> ()
          );
          `Handled
        )
      | (`Page `Down, [])
      | (`Page `Down, [`Shift])
      | (`ASCII 'J', [])
      | (`Arrow `Down, [`Shift])
      | (`ASCII 'j', [])
      | (`Arrow `Down, []) -> (
          set_search_result_selected
            ~choice_count:search_result_choice_count
            (search_result_current_choice+1);
          `Handled
        )
      | (`Page `Up, [])
      | (`Page `Up, [`Shift])
      | (`ASCII 'K', [])
      | (`Arrow `Up, [`Shift])
      | (`ASCII 'k', [])
      | (`Arrow `Up, []) -> (
          set_search_result_selected
            ~choice_count:search_result_choice_count
            (search_result_current_choice-1);
          `Handled
        )
      | (`ASCII '/', []) -> (
          Nottui.Focus.request Vars.search_field_focus_handle;
          Lwd.set Ui_base.Vars.input_mode Search;
          `Handled
        )
      | (`ASCII 'x', []) -> (
          Lwd.set Ui_base.Vars.Single_file.search_field Ui_base.empty_search_field;
          update_search_phrase ();
          `Handled
        )
      | (`Enter, []) -> (
          match !Ui_base.Vars.document_src with
          | Stdin -> `Handled
          | Files _ -> (
              Lwd.set Ui_base.Vars.quit true;
              Ui_base.Vars.file_to_open := Some document;
              `Handled
            )
        )
      | _ -> `Handled
    )
  | Search -> `Unhandled

let main : Nottui.ui Lwd.t =
  Lwd.map ~f:(fun document_store ->
      let _, document_info =
        Option.get (Document_store.min_binding document_store)
      in
      Nottui_widgets.vbox
        [
          Lwd.map ~f:(Nottui.Ui.keyboard_area
                        (keyboard_handler ~document_info))
            Top_pane.main;
          Bottom_pane.main ~document_info;
        ]
    )
    (Lwd.get Ui_base.Vars.Single_file.document_store)
  |> Lwd.join
