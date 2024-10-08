open Docfd_lib
open Lwd_infix

module Vars = struct
  let index_of_document_selected = Lwd.var 0

  let index_of_search_result_selected = Lwd.var 0

  let file_path_filter_field = Lwd.var Ui_base.empty_text_field

  let file_path_filter_field_focus_handle = Nottui.Focus.make ()

  let search_field = Lwd.var Ui_base.empty_text_field

  let search_field_focus_handle = Nottui.Focus.make ()

  let require_field = Lwd.var Ui_base.empty_text_field

  let require_field_focus_handle = Nottui.Focus.make ()

  let document_store_snapshots : Document_store_snapshot.t Dynarray.t =
    Dynarray.create ()

  let document_store_cur_ver = Lwd.var 0
end

let set_document_selected ~choice_count n =
  let n = Misc_utils.bound_selection ~choice_count n in
  Lwd.set Vars.index_of_document_selected n;
  Lwd.set Vars.index_of_search_result_selected 0

let reset_document_selected () =
  Lwd.set Vars.index_of_document_selected 0;
  Lwd.set Vars.index_of_search_result_selected 0

let set_search_result_selected ~choice_count n =
  let n = Misc_utils.bound_selection ~choice_count n in
  Lwd.set Vars.index_of_search_result_selected n

let update_starting_snapshot_and_recompute_rest
    (starting_snapshot : Document_store_snapshot.t)
  =
  let pool = Ui_base.task_pool () in
  let snapshots = Vars.document_store_snapshots in
  Dynarray.set snapshots 0 starting_snapshot;
  for i=1 to Dynarray.length snapshots - 1 do
    let prev = Dynarray.get snapshots (i - 1) in
    let cur = Dynarray.get snapshots i in
    let store =
      match cur.last_action with
      | None -> prev.store
      | Some action ->
        Option.value ~default:prev.store
          (Document_store.play_action pool action prev.store)
    in
    Dynarray.set snapshots i Document_store_snapshot.{ cur with store }
  done;
  let cur_snapshot =
    Dynarray.get snapshots (Lwd.peek Vars.document_store_cur_ver)
  in
  Document_store_manager.submit_update_req
    `Multi_file_view
    cur_snapshot

let reload_document (doc : Document.t) =
  let pool = Ui_base.task_pool () in
  let path = Document.path doc in
  match
    Document.of_path ~env:(Ui_base.eio_env ()) pool (Document.search_mode doc) path
  with
  | Ok doc -> (
      reset_document_selected ();
      let document_store =
        Dynarray.get Vars.document_store_snapshots 0
        |> (fun x -> x.store)
        |> Document_store.add_document pool doc
      in
      let snapshot =
        Document_store_snapshot.make
          None
          document_store
      in
      update_starting_snapshot_and_recompute_rest snapshot
    )
  | Error _ -> ()

let reload_document_selected
    ~(document_info_s : Document_store.document_info array)
  : unit =
  if Array.length document_info_s > 0 then (
    let index = Lwd.peek Vars.index_of_document_selected in
    let doc, _search_results = document_info_s.(index) in
    reload_document doc;
  )

let sync_input_fields_from_document_store
    (x : Document_store.t)
  =
  Document_store.file_path_filter_glob_string x
  |> (fun s ->
      Lwd.set Vars.file_path_filter_field (s, String.length s));
  Document_store.search_exp_string x
  |> (fun s ->
      Lwd.set Vars.search_field (s, String.length s))

let clear_document_store_later_snapshots () =
  let cur_ver = Lwd.peek Vars.document_store_cur_ver in
  Dynarray.truncate Vars.document_store_snapshots (cur_ver + 1)

let add_document_store_snapshot snapshot =
  clear_document_store_later_snapshots ();
  Dynarray.add_last Vars.document_store_snapshots snapshot;
  let new_ver = Lwd.peek Vars.document_store_cur_ver + 1 in
  Lwd.set Vars.document_store_cur_ver new_ver

let add_document_store_current_version () =
  let snapshot =
    Lwd.peek Document_store_manager.multi_file_view_document_store_snapshot
  in
  add_document_store_snapshot snapshot

let add_document_store_current_version_if_input_fields_changed () =
  let cur_ver = Lwd.peek Vars.document_store_cur_ver in
  if cur_ver = 0 then (
    add_document_store_current_version ()
  ) else (
    let prev_snapshot =
      Dynarray.get Vars.document_store_snapshots (cur_ver - 1)
    in
    let cur_snapshot =
      Lwd.peek Document_store_manager.multi_file_view_document_store_snapshot
    in
    let filter_changed =
      Document_store.file_path_filter_glob_string prev_snapshot.store
      <> Document_store.file_path_filter_glob_string cur_snapshot.store
    in
    let search_changed =
      Document_store.search_exp_string prev_snapshot.store
      <> Document_store.search_exp_string cur_snapshot.store
    in
    if filter_changed || search_changed then (
      add_document_store_current_version ()
    )
  )

let drop ~document_count (choice : [`Path of string | `Listed | `Unlisted]) =
  let choice, new_action =
    match choice with
    | `Path path -> (
        let n = Lwd.peek Vars.index_of_document_selected in
        set_document_selected ~choice_count:(document_count - 1) n;
        (`Path path, `Drop_path path)
      )
    | `Listed -> (
        reset_document_selected ();
        (`Usable, `Drop_listed)
      )
    | `Unlisted -> (
        reset_document_selected ();
        (`Unusable, `Drop_unlisted)
      )
  in
  let cur_snapshot =
    Lwd.peek Document_store_manager.multi_file_view_document_store_snapshot
  in
  add_document_store_snapshot cur_snapshot;
  let new_snapshot =
    Document_store_snapshot.make
      (Some new_action)
      (Document_store.drop choice cur_snapshot.store)
  in
  Document_store_manager.submit_update_req
    `Multi_file_view
    new_snapshot

let update_file_path_filter () =
  reset_document_selected ();
  let s = fst @@ Lwd.peek Vars.file_path_filter_field in
  clear_document_store_later_snapshots ();
  Document_store_manager.submit_filter_req `Multi_file_view s

let update_search_phrase () =
  reset_document_selected ();
  let s = fst @@ Lwd.peek Vars.search_field in
  clear_document_store_later_snapshots ();
  Document_store_manager.submit_search_req `Multi_file_view s

module Top_pane = struct
  module Document_list = struct
    let render_document_preview
        ~width
        ~(document_info : Document_store.document_info)
        ~selected
      : Notty.image =
      let open Notty in
      let open Notty.Infix in
      let (doc, search_results) = document_info in
      let search_result_score_image =
        if Option.is_some !Params.debug_output then (
          if Array.length search_results = 0 then
            I.empty
          else (
            let x = search_results.(0) in
            I.strf "(Best search result score: %f)" (Search_result.score x)
          )
        ) else (
          I.empty
        )
      in
      let sub_item_base_left_padding = I.string A.empty "    " in
      let sub_item_width = width - I.width sub_item_base_left_padding - 2 in
      let preview_left_padding_per_line =
        I.string A.(bg lightgreen) " "
        <|>
        I.string A.empty " "
      in
      let preview_line_images =
        let line_count =
          min Params.preview_line_count (Index.global_line_count (Document.index doc))
        in
        OSeq.(0 --^ line_count)
        |> Seq.map (fun global_line_num ->
            Index.words_of_global_line_num global_line_num (Document.index doc)
            |> List.of_seq
            |> Content_and_search_result_render.Text_block_render.of_words ~width:sub_item_width
          )
        |> Seq.map (fun img ->
            let left_padding =
              OSeq.(0 --^ I.height img)
              |> Seq.map (fun _ -> preview_left_padding_per_line)
              |> List.of_seq
              |> I.vcat
            in
            left_padding <|> img
          )
        |> List.of_seq
      in
      let preview_image =
        I.vcat preview_line_images
      in
      let path_image =
        (I.string A.(fg lightgreen) "@ ")
        <|>
        (Document.path doc
         |> File_utils.remove_cwd_from_path
         |> Tokenize.tokenize ~drop_spaces:false
         |> List.of_seq
         |> Content_and_search_result_render.Text_block_render.of_words ~width:sub_item_width
        )
      in
      let last_scan_image =
        I.string A.(fg lightgreen) "Last scan: "
        <|>
        I.string A.empty
          (Timedesc.to_string ~format:Params.last_scan_format_string (Document.last_scan doc))
      in
      let title =
        let attr =
          if selected then (
            A.(fg lightblue ++ st bold)
          ) else (
            A.(fg lightblue)
          )
        in
        match Document.title doc with
        | None ->
          I.void 0 1
        | Some title -> (
            title
            |> Tokenize.tokenize ~drop_spaces:false
            |> List.of_seq
            |> Content_and_search_result_render.Text_block_render.of_words ~attr ~width
          )
      in
      title
      <->
      (sub_item_base_left_padding
       <|>
       I.vcat
         [ search_result_score_image;
           path_image;
           preview_image;
           last_scan_image;
         ]
      )

    let main
        ~width
        ~height
        ~(document_info_s : Document_store.document_info array)
        ~(document_selected : int)
      : Nottui.ui Lwd.t =
      let document_count = Array.length document_info_s in
      let render_pane () =
        let rec aux index height_filled acc =
          if index < document_count
          && height_filled < height
          then (
            let selected = Int.equal document_selected index in
            let img = render_document_preview ~width ~document_info:document_info_s.(index) ~selected in
            aux (index + 1) (height_filled + Notty.I.height img) (img :: acc)
          ) else (
            List.rev acc
            |> List.map Nottui.Ui.atom
            |> Nottui.Ui.vcat
          )
        in
        if document_count = 0 then (
          Nottui.Ui.empty
        ) else (
          aux document_selected 0 []
        )
      in
      let$ background = Ui_base.full_term_sized_background in
      Nottui.Ui.join_z background (render_pane ())
      |> Nottui.Ui.mouse_area
        (Ui_base.mouse_handler
           ~f:(fun direction ->
               let offset =
                 match direction with
                 | `Up -> -1
                 | `Down -> 1
               in
               let document_current_choice =
                 Lwd.peek Vars.index_of_document_selected
               in
               set_document_selected
                 ~choice_count:document_count
                 (document_current_choice + offset);
             )
        )
  end

  module Right_pane = struct
    let main
        ~width
        ~height
        ~(document_info_s : Document_store.document_info array)
        ~(document_selected : int)
      : Nottui.ui Lwd.t =
      if Array.length document_info_s = 0 then
        let blank ~height =
          let _ = height in
          Nottui_widgets.empty_lwd
        in
        Ui_base.vpane ~width ~height
          blank blank
      else (
        let$* search_result_selected = Lwd.get Vars.index_of_search_result_selected in
        let document_info = document_info_s.(document_selected) in
        Ui_base.vpane ~width ~height
          (Ui_base.Content_view.main
             ~width
             ~document_info
             ~search_result_selected)
          (Ui_base.Search_result_list.main
             ~width
             ~document_info
             ~index_of_search_result_selected:Vars.index_of_search_result_selected)
      )
  end

  let main
      ~width
      ~height
      ~(document_info_s : Document_store.document_info array)
    : Nottui.ui Lwd.t =
    let$* document_selected = Lwd.get Vars.index_of_document_selected in
    Ui_base.hpane ~width ~height
      (Document_list.main
         ~height
         ~document_info_s
         ~document_selected)
      (Right_pane.main
         ~height
         ~document_info_s
         ~document_selected)
end

module Bottom_pane = struct
  let status_bar
      ~width
      ~(document_info_s : Document_store.document_info array)
      ~(input_mode : Ui_base.input_mode)
    : Nottui.Ui.t Lwd.t =
    let open Notty.Infix in
    let$* index_of_document_selected = Lwd.get Vars.index_of_document_selected in
    let document_count = Array.length document_info_s in
    let input_mode_image =
      List.assoc input_mode Ui_base.Status_bar.input_mode_images
    in
    let$* cur_ver = Lwd.get Vars.document_store_cur_ver in
    let$* snapshot =
      Lwd.get Document_store_manager.multi_file_view_document_store_snapshot
    in
    let content =
      let file_shown_count =
        Notty.I.strf ~attr:Ui_base.Status_bar.attr
          "%5d/%d documents listed"
          document_count
          (Document_store.size snapshot.store)
      in
      let version =
        Notty.I.strf ~attr:Ui_base.Status_bar.attr
          "v%d "
          cur_ver
      in
      let desc =
        Notty.I.strf ~attr:Ui_base.Status_bar.attr
          "Last action: %s"
          (match snapshot.last_action with
           | None -> "N/A"
           | Some action -> Action.to_string action)
      in
      let ver_len = Notty.I.width version in
      let desc_len = Notty.I.width desc in
      let desc_overlay =
        Notty.I.void
          (width - desc_len - Ui_base.Status_bar.element_spacing - ver_len) 1
        <|>
        desc
      in
      let version_overlay =
        Notty.I.void (width - ver_len) 1 <|> version
      in
      if document_count = 0 then (
        Notty.I.zcat
          [
            Notty.I.hcat
              [
                input_mode_image;
                Ui_base.Status_bar.element_spacer;
                file_shown_count;
              ];
            desc_overlay;
            version_overlay;
          ]
        |> Nottui.Ui.atom
      ) else (
        let index_of_selected =
          Notty.I.strf ~attr:Ui_base.Status_bar.attr
            "Index of document selected: %d"
            index_of_document_selected
        in
        Notty.I.zcat
          [
            Notty.I.hcat
              [
                input_mode_image;
                Ui_base.Status_bar.element_spacer;
                file_shown_count;
                Ui_base.Status_bar.element_spacer;
                index_of_selected;
              ];
            desc_overlay;
            version_overlay;
          ]
        |> Nottui.Ui.atom
      )
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
      let navigate_grid =
        [
          [
            { label = "Enter"; msg = "open document" };
            { label = "/"; msg = "search mode" };
            { label = "x"; msg = "clear mode" };
            { label = "h"; msg = "edit history" };
          ];
          [
            { label = "Tab"; msg = "single file view" };
            { label = "p"; msg = "print mode" };
            { label = "f"; msg = "filter mode" };
          ];
          [
            { label = "?"; msg = "rotate key binding info" };
            { label = "r"; msg = "reload mode" };
            { label = "d"; msg = "drop mode" };
          ];
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
      let filter_grid =
        [
          [
            { label = "Enter"; msg = "exit filter mode" };
          ];
          empty_row;
          empty_row;
        ]
      in
      let clear_grid =
        [
          [
            { label = "/"; msg = "search field" };
            { label = "f"; msg = "file path filter field" };
          ];
          [
            { label = "Esc"; msg = "cancel" };
          ];
          empty_row;
        ]
      in
      let drop_grid =
        [
          [
            { label = "d"; msg = "selected" };
            { label = "l"; msg = "listed" };
            { label = "u"; msg = "unlisted" };
          ];
          [
            { label = "Esc"; msg = "cancel" };
          ];
          empty_row;
        ]
      in
      let print_grid =
        [
          [
            { label = "p"; msg = "selected search result" };
            { label = "s"; msg = "samples of selected document" };
            { label = "a"; msg = "results of selected document" };
          ];
          [
            { label = "Shift+P"; msg = "path of selected document" };
            { label = "l"; msg = "paths of listed" };
            { label = "u"; msg = "paths of unlisted" };
          ];
          [
            { label = "Shift+S"; msg = "samples of all documents" };
            { label = "Shift+A"; msg = "results of all documents" };
            { label = "Esc"; msg = "cancel" };
          ];
        ]
      in
      let reload_grid =
        [
          [
            { label = "r"; msg = "selected" };
            { label = "a"; msg = "all" };
          ];
          [
            { label = "Esc"; msg = "cancel" };
          ];
          empty_row;
        ]
      in
      [
        ({ input_mode = Navigate; init_ui_mode = Ui_multi_file },
         navigate_grid
        );
        ({ input_mode = Navigate; init_ui_mode = Ui_single_file },
         navigate_grid
        );
        ({ input_mode = Search; init_ui_mode = Ui_multi_file },
         search_grid
        );
        ({ input_mode = Search; init_ui_mode = Ui_single_file },
         search_grid
        );
        ({ input_mode = Filter; init_ui_mode = Ui_multi_file },
         filter_grid
        );
        ({ input_mode = Filter; init_ui_mode = Ui_single_file },
         filter_grid
        );
        ({ input_mode = Clear; init_ui_mode = Ui_multi_file },
         clear_grid
        );
        ({ input_mode = Clear; init_ui_mode = Ui_single_file },
         clear_grid
        );
        ({ input_mode = Drop; init_ui_mode = Ui_multi_file },
         drop_grid
        );
        ({ input_mode = Drop; init_ui_mode = Ui_single_file },
         drop_grid
        );
        ({ input_mode = Print; init_ui_mode = Ui_multi_file },
         print_grid
        );
        ({ input_mode = Print; init_ui_mode = Ui_single_file },
         print_grid
        );
        ({ input_mode = Reload; init_ui_mode = Ui_multi_file },
         reload_grid
        );
        ({ input_mode = Reload; init_ui_mode = Ui_single_file },
         reload_grid
        );
      ]

    let grid_lookup = Ui_base.Key_binding_info.make_grid_lookup grid_contents

    let main ~input_mode =
      Ui_base.Key_binding_info.main ~grid_lookup ~input_mode
  end

  let file_path_filter_bar =
    Ui_base.File_path_filter_bar.main
      ~edit_field:Vars.file_path_filter_field
      ~focus_handle:Vars.file_path_filter_field_focus_handle
      ~f:update_file_path_filter

  let search_bar ~input_mode =
    Ui_base.Search_bar.main ~input_mode
      ~edit_field:Vars.search_field
      ~focus_handle:Vars.search_field_focus_handle
      ~f:update_search_phrase

  let main ~width ~document_info_s =
    let$* input_mode = Lwd.get Ui_base.Vars.input_mode in
    Nottui_widgets.vbox
      [
        status_bar ~width ~document_info_s ~input_mode;
        Key_binding_info.main ~input_mode;
        file_path_filter_bar ~input_mode;
        search_bar ~input_mode;
      ]
end

let keyboard_handler
    ~(document_store : Document_store.t)
    ~(document_info_s : Document_store.document_info array)
    (key : Nottui.Ui.key)
  =
  let document_count =
    Array.length document_info_s
  in
  let document_current_choice =
    Lwd.peek Vars.index_of_document_selected
  in
  let document_info =
    if document_count = 0 then
      None
    else
      Some document_info_s.(document_current_choice)
  in
  let search_result_choice_count =
    match document_info with
    | None -> 0
    | Some (_doc, search_results) -> Array.length search_results
  in
  let search_result_current_choice =
    Lwd.peek Vars.index_of_search_result_selected
  in
  match Lwd.peek Ui_base.Vars.input_mode with
  | Navigate -> (
      match key with
      | (`Escape, [])
      | (`ASCII 'C', [`Ctrl]) -> (
          Lwd.set Ui_base.Vars.quit true;
          Ui_base.Vars.action := None;
          `Handled
        )
      | (`ASCII '?', []) -> (
          Ui_base.Key_binding_info.incr_rotation ();
          `Handled
        )
      | (`ASCII 'd', []) -> (
          Ui_base.set_input_mode Drop;
          `Handled
        )
      | (`ASCII 'r', []) -> (
          Ui_base.set_input_mode Reload;
          `Handled
        )
      | (`ASCII 'p', []) -> (
          Ui_base.set_input_mode Print;
          `Handled
        )
      | (`Arrow `Left, [])
      | (`ASCII 'u', [])
      | (`ASCII 'Z', [`Ctrl]) -> (
          let cur_ver = Lwd.peek Vars.document_store_cur_ver in
          let new_ver = cur_ver - 1 in
          if new_ver >= 0 then (
            let cur_snapshot =
              Lwd.peek Document_store_manager.multi_file_view_document_store_snapshot
            in
            Dynarray.set Vars.document_store_snapshots cur_ver cur_snapshot;
            Lwd.set Vars.document_store_cur_ver new_ver;
            let new_snapshot = Dynarray.get Vars.document_store_snapshots new_ver in
            Document_store_manager.submit_update_req `Multi_file_view new_snapshot;
            reset_document_selected ();
          );
          `Handled
        )
      | (`Arrow `Right, [])
      | (`ASCII 'R', [`Ctrl])
      | (`ASCII 'Y', [`Ctrl]) -> (
          let cur_ver = Lwd.peek Vars.document_store_cur_ver in
          let new_ver = cur_ver + 1 in
          if new_ver < Dynarray.length Vars.document_store_snapshots then (
            let cur_snapshot =
              Lwd.peek Document_store_manager.multi_file_view_document_store_snapshot
            in
            Dynarray.set Vars.document_store_snapshots cur_ver cur_snapshot;
            Lwd.set Vars.document_store_cur_ver new_ver;
            let new_snapshot = Dynarray.get Vars.document_store_snapshots new_ver in
            Document_store_manager.submit_update_req `Multi_file_view new_snapshot;
            reset_document_selected ();
          );
          `Handled
        )
      | (`Tab, []) -> (
          Option.iter (fun (doc, _search_results) ->
              let snapshot =
                Lwd.peek Document_store_manager.multi_file_view_document_store_snapshot
              in
              let single_file_document_store =
                Option.get (Document_store.single_out ~path:(Document.path doc) snapshot.store)
              in
              Document_store_manager.submit_update_req
                `Single_file_view
                { snapshot with store = single_file_document_store };
              Lwd.set Ui_base.Vars.Single_file.index_of_search_result_selected
                (Lwd.peek Vars.index_of_search_result_selected);
              Lwd.set Ui_base.Vars.Single_file.search_field
                (Lwd.peek Vars.search_field);
              Ui_base.set_ui_mode Ui_single_file;
            )
            document_info;
          `Handled
        )
      | (`Page `Down, [`Shift])
      | (`ASCII 'J', [])
      | (`Arrow `Down, [`Shift]) -> (
          set_search_result_selected
            ~choice_count:search_result_choice_count
            (search_result_current_choice+1);
          `Handled
        )
      | (`Page `Up, [`Shift])
      | (`ASCII 'K', [])
      | (`Arrow `Up, [`Shift]) -> (
          set_search_result_selected
            ~choice_count:search_result_choice_count
            (search_result_current_choice-1);
          `Handled
        )
      | (`Page `Down, [])
      | (`ASCII 'j', [])
      | (`Arrow `Down, []) -> (
          set_document_selected
            ~choice_count:document_count
            (document_current_choice+1);
          `Handled
        )
      | (`Page `Up, [])
      | (`ASCII 'k', [])
      | (`Arrow `Up, []) -> (
          set_document_selected
            ~choice_count:document_count
            (document_current_choice-1);
          `Handled
        )
      | (`ASCII 'g', []) -> (
          set_document_selected
            ~choice_count:document_count
            0;
          `Handled
        )
      | (`ASCII 'G', []) -> (
          set_document_selected
            ~choice_count:document_count
            (document_count - 1);
          `Handled
        )
      | (`ASCII 'f', []) -> (
          add_document_store_current_version_if_input_fields_changed ();
          Nottui.Focus.request Vars.file_path_filter_field_focus_handle;
          Ui_base.set_input_mode Filter;
          `Handled
        )
      | (`ASCII '/', []) -> (
          add_document_store_current_version_if_input_fields_changed ();
          Nottui.Focus.request Vars.search_field_focus_handle;
          Ui_base.set_input_mode Search;
          `Handled
        )
      | (`ASCII 'h', []) -> (
          Lwd.set Ui_base.Vars.quit true;
          Ui_base.Vars.action := Some Ui_base.Edit_history;
          `Handled
        )
      | (`ASCII 'x', []) -> (
          Ui_base.set_input_mode Clear;
          `Handled
        )
      | (`Enter, []) -> (
          Option.iter (fun (doc, search_results) ->
              let search_result =
                if search_result_current_choice < Array.length search_results then
                  Some search_results.(search_result_current_choice)
                else
                  None
              in
              Lwd.set Ui_base.Vars.quit true;
              Ui_base.Vars.action :=
                Some (Ui_base.Open_file_and_search_result (doc, search_result));
            )
            document_info;
          `Handled
        )
      | _ -> `Handled
    )
  | Clear -> (
      let exit =
        match key with
        | (`Escape, [])
        | (`ASCII 'C', [`Ctrl]) -> true
        | (`ASCII '/', []) -> (
            Lwd.set Vars.search_field Ui_base.empty_text_field;
            update_search_phrase ();
            true
          )
        | (`ASCII 'f', []) -> (
            Lwd.set Vars.file_path_filter_field Ui_base.empty_text_field;
            update_file_path_filter ();
            true
          )
        | _ -> false
      in
      if exit then (
        Ui_base.set_input_mode Navigate;
      );
      `Handled
    )
  | Drop -> (
      let exit =
        match key with
        | (`Escape, [])
        | (`ASCII 'C', [`Ctrl]) -> true
        | (`ASCII '?', []) -> (
            Ui_base.Key_binding_info.incr_rotation ();
            false
          )
        | (`ASCII 'd', []) -> (
            Option.iter (fun (doc, _search_results) ->
                drop ~document_count (`Path (Document.path doc))
              ) document_info;
            true
          )
        | (`ASCII 'u', []) -> (
            drop ~document_count `Unlisted;
            true
          )
        | (`ASCII 'l', []) -> (
            drop ~document_count `Listed;
            true
          )
        | _ -> false
      in
      if exit then (
        Ui_base.set_input_mode Navigate;
      );
      `Handled
    )
  | Print -> (
      let submit_search_results_print_req doc s =
        Printers.Worker.submit_search_results_print_req `Stderr doc s
      in
      let submit_paths_print_req s =
        Printers.Worker.submit_paths_print_req `Stderr s
      in
      let exit =
        (match key with
         | (`Escape, [])
         | (`ASCII 'C', [`Ctrl]) -> true
         | (`ASCII '?', []) -> (
             Ui_base.Key_binding_info.incr_rotation ();
             false
           )
         | (`ASCII 'p', []) -> (
             Option.iter (fun (doc, search_results) ->
                 (if search_result_current_choice < Array.length search_results then
                    Seq.return search_results.(search_result_current_choice)
                  else
                    Seq.empty)
                 |> submit_search_results_print_req doc
               )
               document_info;
             true
           )
         | (`ASCII 's', []) -> (
             Option.iter (fun (doc, search_results) ->
                 Array.to_seq search_results
                 |> OSeq.take !Params.sample_count_per_document
                 |> submit_search_results_print_req doc
               )
               document_info;
             true
           )
         | (`ASCII 'a', []) -> (
             Option.iter (fun (doc, search_results) ->
                 Array.to_seq search_results
                 |> submit_search_results_print_req doc
               )
               document_info;
             true
           )
         | (`ASCII 'P', []) -> (
             Option.iter (fun (doc, _search_results) ->
                 Seq.empty
                 |> submit_search_results_print_req doc
               )
               document_info;
             true
           )
         | (`ASCII 'l', []) -> (
             Document_store.usable_documents_paths document_store
             |> String_set.to_seq
             |> submit_paths_print_req;
             true
           )
         | (`ASCII 'u', []) -> (
             Document_store.unusable_documents_paths document_store
             |> submit_paths_print_req;
             true
           )
         | (`ASCII 'S', []) -> (
             Array.iter (fun (doc, search_results) ->
                 Array.to_seq search_results
                 |> OSeq.take !Params.sample_count_per_document
                 |> submit_search_results_print_req doc
               )
               document_info_s;
             true
           )
         | (`ASCII 'A', []) -> (
             Array.iter (fun (doc, search_results) ->
                 Array.to_seq search_results
                 |> submit_search_results_print_req doc
               )
               document_info_s;
             true
           )
         | _ -> false
        );
      in
      if exit then (
        Ui_base.set_input_mode Navigate;
      );
      `Handled
    )
  | Reload -> (
      let exit =
        (match key with
         | (`Escape, [])
         | (`ASCII 'C', [`Ctrl]) -> true
         | (`ASCII '?', []) -> (
             Ui_base.Key_binding_info.incr_rotation ();
             false
           )
         | (`ASCII 'r', []) -> (
             reload_document_selected ~document_info_s;
             true
           )
         | (`ASCII 'a', []) -> (
             reset_document_selected ();
             Lwd.set Ui_base.Vars.quit true;
             Ui_base.Vars.action := Some Ui_base.Recompute_document_src;
             true
           )
         | _ -> false
        );
      in
      if exit then (
        Ui_base.set_input_mode Navigate;
      );
      `Handled
    )
  | _ -> `Unhandled

let main : Nottui.ui Lwd.t =
  let$* snapshot =
    Lwd.get Document_store_manager.multi_file_view_document_store_snapshot
  in
  let cur_ver = Lwd.peek Vars.document_store_cur_ver in
  if
    cur_ver = 0
    && Dynarray.length Vars.document_store_snapshots = 0
  then (
    Dynarray.add_last Vars.document_store_snapshots snapshot
  ) else (
    Dynarray.set Vars.document_store_snapshots cur_ver snapshot
  );
  sync_input_fields_from_document_store snapshot.store;
  let document_store = snapshot.store in
  let document_info_s =
    Document_store.usable_documents document_store
  in
  let$* (term_width, term_height) = Lwd.get Ui_base.Vars.term_width_height in
  let$* bottom_pane =
    Bottom_pane.main
      ~width:term_width
      ~document_info_s
  in
  let bottom_pane_height = Nottui.Ui.layout_height bottom_pane in
  let top_pane_height = term_height - bottom_pane_height in
  let$* top_pane =
    Top_pane.main
      ~width:term_width
      ~height:top_pane_height
      ~document_info_s
  in
  Nottui_widgets.vbox
    [
      Lwd.return (Nottui.Ui.keyboard_area
                    (keyboard_handler ~document_store ~document_info_s)
                    top_pane);
      Lwd.return bottom_pane;
    ]
