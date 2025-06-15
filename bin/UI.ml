open Docfd_lib
open Lwd_infix

module Vars = struct
  let index_of_document_selected = Lwd.var 0

  let index_of_search_result_selected = Lwd.var 0

  let filter_field = Lwd.var UI_base.empty_text_field

  let filter_field_focus_handle = Nottui.Focus.make ()

  let search_field = Lwd.var UI_base.empty_text_field

  let search_field_focus_handle = Nottui.Focus.make ()

  let require_field = Lwd.var UI_base.empty_text_field

  let require_field_focus_handle = Nottui.Focus.make ()

  let init_document_store : Document_store.t ref = ref Document_store.empty

  let document_store_snapshots : Document_store_snapshot.t Dynarray.t =
    Dynarray.create ()

  let document_store_cur_ver = Lwd.var 0

  let document_list_screen_ratio
    : [ `Hide_left
      | `Left_split
      | `Mid_split
      | `Right_split
      | `Hide_right ]
        Lwd.var
    =
    Lwd.var `Mid_split
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

let get_cur_document_store_snapshot () =
  Dynarray.get
    Vars.document_store_snapshots
    (Lwd.peek Vars.document_store_cur_ver)

let sync_input_fields_from_document_store
    (x : Document_store.t)
  =
  Document_store.filter_exp_string x
  |> (fun s ->
      Lwd.set Vars.filter_field (s, String.length s));
  Document_store.search_exp_string x
  |> (fun s ->
      Lwd.set Vars.search_field (s, String.length s))

let submit_update_req_and_sync_input_fields snapshot =
  Document_store_manager.submit_update_req snapshot;
  sync_input_fields_from_document_store
    (Document_store_snapshot.store snapshot)

let update_starting_store_and_recompute_snapshots
    (starting_store : Document_store.t)
  =
  let pool = UI_base.task_pool () in
  let snapshots = Vars.document_store_snapshots in
  Vars.init_document_store := starting_store;
  let starting_snapshot =
    Document_store_snapshot.make
      ~last_command:None
      starting_store
  in
  Dynarray.set snapshots 0 starting_snapshot;
  for i=1 to Dynarray.length snapshots - 1 do
    let prev = Dynarray.get snapshots (i - 1) in
    let prev_store = Document_store_snapshot.store prev in
    let cur = Dynarray.get snapshots i in
    let store =
      match Document_store_snapshot.last_command cur with
      | None -> prev_store
      | Some command ->
        Option.value ~default:prev_store
          (Document_store.run_command pool command prev_store)
    in
    Dynarray.set
      snapshots
      i
      (Document_store_snapshot.update_store store cur)
  done;
  let cur_snapshot = get_cur_document_store_snapshot () in
  submit_update_req_and_sync_input_fields cur_snapshot

let reload_document (doc : Document.t) =
  let pool = UI_base.task_pool () in
  let path = Document.path doc in
  let doc =
    match
      Document.of_path
        ~env:(UI_base.eio_env ())
        pool
        ~already_in_transaction:false
        (Document.search_mode doc)
        path
    with
    | Ok doc -> Some doc
    | Error _ -> (
        None
      )
  in
  let document_store =
    !Vars.init_document_store
    |> (fun store ->
        match doc with
        | Some doc -> (
            Document_store.add_document pool doc store
          )
        | None -> (
            Document_store.drop (`Path path) store
          )
      )
  in
  reset_document_selected ();
  update_starting_store_and_recompute_snapshots document_store

let reload_document_selected
    ~(search_result_groups : Document_store.search_result_group array)
  : unit =
  if Array.length search_result_groups > 0 then (
    let index = Lwd.peek Vars.index_of_document_selected in
    let doc, _search_results = search_result_groups.(index) in
    reload_document doc;
  )

let commit_cur_document_store_snapshot () =
  let cur_ver = Lwd.peek Vars.document_store_cur_ver in
  let cur_snapshot =
    Dynarray.get Vars.document_store_snapshots cur_ver
  in
  Dynarray.truncate Vars.document_store_snapshots (cur_ver + 1);
  Dynarray.add_last Vars.document_store_snapshots cur_snapshot;
  Lwd.set Vars.document_store_cur_ver (cur_ver + 1)

let commit_cur_document_store_snapshot_if_ver_is_first_or_snapshot_id_diff () =
  let cur_ver = Lwd.peek Vars.document_store_cur_ver in
  if cur_ver = 0 then (
    commit_cur_document_store_snapshot ()
  ) else (
    let prev_snapshot_id =
      Dynarray.get Vars.document_store_snapshots (cur_ver - 1)
      |> Document_store_snapshot.id
    in
    let cur_snapshot_id =
      Dynarray.get Vars.document_store_snapshots cur_ver
      |> Document_store_snapshot.id
    in
    if prev_snapshot_id <> cur_snapshot_id then (
      commit_cur_document_store_snapshot ()
    )
  )

let toggle_mark ~path =
  let cur_snapshot = get_cur_document_store_snapshot () in
  commit_cur_document_store_snapshot ();
  let store = Document_store_snapshot.store cur_snapshot in
  let new_snapshot =
    if
      String_set.mem
        path
        (Document_store.marked_document_paths store)
    then (
      Document_store_snapshot.make
        ~last_command:(Some (`Unmark path))
        (Document_store.unmark (`Path path) store)
    ) else (
      Document_store_snapshot.make
        ~last_command:(Some (`Mark path))
        (Document_store.mark (`Path path) store)
    )
  in
  submit_update_req_and_sync_input_fields new_snapshot

let drop ~document_count (choice : [`Path of string | `All_except of string | `Marked | `Unmarked | `Listed | `Unlisted]) =
  let choice, new_command =
    match choice with
    | `Path path -> (
        let n = Lwd.peek Vars.index_of_document_selected in
        set_document_selected ~choice_count:(document_count - 1) n;
        (`Path path, `Drop path)
      )
    | `All_except path -> (
        set_document_selected ~choice_count:1 0;
        (`All_except path, `Drop_all_except path)
      )
    | `Marked -> (
        reset_document_selected ();
        (`Marked, `Drop_marked)
      )
    | `Unmarked -> (
        reset_document_selected ();
        (`Unmarked, `Drop_unmarked)
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
  let cur_snapshot = get_cur_document_store_snapshot () in
  commit_cur_document_store_snapshot ();
  let new_snapshot =
    Document_store_snapshot.make
      ~last_command:(Some new_command)
      (Document_store.drop
         choice
         (Document_store_snapshot.store cur_snapshot))
  in
  submit_update_req_and_sync_input_fields new_snapshot

let narrow_search_scope_to_level ~level =
  let cur_snapshot = get_cur_document_store_snapshot () in
  commit_cur_document_store_snapshot ();
  let new_snapshot =
    Document_store_snapshot.make
      ~last_command:(Some (`Narrow_level level))
      (Document_store.narrow_search_scope_to_level
         ~level
         (Document_store_snapshot.store cur_snapshot))
  in
  submit_update_req_and_sync_input_fields new_snapshot

let update_filter () =
  reset_document_selected ();
  let s = fst @@ Lwd.peek Vars.filter_field in
  Document_store_manager.submit_filter_req s

let update_search () =
  reset_document_selected ();
  let s = fst @@ Lwd.peek Vars.search_field in
  Document_store_manager.submit_search_req s

module Top_pane = struct
  module Document_list = struct
    let render_document_preview
        ~width
        ~documents_marked
        ~(search_result_group : Document_store.search_result_group)
        ~selected
      : Notty.image =
      let open Notty in
      let open Notty.Infix in
      let (doc, search_results) = search_result_group in
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
          min Params.preview_line_count (Index.global_line_count ~doc_hash:(Document.doc_hash doc))
        in
        OSeq.(0 --^ line_count)
        |> Seq.map (fun global_line_num ->
            Index.words_of_global_line_num ~doc_hash:(Document.doc_hash doc) global_line_num
            |> Dynarray.to_list
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
      let marked = String_set.mem (Document.path doc) documents_marked in
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
      (
        (if marked then I.strf "> " else I.void 0 1)
        <|>
        title
      )
      <->
      (
        sub_item_base_left_padding
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
        ~documents_marked
        ~(search_result_groups : Document_store.search_result_group array)
        ~(document_selected : int)
      : Nottui.ui Lwd.t =
      let document_count = Array.length search_result_groups in
      let render_pane () =
        let rec aux index height_filled acc =
          if index < document_count
          && height_filled < height
          then (
            let selected = Int.equal document_selected index in
            let img = render_document_preview ~width ~documents_marked ~search_result_group:search_result_groups.(index) ~selected in
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
      let$ background = UI_base.full_term_sized_background in
      Nottui.Ui.join_z background (render_pane ())
      |> Nottui.Ui.mouse_area
        (UI_base.mouse_handler
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
        ~(search_result_groups : Document_store.search_result_group array)
        ~(document_selected : int)
      : Nottui.ui Lwd.t =
      if Array.length search_result_groups = 0 then (
        let blank ~height =
          let _ = height in
          Nottui_widgets.empty_lwd
        in
        UI_base.vpane ~width ~height
          blank blank
      ) else (
        let$* search_result_selected = Lwd.get Vars.index_of_search_result_selected in
        let search_result_group = search_result_groups.(document_selected) in
        UI_base.vpane ~width ~height
          (UI_base.Content_view.main
             ~width
             ~search_result_group
             ~search_result_selected)
          (UI_base.Search_result_list.main
             ~width
             ~search_result_group
             ~index_of_search_result_selected:Vars.index_of_search_result_selected)
      )
  end

  let main
      ~width
      ~height
      ~documents_marked
      ~(search_result_groups : Document_store.search_result_group array)
    : Nottui.ui Lwd.t =
    let$* document_selected = Lwd.get Vars.index_of_document_selected in
    let$* l_ratio = Lwd.get Vars.document_list_screen_ratio in
    let l_ratio =
      match l_ratio with
      | `Hide_left -> 0.0
      | `Left_split -> 1.0 -. 0.618
      | `Mid_split -> 0.50
      | `Right_split -> 0.618
      | `Hide_right -> 1.0
    in
    UI_base.hpane ~l_ratio ~width ~height
      (Document_list.main
         ~height
         ~documents_marked
         ~search_result_groups
         ~document_selected)
      (Right_pane.main
         ~height
         ~search_result_groups
         ~document_selected)
end

module Bottom_pane = struct
  let status_bar
      ~width
      ~(search_result_groups : Document_store.search_result_group array)
      ~(input_mode : UI_base.input_mode)
    : Nottui.Ui.t Lwd.t =
    let open Notty.Infix in
    let$* index_of_document_selected = Lwd.get Vars.index_of_document_selected in
    let document_count = Array.length search_result_groups in
    let input_mode_image =
      List.assoc input_mode UI_base.Status_bar.input_mode_images
    in
    let$* cur_ver = Lwd.get Vars.document_store_cur_ver in
    let$* snapshot =
      Lwd.get Document_store_manager.document_store_snapshot
    in
    let content =
      let file_shown_count =
        Notty.I.strf ~attr:UI_base.Status_bar.attr
          "%5d/%d documents listed"
          document_count
          (Document_store_snapshot.store snapshot
           |> Document_store.size)
      in
      let version =
        Notty.I.strf ~attr:UI_base.Status_bar.attr
          "v%d "
          cur_ver
      in
      let desc =
        Notty.I.strf ~attr:UI_base.Status_bar.attr
          "Last command: %s"
          (match Document_store_snapshot.last_command snapshot with
           | None -> "N/A"
           | Some command -> Command.to_string command)
      in
      let ver_len = Notty.I.width version in
      let desc_len = Notty.I.width desc in
      let desc_overlay =
        Notty.I.void
          (width - desc_len - UI_base.Status_bar.element_spacing - ver_len) 1
        <|>
        desc
      in
      let version_overlay =
        Notty.I.void (width - ver_len) 1 <|> version
      in
      let core =
        if document_count = 0 then (
          [
            UI_base.Status_bar.element_spacer;
            file_shown_count;
          ]
        ) else (
          let index_of_selected =
            Notty.I.strf ~attr:UI_base.Status_bar.attr
              "Index of document selected: %d"
              index_of_document_selected
          in
          [
            file_shown_count;
            UI_base.Status_bar.element_spacer;
            index_of_selected;
          ]
        )
      in
      Notty.I.zcat
        [
          Notty.I.hcat
            (input_mode_image
             ::
             UI_base.Status_bar.element_spacer
             ::
             core);
          desc_overlay;
          version_overlay;
        ]
      |> Nottui.Ui.atom
    in
    let$ bar = UI_base.Status_bar.background_bar in
    Nottui.Ui.join_z bar content

  module Key_binding_info = struct
    let grid_contents : UI_base.Key_binding_info.grid_contents =
      let open UI_base.Key_binding_info in
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
            { label = "m"; msg = "mark/unmark document" };
            { label = "n"; msg = "narrow mode" };
            { label = "y"; msg = "copy/yank mode" };
          ];
          [
            { label = "?"; msg = "rotate key binding info" };
            { label = "f"; msg = "filter mode" };
            { label = "Shift+M"; msg = "unmark all" };
            { label = "d"; msg = "drop mode" };
            { label = "Shift+Y"; msg = "copy/yank paths mode" };
          ];
          [
            { label = "Ctrl+C"; msg = "exit" };
            { label = "x"; msg = "clear mode" };
            { label = "Tab"; msg = "change pane split ratio" };
            { label = "r"; msg = "reload mode" };
            { label = "h"; msg = "view/edit command history" };
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
            { label = "f"; msg = "filter field" };
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
            { label = "m"; msg = "marked" };
          ];
          [
            { label = "Shift+D"; msg = "unselected" };
            { label = "Shift+L"; msg = "unlisted" };
            { label = "Shift+M"; msg = "unmarked" };
          ];
          [
            { label = "Esc"; msg = "cancel" };
          ];
        ]
      in
      let mark_grid =
        [
          [
            { label = "l"; msg = "listed" };
          ];
          [
            { label = "Shift+L"; msg = "unlisted" };
          ];
          [
            { label = "Esc"; msg = "cancel" };
          ];
        ]
      in
      let copy_grid =
        [
          [
            { label = "y"; msg = "selected search result" };
            { label = "m"; msg = "results of marked documents" };
            { label = "l"; msg = "results of listed documents" };
          ];
          [
            { label = "a"; msg = "results of selected document" };
          ];
          [
            { label = "Esc"; msg = "cancel" };
          ];
        ]
      in
      let copy_paths_grid =
        [
          [
            { label = "y"; msg = "path of selected document" };
            { label = "m"; msg = "paths of marked documents" };
            { label = "l"; msg = "paths of listed documents" };
          ];
          [
            { label = ""; msg = "" };
            { label = "Shift+M"; msg = "paths of unmarked documents" };
            { label = "Shift+L"; msg = "paths of unlisted documents" };
          ];
          [
            { label = "Esc"; msg = "cancel" };
          ];
        ]
      in
      let narrow_grid =
        [
          [
            { label = "0-9"; msg = "narrow search scope to level N" };
          ];
          [
            { label = "Esc"; msg = "cancel" };
          ];
          empty_row;
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
        ({ input_mode = Navigate },
         navigate_grid
        );
        ({ input_mode = Search },
         search_grid
        );
        ({ input_mode = Filter },
         filter_grid
        );
        ({ input_mode = Clear },
         clear_grid
        );
        ({ input_mode = Drop },
         drop_grid
        );
        ({ input_mode = Mark },
         mark_grid
        );
        ({ input_mode = Narrow },
         narrow_grid
        );
        ({ input_mode = Copy },
         copy_grid
        );
        ({ input_mode = Copy_paths },
         copy_paths_grid
        );
        ({ input_mode = Reload },
         reload_grid
        );
      ]

    let grid_lookup = UI_base.Key_binding_info.make_grid_lookup grid_contents

    let main ~input_mode =
      UI_base.Key_binding_info.main ~grid_lookup ~input_mode
  end

  let filter_bar =
    UI_base.Filter_bar.main
      ~edit_field:Vars.filter_field
      ~focus_handle:Vars.filter_field_focus_handle
      ~f:update_filter

  let search_bar ~input_mode =
    UI_base.Search_bar.main ~input_mode
      ~edit_field:Vars.search_field
      ~focus_handle:Vars.search_field_focus_handle
      ~f:update_search

  let main ~width ~search_result_groups =
    let$* input_mode = Lwd.get UI_base.Vars.input_mode in
    Nottui_widgets.vbox
      [
        status_bar ~width ~search_result_groups ~input_mode;
        Key_binding_info.main ~input_mode;
        filter_bar ~input_mode;
        search_bar ~input_mode;
      ]
end

let keyboard_handler
    ~(document_store : Document_store.t)
    ~(search_result_groups : Document_store.search_result_group array)
    (key : Nottui.Ui.key)
  =
  let document_count =
    Array.length search_result_groups
  in
  let document_current_choice =
    Lwd.peek Vars.index_of_document_selected
  in
  let search_result_group =
    if document_count = 0 then
      None
    else
      Some search_result_groups.(document_current_choice)
  in
  let search_result_choice_count =
    match search_result_group with
    | None -> 0
    | Some (_doc, search_results) -> Array.length search_results
  in
  let search_result_current_choice =
    Lwd.peek Vars.index_of_search_result_selected
  in
  match Lwd.peek UI_base.Vars.input_mode with
  | Navigate -> (
      match key with
      | (`ASCII 'C', [`Ctrl])
      | (`ASCII 'Q', [`Ctrl]) -> (
          Lwd.set UI_base.Vars.quit true;
          UI_base.Vars.action := None;
          `Handled
        )
      | (`ASCII '?', []) -> (
          UI_base.Key_binding_info.incr_rotation ();
          `Handled
        )
      | (`ASCII 'm', []) -> (
          let index = Lwd.peek Vars.index_of_document_selected in
          if index < Array.length search_result_groups then (
            let doc, _ = search_result_groups.(index) in
            toggle_mark ~path:(Document.path doc)
          );
          `Handled
        )
      | (`ASCII 'M', []) -> (
          unmark_all ();
          `Handled
        )
      | (`ASCII 'd', []) -> (
          if Document_store_manager.is_idle () then (
            UI_base.set_input_mode Drop;
          ) else (
            UI_base.Key_binding_info.blink "d";
          );
          `Handled
        )
      | (`ASCII 'n', []) -> (
          UI_base.set_input_mode Narrow;
          `Handled
        )
      | (`ASCII 'r', []) -> (
          UI_base.set_input_mode Reload;
          `Handled
        )
      | (`ASCII 'y', []) -> (
          UI_base.set_input_mode Copy;
          `Handled
        )
      | (`ASCII 'Y', []) -> (
          UI_base.set_input_mode Copy_paths;
          `Handled
        )
      | (`Arrow `Left, [])
      | (`ASCII 'u', [])
      | (`ASCII 'Z', [`Ctrl]) -> (
          let cur_ver = Lwd.peek Vars.document_store_cur_ver in
          let new_ver = cur_ver - 1 in
          if new_ver >= 0 then (
            Lwd.set Vars.document_store_cur_ver new_ver;
            let new_snapshot = Dynarray.get Vars.document_store_snapshots new_ver in
            submit_update_req_and_sync_input_fields new_snapshot;
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
            Lwd.set Vars.document_store_cur_ver new_ver;
            let new_snapshot = Dynarray.get Vars.document_store_snapshots new_ver in
            submit_update_req_and_sync_input_fields new_snapshot;
            reset_document_selected ();
          );
          `Handled
        )
      | (`Tab, []) -> (
          (match Lwd.peek Vars.document_list_screen_ratio with
           | `Hide_left -> (
               Lwd.set Vars.document_list_screen_ratio `Hide_right
             )
           | `Left_split -> (
               Lwd.set Vars.document_list_screen_ratio `Hide_left
             )
           | `Mid_split -> (
               Lwd.set Vars.document_list_screen_ratio `Left_split
             )
           | `Right_split -> (
               Lwd.set Vars.document_list_screen_ratio `Mid_split
             )
           | `Hide_right -> (
               Lwd.set Vars.document_list_screen_ratio `Right_split
             )
          );
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
          if document_count = 1 then (
            set_search_result_selected
              ~choice_count:search_result_choice_count
              (search_result_current_choice+1);
            `Handled
          ) else (
            set_document_selected
              ~choice_count:document_count
              (document_current_choice+1);
            `Handled
          )
        )
      | (`Page `Up, [])
      | (`ASCII 'k', [])
      | (`Arrow `Up, []) -> (
          if document_count = 1 then (
            set_search_result_selected
              ~choice_count:search_result_choice_count
              (search_result_current_choice-1);
            `Handled
          ) else (
            set_document_selected
              ~choice_count:document_count
              (document_current_choice-1);
            `Handled
          )
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
          commit_cur_document_store_snapshot_if_ver_is_first_or_snapshot_id_diff ();
          Nottui.Focus.request Vars.filter_field_focus_handle;
          UI_base.set_input_mode Filter;
          `Handled
        )
      | (`ASCII '/', []) -> (
          commit_cur_document_store_snapshot_if_ver_is_first_or_snapshot_id_diff ();
          Nottui.Focus.request Vars.search_field_focus_handle;
          UI_base.set_input_mode Search;
          `Handled
        )
      | (`ASCII 'h', []) -> (
          Lwd.set UI_base.Vars.quit true;
          UI_base.Vars.action := Some UI_base.Edit_command_history;
          `Handled
        )
      | (`ASCII 'x', []) -> (
          UI_base.set_input_mode Clear;
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
              Lwd.set UI_base.Vars.quit true;
              UI_base.Vars.action :=
                Some (UI_base.Open_file_and_search_result (doc, search_result));
            )
            search_result_group;
          `Handled
        )
      | _ -> `Handled
    )
  | Clear -> (
      let exit =
        match key with
        | (`Escape, []) -> true
        | (`ASCII '/', []) -> (
            commit_cur_document_store_snapshot_if_ver_is_first_or_snapshot_id_diff ();
            Lwd.set Vars.search_field UI_base.empty_text_field;
            update_search ();
            true
          )
        | (`ASCII 'f', []) -> (
            commit_cur_document_store_snapshot_if_ver_is_first_or_snapshot_id_diff ();
            Lwd.set Vars.filter_field UI_base.empty_text_field;
            update_filter ();
            true
          )
        | _ -> false
      in
      if exit then (
        UI_base.set_input_mode Navigate;
      );
      `Handled
    )
  | Drop -> (
      let exit =
        match key with
        | (`Escape, []) -> true
        | (`ASCII '?', []) -> (
            UI_base.Key_binding_info.incr_rotation ();
            false
          )
        | (`ASCII 'd', []) -> (
            Option.iter (fun (doc, _search_results) ->
                drop ~document_count (`Path (Document.path doc))
              ) search_result_group;
            true
          )
        | (`ASCII 'D', []) -> (
            Option.iter (fun (doc, _search_results) ->
                drop ~document_count (`All_except (Document.path doc))
              ) search_result_group;
            true
          )
        | (`ASCII 'l', []) -> (
            drop ~document_count `Listed;
            true
          )
        | (`ASCII 'L', []) -> (
            drop ~document_count `Unlisted;
            true
          )
        | (`ASCII 'm', []) -> (
            drop ~document_count `Marked;
            true
          )
        | (`ASCII 'M', []) -> (
            drop ~document_count `Unmarked;
            true
          )
        | _ -> false
      in
      if exit then (
        UI_base.set_input_mode Navigate;
      );
      `Handled
    )
  | Narrow -> (
      let exit =
        match key with
        | (`Escape, []) -> true
        | (`ASCII '?', []) -> (
            UI_base.Key_binding_info.incr_rotation ();
            false
          )
        | (`ASCII c, []) -> (
            let code_0 = Char.code '0' in
            let code_9 = Char.code '9' in
            let code_c = Char.code c in
            if code_0 <= code_c && code_c <= code_9 then (
              let level = code_c - code_0 in
              narrow_search_scope_to_level ~level;
              true
            ) else (
              false
            )
          )
        | _ -> false
      in
      if exit then (
        UI_base.set_input_mode Navigate;
      );
      `Handled
    )
  | Copy -> (
      let copy_search_result_groups (s : Document_store.search_result_group Seq.t) =
        Clipboard.pipe_to_clipboard (fun oc ->
            Printers.search_result_groups
              ~color:false
              ~underline:true
              oc
              s
          )
      in
      let copy_search_result_group x =
        copy_search_result_groups (Seq.return x)
      in
      let exit =
        match key with
        | (`Escape, []) -> true
        | (`ASCII '?', []) -> (
            UI_base.Key_binding_info.incr_rotation ();
            false
          )
        | (`ASCII 'y', []) -> (
            Option.iter (fun (doc, search_results) ->
                copy_search_result_group
                  (doc,
                   (if search_result_current_choice < Array.length search_results then
                      [|search_results.(search_result_current_choice)|]
                    else
                      [||])
                  )
              )
              search_result_group;
            true
          )
        | (`ASCII 'a', []) -> (
            Option.iter
              copy_search_result_group
              search_result_group;
            true
          )
        | (`ASCII 'm', []) -> (
            let marked =
              Document_store.marked_document_paths document_store
            in
            Document_store.search_result_groups document_store
            |> Array.to_seq
            |> Seq.filter (fun (doc, _) ->
                String_set.mem (Document.path doc) marked)
            |> copy_search_result_groups;
            true
          )
        | (`ASCII 'l', []) -> (
            Document_store.search_result_groups document_store
            |> Array.to_seq
            |> copy_search_result_groups;
            true
          )
        | _ -> false
      in
      if exit then (
        UI_base.set_input_mode Navigate;
      );
      `Handled
    )
  | Copy_paths -> (
      let copy_paths s =
        Clipboard.pipe_to_clipboard (fun oc ->
            Seq.iter (Printers.path_image ~color:false oc) s
          )
      in
      let exit =
        match key with
        | (`Escape, []) -> true
        | (`ASCII '?', []) -> (
            UI_base.Key_binding_info.incr_rotation ();
            false
          )
        | (`ASCII 'y', []) -> (
            Option.iter (fun (doc, _search_results) ->
                copy_paths (Seq.return (Document.path doc))
              )
              search_result_group;
            true
          )
        | (`ASCII 'm', []) -> (
            String_set.inter
              (Document_store.usable_document_paths document_store)
              (Document_store.marked_document_paths document_store)
            |> String_set.to_seq
            |> copy_paths;
            true
          )
        | (`ASCII 'M', []) -> (
            String_set.diff
              (Document_store.usable_document_paths document_store)
              (Document_store.marked_document_paths document_store)
            |> String_set.to_seq
            |> copy_paths;
            true
          )
        | (`ASCII 'l', []) -> (
            Document_store.usable_document_paths document_store
            |> String_set.to_seq
            |> copy_paths;
            true
          )
        | (`ASCII 'L', []) -> (
            Document_store.unusable_document_paths document_store
            |> copy_paths;
            true
          )
        | _ -> false
      in
      if exit then (
        UI_base.set_input_mode Navigate;
      );
      `Handled
    )
  | Reload -> (
      let exit =
        (match key with
         | (`Escape, []) -> true
         | (`ASCII '?', []) -> (
             UI_base.Key_binding_info.incr_rotation ();
             false
           )
         | (`ASCII 'r', []) -> (
             reload_document_selected ~search_result_groups;
             true
           )
         | (`ASCII 'a', []) -> (
             reset_document_selected ();
             Lwd.set UI_base.Vars.quit true;
             UI_base.Vars.action := Some UI_base.Recompute_document_src;
             true
           )
         | _ -> false
        );
      in
      if exit then (
        UI_base.set_input_mode Navigate;
      );
      `Handled
    )
  | _ -> `Unhandled

let main : Nottui.ui Lwd.t =
  let$* snapshot =
    Lwd.get Document_store_manager.document_store_snapshot
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
  let document_store =
    Document_store_snapshot.store snapshot
  in
  let search_result_groups =
    Document_store.search_result_groups document_store
  in
  let document_count = Array.length search_result_groups in
  set_document_selected
    ~choice_count:document_count
    (Lwd.peek Vars.index_of_document_selected);
  if document_count > 0 then (
    set_search_result_selected
      ~choice_count:(Array.length
                       (snd search_result_groups.(Lwd.peek Vars.index_of_document_selected)))
      (Lwd.peek Vars.index_of_search_result_selected)
  );
  let$* (term_width, term_height) = Lwd.get UI_base.Vars.term_width_height in
  let$* bottom_pane =
    Bottom_pane.main
      ~width:term_width
      ~search_result_groups
  in
  let bottom_pane_height = Nottui.Ui.layout_height bottom_pane in
  let top_pane_height = term_height - bottom_pane_height in
  let$* top_pane =
    Top_pane.main
      ~width:term_width
      ~height:top_pane_height
      ~documents_marked:(Document_store.marked_document_paths document_store)
      ~search_result_groups
  in
  Nottui_widgets.vbox
    [
      Lwd.return (Nottui.Ui.keyboard_area
                    (keyboard_handler ~document_store ~search_result_groups)
                    top_pane);
      Lwd.return bottom_pane;
    ]
