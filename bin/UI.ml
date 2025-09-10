open Docfd_lib
open Lwd_infix

module Vars = struct
  let save_script_field = Lwd.var UI_base.empty_text_field

  let save_script_field_focus_handle = Nottui.Focus.make ()

  let document_list_screen_ratio
    : [ `Hide_left
      | `Left_split
      | `Mid_split
      | `Right_split
      | `Hide_right ]
        Lwd.var
    =
    Lwd.var `Mid_split

  let script_files : string Dynarray.t Lwd.var = Lwd.var (Dynarray.create ())

  let script_selected = Lwd.var 0

  let usable_script_files : string Dynarray.t Lwd.t =
    let$* arr = Lwd.get script_files in
    let$ script_name_specified, _ = Lwd.get save_script_field in
    let acc = Dynarray.create () in
    Dynarray.iter (fun s ->
        if CCString.starts_with ~prefix:script_name_specified s then (
          Dynarray.add_last acc s;
        )
      ) arr;
    acc

  let sort_by : Document_store.Sort_by.t Lwd.var = Lwd.var Document_store.Sort_by.default

  let search_result_groups : Document_store.search_result_group array Lwd.t =
    let$* _ver, snapshot =
      Document_store_manager.cur_snapshot
    in
    let document_store =
      Document_store_snapshot.store snapshot
    in
    let$ sort_by = Lwd.get sort_by in
    Document_store.search_result_groups ~sort_by document_store
end

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
    Document_store_manager.lock_with_view (fun view ->
        view.init_document_store
      )
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
  Document_store_manager.update_starting_store document_store

let reload_document_selected
    ~(search_result_groups : Document_store.search_result_group array)
  : unit =
  if Array.length search_result_groups > 0 then (
    let index = Lwd.peek UI_base.Vars.index_of_document_selected in
    let doc, _search_results = search_result_groups.(index) in
    reload_document doc;
  )

let toggle_mark ~path =
  Document_store_manager.update_from_cur_snapshot
    (fun cur_snapshot ->
       let store = Document_store_snapshot.store cur_snapshot in
       let new_command =
         if
           String_set.mem
             path
             (Document_store.marked_document_paths store)
         then (
           `Unmark path
         ) else (
           `Mark path
         )
       in
       store
       |> Document_store.run_command
         (UI_base.task_pool ())
         new_command
       |> Option.get
       |> Document_store_snapshot.make
         ~last_command:(Some new_command)
    )

let drop ~document_count (choice : [`Path of string | `All_except of string | `Marked | `Unmarked | `Listed | `Unlisted]) =
  let new_command =
    match choice with
    | `Path path -> (
        let n = Lwd.peek UI_base.Vars.index_of_document_selected in
        UI_base.set_document_selected ~choice_count:(document_count - 1) n;
        `Drop path
      )
    | `All_except path -> (
        UI_base.set_document_selected ~choice_count:1 0;
        `Drop_all_except path
      )
    | `Marked -> (
        UI_base.reset_document_selected ();
        `Drop_marked
      )
    | `Unmarked -> (
        UI_base.reset_document_selected ();
        `Drop_unmarked
      )
    | `Listed -> (
        UI_base.reset_document_selected ();
        `Drop_listed
      )
    | `Unlisted -> (
        UI_base.reset_document_selected ();
        `Drop_unlisted
      )
  in
  Document_store_manager.update_from_cur_snapshot (fun cur_snapshot ->
      Document_store_snapshot.store cur_snapshot
      |> Document_store.run_command
        (UI_base.task_pool ())
        new_command
      |> Option.get
      |> Document_store_snapshot.make
        ~last_command:(Some new_command)
    )

let mark (choice : [`Path of string | `Listed]) =
  let new_command =
    match choice with
    | `Path path -> `Mark path
    | `Listed -> `Mark_listed
  in
  Document_store_manager.update_from_cur_snapshot (fun cur_snapshot ->
      Document_store_snapshot.store cur_snapshot
      |> Document_store.run_command
        (UI_base.task_pool ())
        new_command
      |> Option.get
      |> Document_store_snapshot.make
        ~last_command:(Some new_command)
    )

let unmark (choice : [`Path of string | `Listed | `All]) =
  let new_command =
    match choice with
    | `Path path -> `Unmark path
    | `Listed -> `Unmark_listed
    | `All -> `Unmark_all
  in
  Document_store_manager.update_from_cur_snapshot (fun cur_snapshot ->
      Document_store_snapshot.store cur_snapshot
      |> Document_store.run_command
        (UI_base.task_pool ())
        new_command
      |> Option.get
      |> Document_store_snapshot.make
        ~last_command:(Some new_command)
    )

let narrow_search_scope_to_level ~level =
  Document_store_manager.update_from_cur_snapshot (fun cur_snapshot ->
      Document_store_snapshot.make
        ~last_command:(Some (`Narrow_level level))
        (Document_store.narrow_search_scope_to_level
           ~level
           (Document_store_snapshot.store cur_snapshot))
    )

let update_filter ~commit () =
  let s = fst @@ Lwd.peek UI_base.Vars.filter_field in
  Document_store_manager.submit_filter_req ~commit s

let update_search ~commit () =
  let s = fst @@ Lwd.peek UI_base.Vars.search_field in
  Document_store_manager.submit_search_req ~commit s

let compute_save_script_path () =
  let base_name, _ = Lwd.peek Vars.save_script_field in
  let dir = Params.script_dir () in
  File_utils.mkdir_recursive dir;
  Filename.concat
    dir
    (Fmt.str "%s%s" base_name Params.docfd_script_ext)

let save_script ~path =
  let comments =
    try
      if Sys.file_exists path then (
        CCIO.with_in path (fun ic ->
            CCIO.read_lines_seq ic
            |> Seq.filter String_utils.line_is_comment
            |> List.of_seq
          )
      ) else (
        []
      )
    with
    | Sys_error _ -> (
        Misc_utils.exit_with_error_msg
          (Fmt.str "failed to read script %s" path)
      )
  in
  Document_store_manager.stop_filter_and_search_and_restore_input_fields ();
  let lines =
    Document_store_manager.lock_with_view (fun view ->
        view.snapshots
        |> Dynarray.to_seq
        |> Seq.filter_map  (fun (snapshot : Document_store_snapshot.t) ->
            Option.map
              Command.to_string
              (Document_store_snapshot.last_command snapshot)
          )
        |> List.of_seq
      )
  in
  try
    CCIO.with_out path (fun oc ->
        CCIO.write_lines_l oc comments;
        CCIO.write_lines_l oc lines;
      )
  with
  | Sys_error _ -> (
      Misc_utils.exit_with_error_msg
        (Fmt.str "failed to write script %s" path)
    )

module Top_pane = struct
  module Document_list = struct
    let render_document_entry
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
          min Params.preview_line_count (Index.global_line_count ~doc_id:(Document.doc_id doc))
        in
        OSeq.(0 --^ line_count)
        |> Seq.map (fun global_line_num ->
            Index.words_of_global_line_num ~doc_id:(Document.doc_id doc) global_line_num
            |> Dynarray.to_list
            |> Content_and_search_result_rendering.Text_block_render.of_words ~width:sub_item_width
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
         |> Tokenization.tokenize ~drop_spaces:false
         |> List.of_seq
         |> Content_and_search_result_rendering.Text_block_render.of_words ~width:sub_item_width
        )
      in
      let path_date_image =
        (match Document.path_date doc with
         | None -> I.void 0 0
         | Some date -> (
             I.string A.(fg lightgreen) "  ⤷ "
             <|>
             I.string A.empty
               (Timedesc.Date.to_rfc3339 date)
           )
        )
      in
      let last_modified_image =
        I.string A.(fg lightgreen) "Last modified: "
        <|>
        I.string A.empty
          (Timedesc.to_string ~format:Params.last_modified_format_string (Document.mod_time doc))
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
            |> Tokenization.tokenize ~drop_spaces:false
            |> List.of_seq
            |> Content_and_search_result_rendering.Text_block_render.of_words ~attr ~width
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
            path_date_image;
            preview_image;
            last_modified_image;
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
            let img = render_document_entry ~width ~documents_marked ~search_result_group:search_result_groups.(index) ~selected in
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
                 Lwd.peek UI_base.Vars.index_of_document_selected
               in
               UI_base.set_document_selected
                 ~choice_count:document_count
                 (document_current_choice + offset);
             )
        )
  end

  module Right_pane = struct
    module Search_result_list = struct
      let main
          ~height
          ~width
          ~(search_result_group : Document_store.search_result_group)
          ~(index_of_search_result_selected : int Lwd.var)
        : Nottui.ui Lwd.t =
        let (document, search_results) = search_result_group in
        let search_result_selected = Lwd.peek index_of_search_result_selected in
        let result_count = Array.length search_results in
        if result_count = 0 then (
          Lwd.return Nottui.Ui.empty
        ) else (
          let images =
            Misc_utils.array_sub_seq
              ~start:search_result_selected
              ~end_exc:(min result_count (search_result_selected + height))
              search_results
            |> Seq.map (Content_and_search_result_rendering.search_result
                          ~doc_id:(Document.doc_id document)
                          ~render_mode:(UI_base.render_mode_of_document document)
                          ~width
                       )
            |> List.of_seq
          in
          let pane =
            images
            |> List.map (fun img ->
                Nottui.Ui.atom Notty.I.(img <-> strf "")
              )
            |> Nottui.Ui.vcat
          in
          let$ background = UI_base.full_term_sized_background in
          Nottui.Ui.join_z background pane
          |> Nottui.Ui.mouse_area
            (UI_base.mouse_handler
               ~f:(fun direction ->
                   let n = Lwd.peek index_of_search_result_selected in
                   let offset =
                     match direction with
                     | `Up -> -1
                     | `Down -> 1
                   in
                   UI_base.set_search_result_selected
                     ~choice_count:result_count
                     (n + offset)
                 )
            )
        )
    end

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
        let$* search_result_selected = Lwd.get UI_base.Vars.index_of_search_result_selected in
        let search_result_group = search_result_groups.(document_selected) in
        UI_base.vpane ~width ~height
          (UI_base.Content_view.main
             ~width
             ~search_result_group
             ~search_result_selected)
          (Search_result_list.main
             ~width
             ~search_result_group
             ~index_of_search_result_selected:UI_base.Vars.index_of_search_result_selected)
      )
  end

  let script_list
      ~width
      ~height
    : Nottui.ui Lwd.t =
    let$ scripts = Vars.usable_script_files in
    Dynarray.to_seq scripts
    |> Seq.map (fun s ->
        let open Notty in
        let attr =
          A.(fg lightblue)
        in
        let img = I.strf ~attr "%s" s in
        Nottui.Ui.atom img
      )
    |> List.of_seq
    |> Nottui.Ui.vcat
    |> Nottui.Ui.resize ~w:width ~h:height

  let main
      ~width
      ~height
      ~documents_marked
      ~(search_result_groups : Document_store.search_result_group array)
    : Nottui.ui Lwd.t =
    let$* input_mode = Lwd.get UI_base.Vars.input_mode in
    match input_mode with
    | Save_script -> (
        script_list ~width ~height
      )
    | _ -> (
        let$* document_selected = Lwd.get UI_base.Vars.index_of_document_selected in
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
      )
end

module Bottom_pane = struct
  let status_bar
      ~width
      ~(search_result_groups : Document_store.search_result_group array)
      ~(input_mode : UI_base.input_mode)
    : Nottui.Ui.t Lwd.t =
    let open Notty.Infix in
    let input_mode_image =
      List.assoc input_mode UI_base.Status_bar.input_mode_images
    in
    let attr = UI_base.Status_bar.attr in
    let edit_field = Vars.save_script_field in
    let$* usable_script_files = Vars.usable_script_files in
    match input_mode with
    | Save_script -> (
        let$* content =
          Nottui_widgets.hbox
            [
              Lwd.return
                (Nottui.Ui.atom
                   (Notty.I.hcat
                      [
                        input_mode_image;
                        UI_base.Status_bar.element_spacer;
                        Notty.I.strf ~attr "Save as: [ ";
                      ]));
              UI_base.wrapped_edit_field edit_field
                ~focus:Vars.save_script_field_focus_handle
                ~on_change:(fun (text, x) ->
                    Lwd.set edit_field (text, x);
                  )
                ~on_submit:(fun (text, x) ->
                    Lwd.set edit_field (text, x);
                    Nottui.Focus.release Vars.save_script_field_focus_handle;
                    Lwd.set UI_base.Vars.input_mode
                      (if String.length text = 0 then
                         Save_script_no_name
                       else
                         Save_script_overwrite
                      );
                  )
                ~on_tab:(fun (text, _) ->
                    let best_fit =
                      let usable_script_count = Dynarray.length usable_script_files in
                      if usable_script_count = 0 then (
                        text
                      ) else if usable_script_count = 1 then (
                        Filename.chop_extension (Dynarray.get usable_script_files 0)
                      ) else (
                        usable_script_files
                        |> Dynarray.to_seq
                        |> String_utils.longest_common_prefix
                      )
                    in
                    Lwd.set edit_field (best_fit, String.length best_fit)
                  );
              Lwd.return (Nottui.Ui.atom (Notty.I.strf ~attr " ] + %s. Confirm with empty field to cancel saving." Params.docfd_script_ext));
            ]
        in
        let$ bar = UI_base.Status_bar.background_bar in
        Nottui.Ui.join_z bar content
      )
    | Save_script_overwrite -> (
        let path = compute_save_script_path () in
        if Sys.file_exists path then (
          let$* content =
            Lwd.return
              (Nottui.Ui.atom
                 (Notty.I.hcat
                    [
                      input_mode_image;
                      UI_base.Status_bar.element_spacer;
                      Notty.I.strf ~attr "%s already exists, overwrite? Existing comments will be moved to the top of the file."
                        (Filename.basename path);
                    ]))
          in
          let$ bar = UI_base.Status_bar.background_bar in
          Nottui.Ui.join_z bar content
        ) else (
          save_script ~path;
          Lwd.set UI_base.Vars.input_mode Save_script_edit;
          UI_base.Status_bar.background_bar
        )
      )
    | Save_script_no_name -> (
        let$* content =
          Lwd.return
            (Nottui.Ui.atom
               (Notty.I.hcat
                  [
                    input_mode_image;
                    UI_base.Status_bar.element_spacer;
                    Notty.I.strf ~attr "No name entered, saving skipped";
                  ]))
        in
        let$ bar = UI_base.Status_bar.background_bar in
        Nottui.Ui.join_z bar content
      )
    | Save_script_edit -> (
        let path = compute_save_script_path () in
        let$* content =
          Lwd.return
            (Nottui.Ui.atom
               (Notty.I.hcat
                  [
                    input_mode_image;
                    UI_base.Status_bar.element_spacer;
                    Notty.I.strf ~attr "Do you want to edit %s to add comments etc?" (Filename.basename path);
                  ]))
        in
        let$ bar = UI_base.Status_bar.background_bar in
        Nottui.Ui.join_z bar content
      )
    | _ -> (
        let$* index_of_document_selected = Lwd.get UI_base.Vars.index_of_document_selected in
        let document_count = Array.length search_result_groups in
        let$* (cur_ver, snapshot) = Document_store_manager.cur_snapshot in
        let content =
          let file_shown_count =
            Notty.I.strf ~attr
              "%5d/%d documents listed"
              document_count
              (Document_store_snapshot.store snapshot
               |> Document_store.size)
          in
          let version =
            Notty.I.strf ~attr
              "v%d "
              cur_ver
          in
          let desc =
            Notty.I.strf ~attr
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
                Notty.I.strf ~attr
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
      )

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
            { label = "↑/↓/j/k"; msg = "select document" };
            { label = "s"; msg = "sort asc mode" };
            { label = "y"; msg = "copy/yank mode" };
            { label = "n"; msg = "narrow mode" };
            { label = "Space"; msg = "toggle mark" };
            { label = "h"; msg = "command history" };
          ];
          [
            { label = "?"; msg = "rotate key binding info" };
            { label = "f"; msg = "filter mode" };
            { label = "Shift+↑/↓/j/k"; msg = "select search result" };
            { label = "Shift+S"; msg = "sort desc mode" };
            { label = "Shift+Y"; msg = "copy/yank paths mode" };
            { label = "d"; msg = "drop mode" };
            { label = "m"; msg = "mark mode" };
            { label = "Ctrl+S"; msg = "save script" };
          ];
          [
            { label = "Ctrl+C"; msg = "exit" };
            { label = "x"; msg = "clear mode" };
            { label = "-/="; msg = "scroll content view" };
            { label = "Tab"; msg = "change pane split ratio" };
            { label = ""; msg = "" };
            { label = "r"; msg = "reload mode" };
            { label = "Shift+M"; msg = "unmark mode" };
            { label = "Ctrl+O"; msg = "load script" };
          ];
        ]
      in
      let search_grid =
        [
          [
            { label = "Enter"; msg = "exit search mode" };
          ];
        ]
      in
      let filter_grid =
        [
          [
            { label = "Enter"; msg = "exit filter mode" };
            { label = "Tab"; msg = "autocomplete" };
          ];
        ]
      in
      let save_script_grid =
        [
          [
            { label = "Enter"; msg = "confirm answer" };
            { label = "Tab"; msg = "autocomplete" };
          ];
          empty_row;
          empty_row;
        ]
      in
      let save_script_confirm_grid =
        [
          [
            { label = "y"; msg = "confirm overwrite" };
            { label = "Esc/n"; msg = "cancel" };
          ];
          empty_row;
          empty_row;
        ]
      in
      let save_script_cancel_grid =
        [
          [
            { label = "Enter"; msg = "confirm" };
          ];
          empty_row;
          empty_row;
        ]
      in
      let save_script_edit_grid =
        [
          [
            { label = "y"; msg = "open in editor" };
            { label = "Esc/n"; msg = "skip" };
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
      let sort_grid =
        [
          [
            { label = "s"; msg = "score" };
            { label = "p"; msg = "path" };
            { label = "d"; msg = "path date" };
            { label = "m"; msg = "mod time" };
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
          empty_row;
          [
            { label = "Esc"; msg = "cancel" };
          ];
        ]
      in
      let unmark_grid =
        [
          [
            { label = "l"; msg = "listed" };
            { label = "a"; msg = "all" };
          ];
          empty_row;
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
        ({ input_mode = Sort `Asc },
         sort_grid
        );
        ({ input_mode = Sort `Desc },
         sort_grid
        );
        ({ input_mode = Drop },
         drop_grid
        );
        ({ input_mode = Mark },
         mark_grid
        );
        ({ input_mode = Unmark },
         unmark_grid
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
        ({ input_mode = Save_script },
         save_script_grid
        );
        ({ input_mode = Save_script_overwrite },
         save_script_confirm_grid
        );
        ({ input_mode = Save_script_no_name },
         save_script_cancel_grid
        );
        ({ input_mode = Save_script_edit },
         save_script_edit_grid
        );
      ]

    let grid_lookup = UI_base.Key_binding_info.make_grid_lookup grid_contents

    let main ~input_mode =
      UI_base.Key_binding_info.main ~grid_lookup ~input_mode
  end

  let autocomplete_grid ~input_mode ~width =
    match input_mode with
    | UI_base.Filter | Search -> (
        let$* l = Lwd.get UI_base.Vars.autocomplete_choices in
        let max_len =
          List.fold_left (fun n x ->
              max n (String.length x)
            ) 0 l
        in
        let cell_len = max_len + 4 in
        let cells_per_row = width / cell_len in
        l
        |> CCList.chunks cells_per_row
        |> (fun rows ->
            let row_count = List.length rows in
            let padding =
              if row_count < 2 then (
                CCList.(0 --^ (2 - row_count))
                |> List.map (fun _ -> [ "" ])
              ) else (
                []
              )
            in
            rows @ padding
          )
        |> List.map (fun row ->
            List.map (fun s ->
                let full_background = Notty.I.void cell_len 1 in
                Notty.I.(strf "%s" s </> full_background)
                |> Nottui.Ui.atom
                |> Lwd.return
              ) row
          )
        |> Nottui_widgets.grid
          ~pad:(Nottui.Gravity.make ~h:`Negative ~v:`Negative)
      )
    | _ -> Lwd.return (Nottui.Ui.atom (Notty.I.void 0 0))

  let filter_bar =
    UI_base.Filter_bar.main
      ~edit_field:UI_base.Vars.filter_field
      ~focus_handle:UI_base.Vars.filter_field_focus_handle
      ~on_change:(update_filter ~commit:false)
      ~on_submit:(update_filter ~commit:true)

  let search_bar ~input_mode =
    UI_base.Search_bar.main ~input_mode
      ~edit_field:UI_base.Vars.search_field
      ~focus_handle:UI_base.Vars.search_field_focus_handle
      ~on_change:(update_search ~commit:false)
      ~on_submit:(update_search ~commit:true)

  let main ~width ~search_result_groups =
    let$* input_mode = Lwd.get UI_base.Vars.input_mode in
    Nottui_widgets.vbox
      [
        status_bar ~width ~search_result_groups ~input_mode;
        Key_binding_info.main ~input_mode;
        autocomplete_grid ~input_mode ~width;
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
    Lwd.peek UI_base.Vars.index_of_document_selected
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
    Lwd.peek UI_base.Vars.index_of_search_result_selected
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
      | (`ASCII ' ', []) -> (
          let index = Lwd.peek UI_base.Vars.index_of_document_selected in
          if index < Array.length search_result_groups then (
            let doc, _ = search_result_groups.(index) in
            toggle_mark ~path:(Document.path doc)
          );
          `Handled
        )
      | (`ASCII 'm', []) -> (
          UI_base.set_input_mode Mark;
          `Handled
        )
      | (`ASCII 'M', []) -> (
          UI_base.set_input_mode Unmark;
          `Handled
        )
      | (`ASCII 'd', []) -> (
          UI_base.set_input_mode Drop;
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
          Document_store_manager.shift_ver ~offset:(-1);
          `Handled
        )
      | (`Arrow `Right, [])
      | (`ASCII 'R', [`Ctrl])
      | (`ASCII 'Y', [`Ctrl]) -> (
          Document_store_manager.shift_ver ~offset:1;
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
      | (`ASCII '=', []) -> (
          UI_base.incr_content_view_offset ();
          `Handled
        )
      | (`ASCII '-', []) -> (
          UI_base.decr_content_view_offset ();
          `Handled
        )
      | (`Page `Down, [`Shift])
      | (`ASCII 'J', [])
      | (`Arrow `Down, [`Shift]) -> (
          UI_base.set_search_result_selected
            ~choice_count:search_result_choice_count
            (search_result_current_choice+1);
          `Handled
        )
      | (`Page `Up, [`Shift])
      | (`ASCII 'K', [])
      | (`Arrow `Up, [`Shift]) -> (
          UI_base.set_search_result_selected
            ~choice_count:search_result_choice_count
            (search_result_current_choice-1);
          `Handled
        )
      | (`Page `Down, [])
      | (`ASCII 'j', [])
      | (`Arrow `Down, []) -> (
          if document_count = 1 then (
            UI_base.set_search_result_selected
              ~choice_count:search_result_choice_count
              (search_result_current_choice+1);
            `Handled
          ) else (
            UI_base.set_document_selected
              ~choice_count:document_count
              (document_current_choice+1);
            `Handled
          )
        )
      | (`Page `Up, [])
      | (`ASCII 'k', [])
      | (`Arrow `Up, []) -> (
          if document_count = 1 then (
            UI_base.set_search_result_selected
              ~choice_count:search_result_choice_count
              (search_result_current_choice-1);
            `Handled
          ) else (
            UI_base.set_document_selected
              ~choice_count:document_count
              (document_current_choice-1);
            `Handled
          )
        )
      | (`ASCII 'g', []) -> (
          UI_base.set_document_selected
            ~choice_count:document_count
            0;
          `Handled
        )
      | (`ASCII 'G', []) -> (
          UI_base.set_document_selected
            ~choice_count:document_count
            (document_count - 1);
          `Handled
        )
      | (`ASCII 'f', []) -> (
          Nottui.Focus.request UI_base.Vars.filter_field_focus_handle;
          UI_base.set_input_mode Filter;
          `Handled
        )
      | (`ASCII '/', []) -> (
          Nottui.Focus.request UI_base.Vars.search_field_focus_handle;
          UI_base.set_input_mode Search;
          `Handled
        )
      | (`ASCII 'h', []) -> (
          Lwd.set UI_base.Vars.quit true;
          UI_base.Vars.action := Some UI_base.Edit_command_history;
          `Handled
        )
      | (`ASCII 'S', [`Ctrl]) -> (
          UI_base.set_input_mode Save_script;
          File_utils.list_files_recursive_filter_by_exts
            ~max_depth:1
            ~report_progress:(fun () -> ())
            ~exts:[ Params.docfd_script_ext ]
            (Seq.return (Params.script_dir ()))
          |> String_set.to_seq
          |> Seq.map Filename.basename
          |> Dynarray.of_seq
          |> Lwd.set Vars.script_files;
          Nottui.Focus.request Vars.save_script_field_focus_handle;
          `Handled
        )
      | (`ASCII 'O', [`Ctrl]) -> (
          Lwd.set UI_base.Vars.quit true;
          UI_base.Vars.action := Some UI_base.Select_and_load_script;
          `Handled
        )
      | (`ASCII 'x', []) -> (
          UI_base.set_input_mode Clear;
          `Handled
        )
      | (`ASCII 's', []) -> (
          UI_base.set_input_mode (Sort `Asc);
          `Handled
        )
      | (`ASCII 'S', []) -> (
          UI_base.set_input_mode (Sort `Desc);
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
  | Sort order -> (
      let exit =
        match key with
        | (`Escape, []) -> true
        | (`ASCII 's', []) -> (
            Lwd.set Vars.sort_by (`Score, order);
            true
          )
        | (`ASCII 'p', []) -> (
            Lwd.set Vars.sort_by (`Path, order);
            true
          )
        | (`ASCII 'd', []) -> (
            Lwd.set Vars.sort_by (`Path_date, order);
            true
          )
        | (`ASCII 'm', []) -> (
            Lwd.set Vars.sort_by (`Mod_time, order);
            true
          )
        | _ -> false
      in
      if exit then (
        UI_base.set_input_mode Navigate;
      );
      `Handled
    )
  | Clear -> (
      let exit =
        match key with
        | (`Escape, []) -> true
        | (`ASCII '/', []) -> (
            Lwd.set UI_base.Vars.search_field UI_base.empty_text_field;
            update_search ~commit:true ();
            true
          )
        | (`ASCII 'f', []) -> (
            Lwd.set UI_base.Vars.filter_field UI_base.empty_text_field;
            update_filter ~commit:true ();
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
  | Mark -> (
      let exit =
        match key with
        | (`Escape, []) -> true
        | (`ASCII '?', []) -> (
            UI_base.Key_binding_info.incr_rotation ();
            false
          )
        | (`ASCII 'l', []) -> (
            mark `Listed;
            true
          )
        | _ -> false
      in
      if exit then (
        UI_base.set_input_mode Navigate;
      );
      `Handled
    )
  | Unmark -> (
      let exit =
        match key with
        | (`Escape, []) -> true
        | (`ASCII '?', []) -> (
            UI_base.Key_binding_info.incr_rotation ();
            false
          )
        | (`ASCII 'l', []) -> (
            unmark `Listed;
            true
          )
        | (`ASCII 'a', []) -> (
            unmark `All;
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
            search_result_groups
            |> Array.to_seq
            |> Seq.filter (fun (doc, _) ->
                String_set.mem (Document.path doc) marked)
            |> copy_search_result_groups;
            true
          )
        | (`ASCII 'l', []) -> (
            search_result_groups
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
             UI_base.reset_document_selected ();
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
  | Save_script_overwrite -> (
      (match key with
       | (`Escape, [])
       | (`ASCII 'n', []) -> (
           UI_base.set_input_mode Navigate;
         )
       | (`ASCII 'y', []) -> (
           let path = compute_save_script_path () in
           save_script ~path;
           UI_base.set_input_mode Save_script_edit;
         )
       | _ -> ()
      );
      `Handled
    )
  | Save_script_no_name -> (
      let exit =
        (match key with
         | (`Enter, []) -> true
         | _ -> false
        );
      in
      if exit then (
        UI_base.set_input_mode Navigate;
      );
      `Handled
    )
  | Save_script_edit -> (
      let exit =
        (match key with
         | (`Escape, [])
         | (`ASCII 'n', []) -> true
         | (`ASCII 'y', []) -> (
             let path = compute_save_script_path () in
             Lwd.set UI_base.Vars.quit true;
             UI_base.Vars.action := Some (UI_base.Edit_script path);
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
  let$* (_, snapshot) =
    Document_store_manager.cur_snapshot
  in
  let document_store =
    Document_store_snapshot.store snapshot
  in
  let$* search_result_groups = Vars.search_result_groups in
  let document_count = Array.length search_result_groups in
  UI_base.set_document_selected
    ~choice_count:document_count
    (Lwd.peek UI_base.Vars.index_of_document_selected);
  if document_count > 0 then (
    UI_base.set_search_result_selected
      ~choice_count:(Array.length
                       (snd search_result_groups.(Lwd.peek UI_base.Vars.index_of_document_selected)))
      (Lwd.peek UI_base.Vars.index_of_search_result_selected)
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
