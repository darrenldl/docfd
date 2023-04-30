module Vars = struct
  let index_of_document_selected = Lwd.var 0

  let index_of_search_result_selected = Lwd.var 0

  let search_field = Lwd.var Ui_base.empty_search_field

  let search_constraints =
    Lwd.var (Search_constraints.make
               ~fuzzy_max_edit_distance:0
               ~phrase:"")

  let search_field_focus_handle = Nottui.Focus.make ()
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

let update_search_constraints () =
  reset_document_selected ();
  Lwd.set Vars.search_constraints
    (Search_constraints.make
       ~fuzzy_max_edit_distance:!Params.max_fuzzy_edit_distance
       ~phrase:(fst @@ Lwd.peek Vars.search_field)
    )

let documents =
  Lwd.map
    ~f:(fun search_constraints ->
        !Ui_base.Vars.all_documents
        |> List.filter_map (fun doc ->
            if Search_constraints.is_empty search_constraints then
              Some doc
            else (
              match Document.search search_constraints doc () with
              | Seq.Nil -> None
              | Seq.Cons _ as s ->
                let search_results =
                  (fun () -> s)
                  |> OSeq.take Params.search_result_limit
                  |> Array.of_seq
                in
                Array.sort Search_result.compare search_results;
                Some { doc with search_results }
            )
          )
        |> (fun l ->
            if Search_constraints.is_empty search_constraints then
              l
            else
              List.sort (fun (doc1 : Document.t) (doc2 : Document.t) ->
                  Search_result.compare
                    (doc1.search_results.(0))
                    (doc2.search_results.(0))
                ) l
          )
        |> Array.of_list
      )
    (Lwd.get Vars.search_constraints)

module Top_pane = struct
  module Document_list = struct
    let render_document_previews
        (documents : Document.t array)
      : Notty.image array * Notty.image array =
      let images_selected : Notty.image list ref = ref [] in
      let images_unselected : Notty.image list ref = ref [] in
      Array.iter (fun (doc : Document.t) ->
          let open Notty in
          let open Notty.Infix in
          let search_result_score_image =
            if !Params.debug then
              if Array.length doc.search_results = 0 then
                I.empty
              else
                let x = doc.search_results.(0) in
                I.strf "(best content search result score: %f)" (Search_result.score x)
            else
              I.empty
          in
          let preview_line_images =
            let line_count =
              min Params.preview_line_count (Index.line_count doc.index)
            in
            OSeq.(0 --^ line_count)
            |> Seq.map (fun line_num -> Index.line_of_line_num line_num doc.index)
            |> Seq.map (fun line ->
                (I.string A.(bg lightgreen) " ")
                <|>
                (I.strf " %s" (Misc_utils.sanitize_string_for_printing line))
              )
            |> List.of_seq
          in
          let preview_image =
            I.vcat preview_line_images
          in
          let path_image =
            I.string A.(fg lightgreen) "@ "
            <|>
            I.string A.empty
              (Option.value ~default:Params.stdin_doc_path_placeholder doc.path);
          in
          let title =
            Option.value ~default:"" doc.title
            |> Misc_utils.sanitize_string_for_printing
          in
          let img_selected =
            (I.string A.(fg lightblue ++ st bold) title)
            <->
            (I.string A.empty "  "
             <|>
             I.vcat
               [ search_result_score_image;
                 path_image;
                 preview_image;
               ]
            )
          in
          let img_unselected =
            (I.string A.(fg lightblue) title)
            <->
            (I.string A.empty "  "
             <|>
             I.vcat
               [ search_result_score_image;
                 path_image;
                 preview_image;
               ]
            )
          in
          images_selected := img_selected :: !images_selected;
          images_unselected := img_unselected :: !images_unselected
        ) documents;
      let images_selected = Array.of_list (List.rev !images_selected) in
      let images_unselected = Array.of_list (List.rev !images_unselected) in
      (images_selected, images_unselected)

    let main ~documents =
      let document_count = Array.length documents in
      Lwd.map ~f:(fun document_selected ->
          let pane =
            if document_count = 0 then (
              Nottui.Ui.empty
            ) else (
              let (images_selected, images_unselected) =
                render_document_previews documents
              in
              let (_term_width, term_height) = Notty_unix.Term.size (Ui_base.get_term ()) in
              CCInt.range'
                document_selected
                (min (document_selected + term_height / 2) document_count)
              |> CCList.of_iter
              |> List.map (fun j ->
                  if Int.equal document_selected j then
                    images_selected.(j)
                  else
                    images_unselected.(j)
                )
              |> List.map Nottui.Ui.atom
              |> Nottui.Ui.vcat
            )
          in
          Nottui.Ui.join_z (Ui_base.full_term_sized_background ()) pane
          |> Nottui.Ui.mouse_area
            (Ui_base.mouse_handler
               ~choice_count:document_count
               ~current_choice:Vars.index_of_document_selected)
        )
        (Lwd.get Vars.index_of_document_selected)
  end

  module Right_pane = struct
    let main
        ~(documents : Document.t array)
        ~(document_selected : int)
      : Nottui.ui Lwd.t =
      if Array.length documents = 0 then
        Nottui_widgets.(v_pane empty_lwd empty_lwd)
      else (
        Lwd.map ~f:(fun search_result_selected ->
            let document = documents.(document_selected) in
            Nottui_widgets.v_pane
              (Ui_base.Content_view.main ~document ~search_result_selected)
              (Ui_base.Search_result_list.main
                 ~document
                 ~index_of_search_result_selected:Vars.index_of_search_result_selected)
          )
          (Lwd.get Vars.index_of_search_result_selected)
        |> Lwd.join
      )
  end

  let main
      ~(documents : Document.t array)
    : Nottui.ui Lwd.t =
    Lwd.map ~f:(fun document_selected ->
        Nottui_widgets.h_pane
          (Document_list.main ~documents)
          (Right_pane.main ~documents ~document_selected)
      )
      (Lwd.get Vars.index_of_document_selected)
    |> Lwd.join
end

module Bottom_pane = struct
  let status_bar ~documents ~(input_mode : Ui_base.input_mode) =
    Lwd.map ~f:(fun index_of_document_selected ->
        let document_count = Array.length documents in
        let input_mode_image =
          List.assoc input_mode Ui_base.Status_bar.input_mode_images
        in
        let content =
          if document_count = 0 then
            Nottui.Ui.atom input_mode_image
          else (
            let file_shown_count =
              Notty.I.strf ~attr:Ui_base.Status_bar.attr
                "%5d/%d documents listed"
                document_count !Ui_base.Vars.total_document_count
            in
            let index_of_selected =
              Notty.I.strf ~attr:Ui_base.Status_bar.attr
                "index of document selected: %d"
                index_of_document_selected
            in
            Notty.I.hcat
              [
                List.assoc input_mode Ui_base.Status_bar.input_mode_images;
                Ui_base.Status_bar.element_spacer;
                file_shown_count;
                Ui_base.Status_bar.element_spacer;
                index_of_selected;
              ]
            |> Nottui.Ui.atom
          )
        in
        Nottui.Ui.join_z (Ui_base.Status_bar.background_bar ()) content
      )
      (Lwd.get Vars.index_of_document_selected)

  module Key_binding_info = struct
    let grid_contents : Ui_base.Key_binding_info.grid_contents =
      let open Ui_base.Key_binding_info in
      let navigate_grid =
        [
          [
            { label = "Enter"; msg = "open document" };
            { label = "/"; msg = "switch to search mode" };
            { label = "x"; msg = "clear search" };
          ];
          [
            { label = "Tab";
              msg = "switch to single file view" };
            { label = "q"; msg = "exit" };
          ];
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
      ]

    let grid_lookup = Ui_base.Key_binding_info.make_grid_lookup grid_contents

    let main ~input_mode =
      Ui_base.Key_binding_info.main ~grid_lookup ~input_mode
  end

  let search_bar ~input_mode =
    Ui_base.Search_bar.main ~input_mode
      ~edit_field:Vars.search_field
      ~focus_handle:Vars.search_field_focus_handle
      ~f:update_search_constraints

  let main ~documents =
    Lwd.map ~f:(fun input_mode ->
        Nottui_widgets.vbox
          [
            status_bar ~documents ~input_mode;
            Key_binding_info.main ~input_mode;
            search_bar ~input_mode;
          ]
      )
      (Lwd.get Ui_base.Vars.input_mode)
    |> Lwd.join
end

let keyboard_handler
    ~(documents : Document.t array)
    (key : Nottui.Ui.key)
  =
  let document_choice_count =
    Array.length documents
  in
  let document_current_choice =
    Lwd.peek Vars.index_of_document_selected
  in
  let document_selected =
    if document_choice_count = 0 then
      None
    else
      Some documents.(document_current_choice)
  in
  let search_result_choice_count =
    if document_choice_count = 0 then
      0
    else
      Array.length documents.(document_current_choice).search_results
  in
  let search_result_current_choice =
    Lwd.peek Vars.index_of_search_result_selected
  in
  match Lwd.peek Ui_base.Vars.input_mode with
  | Navigate -> (
      match key with
      | (`Escape, [])
      | (`ASCII 'q', [])
      | (`ASCII 'C', [`Ctrl]) -> (
          Ui_base.Vars.file_to_open := None;
          Lwd.set Ui_base.Vars.quit true;
          `Handled
        )
      | (`Tab, []) -> (
          Option.iter (fun document_selected ->
              Lwd.set Ui_base.Vars.document_selected document_selected;
              Lwd.set Ui_base.Vars.Single_file.index_of_search_result_selected
                (Lwd.peek Vars.index_of_search_result_selected);
              Lwd.set Ui_base.Vars.Single_file.search_field
                (Lwd.peek Vars.search_field);
              Lwd.set Ui_base.Vars.ui_mode Ui_single_file;
            )
            document_selected;
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
            ~choice_count:document_choice_count
            (document_current_choice+1);
          `Handled
        )
      | (`Page `Up, [])
      | (`ASCII 'k', [])
      | (`Arrow `Up, []) -> (
          set_document_selected
            ~choice_count:document_choice_count
            (document_current_choice-1);
          `Handled
        )
      | (`ASCII '/', []) -> (
          Nottui.Focus.request Vars.search_field_focus_handle;
          Lwd.set Ui_base.Vars.input_mode Search;
          `Handled
        )
      | (`ASCII 'x', []) -> (
          Lwd.set Vars.search_field Ui_base.empty_search_field;
          update_search_constraints ();
          `Handled
        )
      | (`Enter, []) -> (
          Option.iter (fun document_selected ->
              match document_selected.Document.path with
              | None -> ()
              | Some _ -> (
                  Ui_base.Vars.file_to_open := Some document_selected;
                  Lwd.set Ui_base.Vars.quit true;
                )
            )
            document_selected;
          `Handled
        )
      | _ -> `Handled
    )
  | Search -> `Unhandled

let main : Nottui.ui Lwd.t =
  Lwd.map ~f:(fun documents ->
      Nottui_widgets.vbox
        [
          Lwd.map
            ~f:(Nottui.Ui.keyboard_area (keyboard_handler ~documents))
            (Top_pane.main ~documents);
          Bottom_pane.main ~documents;
        ]
    )
    documents
  |> Lwd.join
