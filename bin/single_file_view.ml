open Lwd_infix

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
  let s = fst @@ Lwd.peek Ui_base.Vars.Single_file.search_field in
  Document_store_manager.submit_search_req s Ui_base.Vars.Single_file.document_store

let reload_document (doc : Document.t) : unit =
  let pool = Ui_base.task_pool () in
  match
    Document.of_path ~env:(Ui_base.eio_env ()) pool (Document.search_mode doc) (Document.path doc)
  with
  | Ok doc -> (
      reset_search_result_selected ();
      let global_document_store =
        Lwd.peek Ui_base.Vars.document_store
        |> Document_store.add_document pool doc
      in
      Document_store_manager.submit_update_req global_document_store Ui_base.Vars.document_store;
      let document_store =
        Lwd.peek Ui_base.Vars.Single_file.document_store
        |> Document_store.add_document pool doc
      in
      Document_store_manager.submit_update_req document_store Ui_base.Vars.Single_file.document_store;
    )
  | Error _ -> ()

module Top_pane = struct
  let main
      ~width
      ~height
      ~document_info
    : Nottui.ui Lwd.t =
    let$* search_result_selected =
      Lwd.get Ui_base.Vars.Single_file.index_of_search_result_selected
    in
    let sub_pane_height = height / 2 in
    Ui_base.vpane ~width ~height
      (Ui_base.Content_view.main
         ~height:sub_pane_height
         ~width
         ~document_info
         ~search_result_selected)
      (Ui_base.Search_result_list.main
         ~height:sub_pane_height
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
            "Document: %s" (Document.path document |> File_utils.remove_cwd_from_path);
          Ui_base.Status_bar.element_spacer;
          Notty.I.strf ~attr:Ui_base.Status_bar.attr
            "Last scan: %a"
            (Timedesc.pp ~format:Params.last_scan_format_string ())
            (Document.last_scan document);
        ]
      |> Nottui.Ui.atom
    in
    let$ bar = Ui_base.Status_bar.background_bar in
    Nottui.Ui.join_z bar content

  module Key_binding_info = struct
    let grid_contents : Ui_base.Key_binding_info.grid_contents =
      let open Ui_base.Key_binding_info in
      let empty_row =
        [
          { label = ""; msg = "" };
        ]
      in
      let navigate_line0 =
        [
          { label = "Enter"; msg = "open document" };
          { label = "/"; msg = "search mode" };
          { label = "x"; msg = "clear search" };
        ]
      in
      let print_items =
        [
          { label = "p"; msg = "print mode" };
        ]
      in
      let navigate_line2 =
        [
          { label = "r"; msg = "reload" };
        ]
      in
      let search_grid =
        [
          [
            { label = "Enter"; msg = "exit search mode" };
          ];
          empty_row;
          empty_row;
        ]
      in
      let print_grid =
        [
          [
            { label = "p"; msg = "selected search result" };
            { label = "s"; msg = "samples" };
            { label = "a"; msg = "all results" };
          ];
          [
            { label = "Shift+P"; msg = "path" };
            { label = "Esc"; msg = "cancel" };
          ];
          empty_row;
        ]
      in
      [
        ({ input_mode = Navigate; init_ui_mode = Ui_multi_file },
         [
           navigate_line0;
           ({ label = "Tab"; msg = "multi-file view" } :: print_items);
           navigate_line2;
         ]
        );
        ({ input_mode = Navigate; init_ui_mode = Ui_single_file },
         [
           navigate_line0;
           print_items;
           navigate_line2;
         ]
        );
        ({ input_mode = Search; init_ui_mode = Ui_multi_file },
         search_grid
        );
        ({ input_mode = Search; init_ui_mode = Ui_single_file },
         search_grid
        );
        ({ input_mode = Print; init_ui_mode = Ui_multi_file },
         print_grid
        );
        ({ input_mode = Print; init_ui_mode = Ui_single_file },
         print_grid
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
        search_bar ~input_mode;
      ]
end

let keyboard_handler
    ~(document_info : Document_store.document_info)
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
      | (`ASCII 'Q', [`Ctrl])
      | (`ASCII 'C', [`Ctrl]) -> (
          Lwd.set Ui_base.Vars.quit true;
          Ui_base.Vars.action := None;
          `Handled
        )
      | (`ASCII 'r', []) -> (
          Ui_base.Key_binding_info.blink "r";
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
          Ui_base.Key_binding_info.blink "x";
          Lwd.set Ui_base.Vars.Single_file.search_field Ui_base.empty_text_field;
          update_search_phrase ();
          `Handled
        )
      | (`ASCII 'p', []) -> (
          Lwd.set Ui_base.Vars.input_mode Print;
          `Handled
        )
      | (`Enter, []) -> (
          let search_result =
            if search_result_current_choice < Array.length search_results then
              Some search_results.(search_result_current_choice)
            else
              None
          in
          Lwd.set Ui_base.Vars.quit true;
          Ui_base.Vars.action :=
            Some (Ui_base.Open_file_and_search_result (document, search_result));
          `Handled
        )
      | _ -> `Handled
    )
  | Print -> (
      let submit_search_results_print_req doc s =
        Printers.Worker.submit_search_results_print_req `Stderr doc s
      in
      let exit =
        (match key with
         | (`Escape, [])
         | (`ASCII 'Q', [`Ctrl])
         | (`ASCII 'C', [`Ctrl]) -> true
         | (`ASCII 'p', []) -> (
             let (doc, search_results) = document_info in
             (if search_result_current_choice < Array.length search_results then
                Seq.return search_results.(search_result_current_choice)
              else
                Seq.empty)
             |> submit_search_results_print_req doc;
             true
           )
         | (`ASCII 's', []) -> (
             let (doc, search_results) = document_info in
             Array.to_seq search_results
             |> OSeq.take !Params.sample_count_per_document
             |> submit_search_results_print_req doc;
             true
           )
         | (`ASCII 'a', []) -> (
             let (doc, search_results) = document_info in
             Array.to_seq search_results
             |> submit_search_results_print_req doc;
             true
           )
         | (`ASCII 'P', []) -> (
             let (doc, _search_results) = document_info in
             Seq.empty
             |> submit_search_results_print_req doc;
             true
           )
         | _ -> false
        );
      in
      if exit then (
        Lwd.set Ui_base.Vars.input_mode Navigate;
      );
      `Handled
    )
  | _ -> `Unhandled

let main : Nottui.ui Lwd.t =
  let$* document_store = Lwd.get Ui_base.Vars.Single_file.document_store in
  let _, document_info =
    Option.get (Document_store.min_binding document_store)
  in
  let$* bottom_pane = Bottom_pane.main ~document_info in
  let bottom_pane_height = Nottui.Ui.layout_height bottom_pane in
  let$* (term_width, term_height) = Lwd.get Ui_base.Vars.term_width_height in
  let top_pane_height = term_height - bottom_pane_height in
  let$* top_pane =
    Top_pane.main
      ~width:term_width
      ~height:top_pane_height
      ~document_info
  in
  Nottui_widgets.vbox
    [
      Lwd.return (
        Nottui.Ui.keyboard_area
          (keyboard_handler ~document_info)
          top_pane);
      Lwd.return bottom_pane;
    ]
