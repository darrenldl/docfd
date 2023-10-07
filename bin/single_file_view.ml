open Docfd_lib
open Lwd_infix

module Vars = struct
  let search_field_focus_handle = Nottui.Focus.make ()

  let stop_search_signal = Atomic.make (Stop_signal.make ())
end

let cancel_search () =
  Stop_signal.signal (Atomic.get Vars.stop_search_signal);
  Atomic.set Vars.stop_search_signal (Stop_signal.make ())

let set_search_result_selected ~choice_count n =
  let n = Misc_utils.bound_selection ~choice_count n in
  Lwd.set Ui_base.Vars.Single_file.index_of_search_result_selected n

let reset_search_result_selected () =
  cancel_search ();
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
    |> Document_store.update_search_phrase
      ~stop_signal:(Atomic.get Vars.stop_search_signal)
      search_phrase
  in
  Lwd.set Ui_base.Vars.Single_file.document_store document_store

let reload_document (doc : Document.t) : unit =
  match Document.of_path ~env:(Ui_base.eio_env ()) doc.path with
  | Ok doc -> (
      reset_search_result_selected ();
      let stop_signal = Atomic.get Vars.stop_search_signal in
      let global_document_store =
        Lwd.peek Ui_base.Vars.document_store
        |> Document_store.add_document ~stop_signal doc
      in
      Lwd.set Ui_base.Vars.document_store global_document_store;
      let document_store =
        Lwd.peek Ui_base.Vars.Single_file.document_store
        |> Document_store.add_document ~stop_signal doc
      in
      Lwd.set Ui_base.Vars.Single_file.document_store document_store;
    )
  | Error _ -> ()

module Top_pane = struct
  let main
      ~document_info
    : Nottui.ui Lwd.t =
    let$* search_result_selected =
      Lwd.get Ui_base.Vars.Single_file.index_of_search_result_selected
    in
    let$* (term_width, _term_height) = Lwd.get Ui_base.Vars.term_width_height in
    let width = term_width - Params.line_wrap_underestimate_offset in
    Nottui_widgets.v_pane
      (Ui_base.Content_view.main
         ~width
         ~document_info
         ~search_result_selected)
      (Ui_base.Search_result_list.main
         ~width
         ~document_info
         ~index_of_search_result_selected:Ui_base.Vars.Single_file.index_of_search_result_selected)
end

module Bottom_pane = struct
  let status_bar
      ~(document : Document.t)
      ~(input_mode : Ui_base.input_mode)
    =
    let content =
      Notty.I.hcat
        [
          List.assoc input_mode Ui_base.Status_bar.input_mode_images;
          Ui_base.Status_bar.element_spacer;
          Notty.I.strf ~attr:Ui_base.Status_bar.attr
            "Document: %s" document.path;
        ]
      |> Nottui.Ui.atom
    in
    let$ bar = Ui_base.Status_bar.background_bar in
    Nottui.Ui.join_z bar content

  module Key_binding_info = struct
    let grid_contents : Ui_base.Key_binding_info.grid_contents =
      let open Ui_base.Key_binding_info in
      let navigate_line0 =
        [
          { label = "Enter"; msg = "open document" };
          { label = "/"; msg = "search mode" };
          { label = "x"; msg = "clear search" };
        ]
      in
      let search_grid =
        [
          [
            { label = "Enter"; msg = "exit search mode" };
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
             { label = "Tab"; msg = "multi-file view" };
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
      ~f:update_search_phrase

  let main
      ~document_info
    : Nottui.ui Lwd.t =
    let document, _search_results = document_info in
    let$* input_mode = Lwd.get Ui_base.Vars.input_mode in
    Nottui_widgets.vbox
      [
        status_bar ~document ~input_mode;
        Key_binding_info.main ~input_mode;
        search_bar ~padding:0 ~input_mode;
      ]
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
          cancel_search ();
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
          cancel_search ();
          `Handled
        )
      | (`ASCII 'x', []) -> (
          Lwd.set Ui_base.Vars.Single_file.search_field Ui_base.empty_text_field;
          update_search_phrase ();
          `Handled
        )
      | (`Enter, []) -> (
          Lwd.set Ui_base.Vars.quit true;
          let search_result =
            if search_result_current_choice < Array.length search_results then
              Some search_results.(search_result_current_choice)
            else
              None
          in
          Ui_base.Vars.action :=
            Some (Ui_base.Open_file_and_search_result (document, search_result));
          `Handled
        )
      | _ -> `Handled
    )
  | _ -> `Unhandled

let main : Nottui.ui Lwd.t =
  let$* document_store = Lwd.get Ui_base.Vars.Single_file.document_store in
  let _, document_info =
    Option.get (Document_store.min_binding document_store)
  in
  Nottui_widgets.vbox
    [
      (let$ top_pane = Top_pane.main ~document_info in
       Nottui.Ui.keyboard_area
         (keyboard_handler ~document_info)
         top_pane);
      Bottom_pane.main ~document_info;
    ]
