module Vars = struct
  let search_field = Lwd.var empty_search_field

  let focus_handle = Nottui.Focus.make ()

  let search_results : Search_result.t array Lwd.var = Lwd.var [||]

  let search_result_selected : int Lwd.var = Lwd.var 0

  let document : Document.t Lwd.var = Lwd.var (Document.make_empty ())
end

let set_search_result_selected ~choice_count n =
  let n = Misc_utils.bound_selection ~choice_count n in
  Lwd.set index_of_search_result_selected n

let reset_search_result_selected () =
  Lwd.set index_of_search_result_selected 0

let update_search_constraints ~document () =
  reset_search_result_selected ();
  let search_constraints =
    Search_constraints.make
      ~fuzzy_max_edit_distance:!Params.max_fuzzy_edit_distance
      ~phrase:(fst @@ Lwd.peek Vars.Single_file.search_field)
  in
  let search_results = Document.search search_constraints document
                       |> OSeq.take Params.search_result_limit
                       |> Array.of_seq
  in
  Array.sort Search_result.compare search_results;
  Lwd.set document { document with search_results }

module Top_pane = struct
  let main
    : Nottui.ui Lwd.t =
    Lwd.map ~f:(fun (document, search_result_selected) ->
        Nottui_widgets.v_pane
          [
            Ui_base.Content_view.main ~document ~search_result_selected;
            Ui_base.Search_result_list.main ~document ~search_result_selected;
          ]
      )
      Lwd.(pair
             document
             search_result_selected)
end

module Bottom_pane = struct
  let status_bar ~(document : Document.t) =
    Lwd.map ~f:(fun input_mode ->
        let path =
          match document.path with
          | None -> "<stdin>"
          | Some s -> s
        in
        let content =
          [
            List.assoc input_mode Ui_base.Status_bar.input_mode_images;
            Ui_base.Status_bar.element_spacer;
            Notty.I.strf ~attr:Ui_base.Status_bar.attr
              "document: %s" path;
          ]
        in
        Nottui.Ui.join_z
          (Ui_base.Status_bar.background_bar ())
          content
      )
      (Lwd.get Ui_base.Vars.input_mode)

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

    let main =
      Ui_base.Key_binding_info.main ~input_mode ~grid_contents
  end

  let main
      ~document
    : Nottui.ui Lwd.t =
    Nottui_widgets.hbox
      [
        status_bar ~document;
      ]
end

let keyboard_handler
    (key : Nottui.Ui.key)
  =
  let document = Lwd.peek document in
  match Lwd.peek Ui_base.Vars.input_mode with
  | Navigate -> (
      match key with
      | (`Escape, [])
      | (`ASCII 'q', [])
      | (`ASCII 'C', [`Ctrl]) -> (
          Lwd.set Vars.quit true;
          `Handled
        )
      | (`Tab, []) -> (
          (match !Vars.init_ui_mode with
           | Ui_multi_file ->
             Lwd.set Vars.ui_mode Ui_multi_file
           | Ui_single_file -> ()
          );
          `Handled
        )
      | (`ASCII 'J', [])
      | (`Arrow `Down, [`Shift])
      | (`ASCII 'j', [])
      | (`Arrow `Down, []) -> (
          set_search_result_selected
            ~choice_count:sf_search_result_choice_count
            (sf_search_result_current_choice+1);
          `Handled
        )
      | (`ASCII 'K', [])
      | (`Arrow `Up, [`Shift])
      | (`ASCII 'k', [])
      | (`Arrow `Up, []) -> (
          Single_file.set_search_result_selected
            ~choice_count:sf_search_result_choice_count
            (sf_search_result_current_choice-1);
          `Handled
        )
      | (`ASCII '/', []) -> (
          Nottui.Focus.request Vars.Single_file.focus_handle;
          Lwd.set Vars.input_mode Search;
          `Handled
        )
      | (`ASCII 'x', []) -> (
          Lwd.set Vars.Single_file.search_field empty_search_field;
          Single_file.update_search_constraints ~document:(Option.get document) ();
          `Handled
        )
      | (`Enter, []) -> (
          match !Vars.document_src with
          | Stdin -> `Handled
          | Files _ -> (
              Lwd.set Vars.quit true;
              Vars.file_to_open := document;
              `Handled
            )
        )
      | _ -> `Handled
    )
  | Search -> `Unhandled

let main
    ~document
  : Nottui.ui Lwd.t =
  Lwd.set Vars.document document;
  Nottui_widgets.hbox
    [
      Top_pane.main;
      Bottom_pane.main ~document;
    ]
