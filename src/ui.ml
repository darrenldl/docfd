type input_mode =
  | Navigate
  | Search

type ui_mode =
  | Ui_single_file
  | Ui_multi_file

type document_src =
  | Stdin
  | Files of string list

let empty_search_field = ("", 0)

module Vars = struct
  let quit = Lwd.var false

  let index_of_document_selected = Lwd.var 0

  module Multi_file = struct
    let index_of_search_result_selected = Lwd.var 0

    let search_field = Lwd.var empty_search_field

    let search_constraints =
      Lwd.var (Search_constraints.make
                 ~fuzzy_max_edit_distance:0
                 ~phrase:"")

    let focus_handle = Nottui.Focus.make ()
  end

  module Single_file = struct
    let index_of_search_result_selected = Lwd.var 0

    let search_field = Lwd.var empty_search_field

    (* let search_constraints =
      Lwd.var (Search_constraints.make
                 ~fuzzy_max_edit_distance:0
                 ~phrase:"") *)

    let focus_handle = Nottui.Focus.make ()

    let search_results : Search_result.t array Lwd.var = Lwd.var [||]
  end

  let file_to_open : Document.t option ref = ref None

  let input_mode : input_mode Lwd.var = Lwd.var Navigate

  let init_ui_mode : ui_mode ref = ref Ui_multi_file

  let ui_mode : ui_mode Lwd.var = Lwd.var Ui_multi_file

  let all_documents : Document.t list Lwd.var = Lwd.var []

  let document_src : document_src ref = ref (Files [])

  let term : Notty_unix.Term.t ref = ref (Notty_unix.Term.create ())
end

let full_term_sized_background () =
  let (term_width, term_height) = Notty_unix.Term.size !Vars.term in
  Notty.I.void term_width term_height
  |> Nottui.Ui.atom

let total_document_count =
  Lwd.map ~f:List.length (Lwd.get Vars.all_documents)

let documents =
  Lwd.map2
    ~f:(fun all_documents search_constraints ->
        all_documents
        |> List.filter_map (fun doc ->
            if Search_constraints.is_empty search_constraints then
              Some doc
            else (
              match Document.search search_constraints doc () with
              | Seq.Nil -> None
              | Seq.Cons _ as s ->
                let search_results = (fun () -> s)
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
    (Lwd.get Vars.all_documents)
    (Lwd.get Vars.Multi_file.search_constraints)

let document_selected : Document.t option Lwd.t =
  Lwd.map ~f:(fun (documents, index) ->
      if Array.length documents = 0 then
        None
      else
        Some documents.(index)
    )
    Lwd.(pair
           documents
           (get Vars.index_of_document_selected))

let bound_selection ~choice_count (x : int) : int =
  max 0 (min (choice_count - 1) x)

module Multi_file = struct
  let set_document_selected ~choice_count n =
    let n = bound_selection ~choice_count n in
    Lwd.set Vars.index_of_document_selected n;
    Lwd.set Vars.Multi_file.index_of_search_result_selected 0

  let reset_document_selected () =
    Lwd.set Vars.index_of_document_selected 0;
    Lwd.set Vars.Multi_file.index_of_search_result_selected 0

  let set_search_result_selected ~choice_count n =
    let n = bound_selection ~choice_count n in
    Lwd.set Vars.Multi_file.index_of_search_result_selected n

  let update_search_constraints () =
    reset_document_selected ();
    Lwd.set Vars.Multi_file.search_constraints
      (Search_constraints.make
         ~fuzzy_max_edit_distance:!Params.max_fuzzy_edit_distance
         ~phrase:(fst @@ Lwd.peek Vars.Multi_file.search_field)
      )
end

module Single_file = struct
  let set_search_result_selected ~choice_count n =
    let n = bound_selection ~choice_count n in
    Lwd.set Vars.Single_file.index_of_search_result_selected n

  let reset_search_result_selected () =
    Lwd.set Vars.Single_file.index_of_search_result_selected 0

  let update_search_constraints ~document () =
    reset_search_result_selected ();
    let search_constraints =
      Search_constraints.make
         ~fuzzy_max_edit_distance:!Params.max_fuzzy_edit_distance
         ~phrase:(fst @@ Lwd.peek Vars.Single_file.search_field)
    in
    let results = Document.search search_constraints document
        |> OSeq.take Params.search_result_limit
                                     |> Array.of_seq
    in
                Array.sort Search_result.compare results;
                Lwd.set Vars.Single_file.search_results results
end

module Document_list = struct
  let mouse_handler
      documents
      ~x ~y
      (button : Notty.Unescape.button)
    =
    let _ = x in
    let _ = y in
    let choice_count = Array.length documents in
    let current_choice =
      Lwd.peek Vars.index_of_document_selected
    in
    match button with
    | `Scroll `Down ->
      Multi_file.set_document_selected
        ~choice_count (current_choice+1);
      `Handled
    | `Scroll `Up ->
      Multi_file.set_document_selected
        ~choice_count (current_choice-1);
      `Handled
    | _ -> `Unhandled

  let main =
    Lwd.map2 ~f:(fun documents i ->
        let image_count = Array.length documents in
        let pane =
          if Array.length documents = 0 then (
            Nottui.Ui.empty
          ) else (
            let (images_selected, images_unselected) =
              Render.documents documents
            in
            let (_term_width, term_height) = Notty_unix.Term.size !Vars.term in
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
        |> Nottui.Ui.mouse_area (mouse_handler documents)
      )
      documents
      (Lwd.get Vars.index_of_document_selected)
end

module Content_view = struct
  let main =
    Lwd.map ~f:(fun (ui_mode, document) ->
        match document with
        | None -> Nottui.Ui.empty
        | Some document -> (
            let (_term_width, term_height) = Notty_unix.Term.size !Vars.term in
            let render_seq s =
              s
              |> OSeq.take term_height
              |> Seq.map Misc_utils.sanitize_string_for_printing
              |> Seq.map (fun s -> Nottui.Ui.atom Notty.(I.string A.empty s))
              |> List.of_seq
              |> Nottui.Ui.vcat
            in
            let content =
              Index.lines document.index
              |> render_seq
            in
            content
          )
      )
      Lwd.(pair
             (get Vars.ui_mode)
             document_selected)
end

module Search_result_list = struct
  let mouse_handler
      ~choice_count
      ~current_choice
      ~x ~y
      (button : Notty.Unescape.button)
    =
    let _ = x in
    let _ = y in
    match button with
    | `Scroll `Down -> (
        (match Lwd.peek Vars.ui_mode with
         | Ui_single_file ->
           Single_file.set_search_result_selected
             ~choice_count
             (current_choice + 1)
         | Ui_multi_file ->
           Multi_file.set_search_result_selected
             ~choice_count
             (current_choice + 1)
        );
        `Handled
      )
    | `Scroll `Up -> (
        (match Lwd.peek Vars.ui_mode with
         | Ui_single_file ->
           Single_file.set_search_result_selected
             ~choice_count
             (current_choice - 1)
         | Ui_multi_file ->
           Multi_file.set_search_result_selected
             ~choice_count
             (current_choice - 1)
        );
        `Handled
      )
    | _ -> `Unhandled

  type params = {
    ui_mode : ui_mode;
    document : Document.t;
    search_results : Search_result.t array;
    result_selected : int;
  }

  let params : params option Lwd.t =
    Lwd.map
      ~f:(fun (ui_mode,
               (document,
               (sf_search_results,
                (mf_result_selected, sf_result_selected)))) ->
           match document with
           | None -> None
           | Some document ->
             match ui_mode with
             | Ui_single_file ->
               Some
                 {
                   ui_mode;
                   document;
                   search_results = sf_search_results;
                   result_selected = sf_result_selected;
                 }
             | Ui_multi_file ->
               Some
                 {
                   ui_mode;
                   document;
                   search_results = document.search_results;
                   result_selected = mf_result_selected;
                 }
         )
      Lwd.(pair
             (get Vars.ui_mode)
             (pair
                document_selected
                (pair
                (get Vars.Single_file.search_results)
                (pair
                   (get Vars.Multi_file.index_of_search_result_selected)
                   (get Vars.Single_file.index_of_search_result_selected)))))

  let main =
    Lwd.map ~f:(fun params ->
        match params with
        | None -> Nottui.Ui.empty
        | Some { ui_mode = _; document; search_results; result_selected } -> (
            let result_count = Array.length search_results in
            if result_count = 0 then (
              Nottui.Ui.empty
            ) else (
              let (_term_width, term_height) = Notty_unix.Term.size !Vars.term in
              let images =
                Render.search_results
                  ~start:result_selected
                  ~end_exc:(min (result_selected + term_height / 2) result_count)
                  document.index
                  search_results
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
                (mouse_handler
                   ~choice_count:result_count
                   ~current_choice:result_selected)
            )
          )
      )
      params
end

module Status_bar = struct
  let main =
    let fg_color = Notty.A.black in
    let bg_color = Notty.A.white in
    let background_bar () =
      let (term_width, _term_height) = Notty_unix.Term.size !Vars.term in
      Notty.I.char Notty.A.(bg bg_color) ' ' term_width 1
      |> Nottui.Ui.atom
    in
    let element_spacing = 4 in
    let element_spacer =
      Notty.(I.string
               A.(bg bg_color ++ fg fg_color))
        (String.make element_spacing ' ')
    in
    let input_mode_strings =
      [ (Navigate, "NAVIGATE")
      ; (Search, "SEARCH")
      ]
    in
    let max_input_mode_string_len =
      List.fold_left (fun acc (_, s) ->
          max acc (String.length s)
        )
        0
        input_mode_strings
    in
    let input_mode_string_background =
      Notty.I.char Notty.A.(bg bg_color) ' ' max_input_mode_string_len 1
    in
    let input_mode_strings =
      List.map (fun (mode, s) ->
          let s = Notty.(I.string A.(bg bg_color ++ fg fg_color ++ st bold) s) in
          (mode, Notty.I.(s </> input_mode_string_background))
        )
        input_mode_strings
    in
    Lwd.map
       ~f:(fun (total_document_count,
                (documents,
                 (ui_mode,
                  (input_mode, (index_of_document_selected, document_selected))))) ->
            let file_shown_count =
              Notty.I.strf ~attr:Notty.A.(bg bg_color ++ fg fg_color)
                "%5d/%d documents listed"
                (Array.length documents) total_document_count
            in
            let index_of_selected =
              match document_selected with
              | None -> Notty.I.void 0 0
              | Some _ ->
                Notty.I.strf ~attr:Notty.A.(bg bg_color ++ fg fg_color)
                  "index of document selected: %d"
                  index_of_document_selected
            in
            let path_of_selected =
              match document_selected with
              | None -> Notty.I.void 0 0
              | Some document_selected ->
                Notty.I.strf ~attr:Notty.A.(bg bg_color ++ fg fg_color)
                  "document selected: %s"
                  (match document_selected.path with
                   | Some s -> s
                   | None -> "<stdin>")
            in
            let content =
              [ Some [ List.assoc input_mode input_mode_strings ]
              ; Some [ element_spacer; file_shown_count ]
              ; (match ui_mode with
                 | Ui_single_file ->
                   Some [ element_spacer; path_of_selected ]
                 | Ui_multi_file ->
                   Some [ element_spacer; index_of_selected ]
                )
              ]
              |> List.filter_map Fun.id
              |> List.flatten
              |> Notty.I.hcat
              |> Nottui.Ui.atom
            in
            Nottui.Ui.join_z (background_bar ()) content
          )
       Lwd.(
         (pair
            total_document_count
            (pair
               documents
               (pair
                  (get Vars.ui_mode)
                  (pair
                     (get Vars.input_mode)
                     (pair
                        (get Vars.index_of_document_selected)
                        document_selected))))))
end

module Key_binding_info = struct
  type key_msg = {
    key : string;
    msg : string;
  }

  type key_msg_line = key_msg list

  let main () =
    let grid_contents
      : ((input_mode * ui_mode) * (key_msg_line list)) list =
      let navigate_line0 : key_msg_line =
        [
          { key = "Enter"; msg = "open document" };
          { key = "/"; msg = "switch to search mode" };
          { key = "x"; msg = "clear search" };
        ]
      in
      let search_lines =
        [
          [
            { key = "Enter"; msg = "confirm and exit search mode" };
          ];
          [
            { key = ""; msg = "" };
          ];
        ]
      in
      [
        ((Navigate, Ui_single_file),
         (match !Vars.init_ui_mode with
          | Ui_single_file ->
            [
              navigate_line0;
              [
                { key = "Tab";
                  msg = "switch to multi file view" };
                { key = "q"; msg = "exit" };
              ];
            ]
          | Ui_multi_file ->
            [
              navigate_line0;
              [
                { key = "Tab";
                  msg = "switch to multi file view" };
                { key = "q"; msg = "exit" };
              ];
            ]
         )
        );
        ((Navigate, Ui_multi_file),
         [
           navigate_line0;
           [
             { key = "Tab";
               msg = "switch to single file view" };
             { key = "q"; msg = "exit" };
           ];
         ]
        );
        ((Search, Ui_single_file), search_lines);
        ((Search, Ui_multi_file), search_lines);
      ]
    in
    (*let grid_height =
      grid_contents
      |> List.hd
      |> snd
      |> List.length
      in*)
    let max_key_msg_len_lookup =
      grid_contents
      |> List.map (fun (mode, grid) ->
          let max_key_len, max_msg_len =
            List.fold_left (fun (max_key_len, max_msg_len) row ->
                List.fold_left (fun (max_key_len, max_msg_len) { key; msg } ->
                    (max max_key_len (String.length key),
                     max max_msg_len (String.length msg))
                  )
                  (max_key_len, max_msg_len)
                  row
              )
              (0, 0)
              grid
          in
          (mode, (max_key_len, max_msg_len))
        )
    in
    let key_msg_pair modes { key; msg } : Nottui.ui Lwd.t =
      let (max_key_len, max_msg_len) =
        List.assoc modes max_key_msg_len_lookup
      in
      let key_attr = Notty.A.(fg lightyellow ++ st bold) in
      let msg_attr = Notty.A.empty in
      let msg = String.capitalize_ascii msg in
      let key_background = Notty.I.void max_key_len 1 in
      let content = Notty.(I.hcat
                             [ I.(string key_attr key </> key_background)
                             ; I.string A.empty "  "
                             ; I.string msg_attr msg
                             ]
                          )
      in
      let full_background =
        Notty.I.void (max_key_len + 2 + max_msg_len + 2) 1
      in
      Notty.I.(content </> full_background)
      |> Nottui.Ui.atom
      |> Lwd.return
    in
    let grid =
      List.map (fun (modes, grid_contents) ->
          (modes,
           grid_contents
           |> List.map (fun l ->
               List.map (key_msg_pair modes) l
             )
           |> Nottui_widgets.grid
             ~pad:(Nottui.Gravity.make ~h:`Negative ~v:`Negative)
          )
        )
        grid_contents
    in
    let grid =
      Lwd.map ~f:(fun (input_mode, ui_mode) ->
          List.assoc (input_mode, ui_mode) grid)
        Lwd.(pair
               (Lwd.get Vars.input_mode)
               (Lwd.get Vars.ui_mode))
    in
    Lwd.join grid
end

module Search_bar = struct
  let search_label_str = "Search:"

  let label_strs =
    [ search_label_str ]

  let max_label_len =
    List.fold_left (fun x s ->
        max x (String.length s))
      0
      label_strs

  let label_widget_len = max_label_len + 1

  let make_label_widget ~s ~len ~(style_on_mode : input_mode) (v : input_mode Lwd.var) =
    Lwd.map ~f:(fun mode' ->
        (if style_on_mode = mode' then
           Notty.(I.string A.(st bold) s)
         else
           Notty.(I.string A.empty s))
        |> Notty.I.hsnap ~align:`Left len
        |> Nottui.Ui.atom
      ) (Lwd.get v)

  let search_label =
    make_label_widget
      ~s:search_label_str
      ~len:label_widget_len
      ~style_on_mode:Search
      Vars.input_mode

  let make_search_field ~edit_field ~focus_handle ~f =
    Nottui_widgets.edit_field (Lwd.get edit_field)
      ~focus:focus_handle
      ~on_change:(fun (text, x) -> Lwd.set edit_field (text, x))
      ~on_submit:(fun _ ->
          f ();
          Nottui.Focus.release focus_handle;
          Lwd.set Vars.input_mode Navigate
        )

  let main : Nottui.ui Lwd.t =
    Lwd.map ~f:(fun (ui_mode, document) ->
    Nottui_widgets.hbox
      [
        search_label;
        (match document with
        | None -> Lwd.return Nottui.Ui.empty
        | Some document -> (
          match ui_mode with
        | Ui_multi_file ->
            make_search_field
          ~edit_field:Vars.Multi_file.search_field
          ~focus_handle:Vars.Multi_file.focus_handle
          ~f:Multi_file.update_search_constraints
        | Ui_single_file ->
            make_search_field
          ~edit_field:Vars.Single_file.search_field
          ~focus_handle:Vars.Single_file.focus_handle
          ~f:(Single_file.update_search_constraints ~document)
        )
        );
      ]
    )
    Lwd.(pair (get Vars.ui_mode) document_selected)
        |> Lwd.join
end

let keyboard_handler
    ~document_choice_count
    (document : Document.t option)
    (key : Nottui.Ui.key)
  =
  let document_current_choice = Lwd.peek Vars.index_of_document_selected in
  let mf_search_result_choice_count =
    match document with
    | None -> 0
    | Some document ->
      Array.length document.search_results
  in
  let sf_search_result_choice_count =
    Array.length (Lwd.peek Vars.Single_file.search_results)
  in
  let mf_search_result_current_choice =
    Lwd.peek Vars.Multi_file.index_of_search_result_selected
  in
  let sf_search_result_current_choice =
    Lwd.peek Vars.Single_file.index_of_search_result_selected
  in
  match Lwd.peek Vars.input_mode with
  | Navigate -> (
      match key, Lwd.peek Vars.ui_mode with
      | ((`Escape, []), _)
      | ((`ASCII 'q', []), _)
      | ((`ASCII 'C', [`Ctrl]), _) -> (
          Lwd.set Vars.quit true;
          `Handled
        )
      | ((`Tab, []), _) -> (
          (match !Vars.init_ui_mode with
           | Ui_multi_file -> (
               match Lwd.peek Vars.ui_mode with
               | Ui_multi_file -> (
                 Option.iter
                 (fun document ->
                   Lwd.set
                   Vars.Single_file.search_field
                   (Lwd.peek Vars.Multi_file.search_field);
                   Lwd.set
                   Vars.Single_file.search_results
                   (Array.copy document.Document.search_results);
                   )
                 document;
                 Lwd.set Vars.ui_mode Ui_single_file
               )
               | Ui_single_file -> Lwd.set Vars.ui_mode Ui_multi_file
             )
           | Ui_single_file -> ()
          );
          `Handled
        )
      | ((`ASCII 'j', []), Ui_multi_file)
      | ((`Arrow `Down, []), Ui_multi_file) -> (
          Multi_file.set_document_selected
            ~choice_count:document_choice_count
            (document_current_choice+1);
          `Handled
        )
      | ((`ASCII 'k', []), Ui_multi_file)
      | ((`Arrow `Up, []), Ui_multi_file) -> (
          Multi_file.set_document_selected
            ~choice_count:document_choice_count
            (document_current_choice-1);
          `Handled
        )
      | ((`ASCII 'J', []), Ui_multi_file)
      | ((`Arrow `Down, [`Shift]), Ui_multi_file) -> (
          Multi_file.set_search_result_selected
            ~choice_count:mf_search_result_choice_count
            (mf_search_result_current_choice+1);
          `Handled
        )
      | ((`ASCII 'J', []), Ui_single_file)
      | ((`Arrow `Down, [`Shift]), Ui_single_file)
      | ((`ASCII 'j', []), Ui_single_file)
      | ((`Arrow `Down, []), Ui_single_file) -> (
          Single_file.set_search_result_selected
            ~choice_count:sf_search_result_choice_count
            (sf_search_result_current_choice+1);
          `Handled
        )
      | ((`ASCII 'K', []), Ui_multi_file)
      | ((`Arrow `Up, [`Shift]), Ui_multi_file) -> (
          Multi_file.set_search_result_selected
            ~choice_count:mf_search_result_choice_count
            (mf_search_result_current_choice-1);
          `Handled
        )
      | ((`ASCII 'K', []), Ui_single_file)
      | ((`Arrow `Up, [`Shift]), Ui_single_file)
      | ((`ASCII 'k', []), Ui_single_file)
      | ((`Arrow `Up, []), Ui_single_file) -> (
          Single_file.set_search_result_selected
            ~choice_count:sf_search_result_choice_count
            (sf_search_result_current_choice-1);
          `Handled
        )
      | ((`ASCII '/', []), Ui_single_file) -> (
        Nottui.Focus.request Vars.Single_file.focus_handle;
        Lwd.set Vars.input_mode Search;
        `Handled
      )
      | ((`ASCII '/', []), Ui_multi_file) -> (
        Nottui.Focus.request Vars.Multi_file.focus_handle;
        Lwd.set Vars.input_mode Search;
        `Handled
      )
      | ((`ASCII 'x', []), Ui_single_file) -> (
        Lwd.set Vars.Single_file.search_field empty_search_field;
        Single_file.update_search_constraints ~document:(Option.get document) ();
        `Handled
      )
      | ((`ASCII 'x', []), Ui_multi_file) -> (
        Lwd.set Vars.Multi_file.search_field empty_search_field;
        Multi_file.update_search_constraints ();
        `Handled
      )
      | ((`Enter, []), _) -> (
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
