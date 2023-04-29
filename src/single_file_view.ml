module Vars = struct
  let search_field_focus_handle = Nottui.Focus.make ()
end

let set_search_result_selected ~choice_count n =
  let n = Misc_utils.bound_selection ~choice_count n in
  Lwd.set Ui_base.Vars.Single_file.index_of_search_result_selected n

let reset_search_result_selected () =
  Lwd.set Ui_base.Vars.Single_file.index_of_search_result_selected 0

let update_search_constraints ~document =
  reset_search_result_selected ();
  let search_constraints =
    Search_constraints.make
      ~fuzzy_max_edit_distance:!Params.max_fuzzy_edit_distance
      ~phrase:(fst @@ Lwd.peek Ui_base.Vars.Single_file.search_field)
  in
  let search_results = Document.search search_constraints document
                       |> OSeq.take Params.search_result_limit
                       |> Array.of_seq
  in
  Array.sort Search_result.compare search_results;
  Lwd.set Ui_base.Vars.document_selected { document with search_results }

module Top_pane = struct
  let main
    : Nottui.ui Lwd.t =
    Lwd.map ~f:(fun (document, search_result_selected) ->
        Nottui_widgets.v_pane
          (Ui_base.Content_view.main ~document ~search_result_selected)
          (Ui_base.Search_result_list.main ~document ~search_result_selected)
      )
      Lwd.(pair
             (get Ui_base.Vars.document_selected)
             (get Ui_base.Vars.Single_file.index_of_search_result_selected))
    |> Lwd.join
end

module Bottom_pane = struct
  let status_bar ~(document : Document.t) ~(input_mode : Ui_base.input_mode) =
    let path =
      match document.path with
      | None -> "<stdin>"
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
      [
        (Navigate,
         [
           [
             { key = "Enter"; msg = "open document" };
             { key = "/"; msg = "switch to search mode" };
             { key = "x"; msg = "clear search" };
           ];
           [
             { key = "Tab";
               msg = "switch to multi file view" };
             { key = "q"; msg = "exit" };
           ];
         ]
        );
        (Search,
         [
           [
             { key = "Enter"; msg = "confirm and exit search mode" };
           ];
           [
             { key = ""; msg = "" };
           ];
         ]
        );
      ]

    let grid_lookup = Ui_base.Key_binding_info.make_grid_lookup grid_contents

    let main ~input_mode =
      Ui_base.Key_binding_info.main ~grid_lookup ~input_mode
  end

  let search_bar ~document ~input_mode =
    Ui_base.Search_bar.main ~input_mode
      ~edit_field:Ui_base.Vars.Single_file.search_field
      ~focus_handle:Vars.search_field_focus_handle
      ~f:(fun () -> update_search_constraints ~document)

  let main
      ~document
    : Nottui.ui Lwd.t =
    Lwd.map ~f:(fun input_mode ->
        Nottui_widgets.vbox
          [
            status_bar ~document ~input_mode;
            Key_binding_info.main ~input_mode;
            search_bar ~document ~input_mode;
          ]
      )
      (Lwd.get Ui_base.Vars.input_mode)
    |> Lwd.join
end

let keyboard_handler
    (key : Nottui.Ui.key)
  =
  let document = Lwd.peek Ui_base.Vars.document_selected in
  let search_result_choice_count =
    Array.length document.search_results
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
      | (`Tab, []) -> (
          (match !Ui_base.Vars.init_ui_mode with
           | Ui_multi_file ->
             Lwd.set Ui_base.Vars.ui_mode Ui_multi_file
           | Ui_single_file -> ()
          );
          `Handled
        )
      | (`ASCII 'J', [])
      | (`Arrow `Down, [`Shift])
      | (`ASCII 'j', [])
      | (`Arrow `Down, []) -> (
          set_search_result_selected
            ~choice_count:search_result_choice_count
            (search_result_current_choice+1);
          `Handled
        )
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
          update_search_constraints ~document;
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

let main
  : Nottui.ui Lwd.t =
  Lwd.map ~f:(fun document ->
      Nottui_widgets.vbox
        [
          Lwd.map ~f:(Nottui.Ui.keyboard_area keyboard_handler)
            Top_pane.main;
          Bottom_pane.main ~document;
        ]
    )
    (Lwd.get Ui_base.Vars.document_selected)
  |> Lwd.join
