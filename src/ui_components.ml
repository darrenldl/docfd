type input_mode =
  | Navigate
  | Search

type ui_mode =
  | Ui_single_file
  | Ui_multi_file

type document_src =
  | Stdin
  | Files of string list

type ctx = {
  term : Notty_unix.Term.t;
  fuzzy_max_edit_distance : int;
  document_src : document_src;
  input_mode : input_mode;
  init_ui_mode : ui_mode;
  ui_mode : ui_mode;
  all_documents : Document.t array;
  documents : Document.t array;
  document_selected : int;
  content_search_result_selected : int;
  content_search_focus_handle : Nottui.Focus.handle;
  content_search_field : (string * int) Lwd.var;
  content_search_constraints : Content_search_constraints.t;
  file_to_open : Document.t option;
  quit : bool Lwd.var;
}

let empty_search_field = ("", 0)

let bound_selection ~choice_count (x : int) : int =
  max 0 (min (choice_count - 1) x)

let set_document_selected
    (ctx' : ctx Lwd.var)
    n
  =
  let ctx = Lwd.peek ctx' in
  let choice_count = Array.length ctx.documents in
  let document_selected = bound_selection ~choice_count n in
  Lwd.set ctx'
    { ctx with
      document_selected;
      content_search_result_selected = 0;
    }

let set_content_search_result_selected
    (ctx' : ctx Lwd.var)
    n
  =
  let ctx = Lwd.peek ctx' in
  let doc = ctx.documents.(ctx.document_selected) in
  let choice_count = Array.length doc.content_search_results in
  let document_selected = bound_selection ~choice_count n in
  Lwd.set ctx'
    { ctx with
      document_selected;
      content_search_result_selected = 0;
    }

let update_content_search_constraints
    (ctx' : ctx Lwd.var)
    ()
  =
  let ctx = Lwd.peek ctx' in
  let old_content_search_constraints =
  ctx.content_search_constraints 
  in
  let content_search_constraints =
    (Content_search_constraints.make
       ~fuzzy_max_edit_distance:ctx.fuzzy_max_edit_distance
       ~phrase:(fst @@ Lwd.peek ctx.content_search_field)
    )
  in
  set_document_selected ctx' 0;
  if Content_search_constraints.equal
old_content_search_constraints
  content_search_constraints
  then
    ()
  else (
    let documents =
          ctx.all_documents
          |> Array.to_seq
          |> Seq.filter_map (fun doc ->
              if Content_search_constraints.is_empty content_search_constraints then
                Some doc
              else (
                match Document.content_search_results content_search_constraints doc () with
                | Seq.Nil -> None
                | Seq.Cons _ as s ->
                  let content_search_results = (fun () -> s)
                                               |> OSeq.take Params.content_search_result_limit
                                               |> Array.of_seq
                  in
                  Array.sort Content_search_result.compare content_search_results;
                  Some { doc with content_search_results }
              )
            )
          |> Array.of_seq
    in
    Array.sort
    (fun (doc1 : Document.t) (doc2 : Document.t) ->
                    Content_search_result.compare
                      (doc1.content_search_results.(0))
                      (doc2.content_search_results.(0))
          )
          documents;
    Lwd.set ctx' { ctx with documents; content_search_constraints }
  )

let full_term_sized_background (ctx : ctx Lwd.var) =
  let (term_width, term_height) = Notty_unix.Term.size (Lwd.peek ctx).term in
  Notty.I.void term_width term_height
  |> Nottui.Ui.atom

module Document_list = struct
  let mouse_handler
      (ctx : ctx Lwd.var)
      ~x ~y
      (button : Notty.Unescape.button)
    =
    let _ = x in
    let _ = y in
    match button with
    | `Scroll `Down ->
      set_document_selected ctx
        ((Lwd.peek ctx).document_selected + 1);
      `Handled
    | `Scroll `Up ->
      set_document_selected ctx
        ((Lwd.peek ctx).document_selected - 1);
      `Handled
    | _ -> `Unhandled

  let f
      (ctx' : ctx Lwd.var)
    : Nottui.ui Lwd.t =
    Lwd.map ~f:(fun ctx ->
        let image_count = Array.length ctx.documents in
        let pane =
          if Array.length ctx.documents = 0 then (
            Nottui.Ui.empty
          ) else (
            let (images_selected, images_unselected) =
              Render.documents ctx.documents
            in
            let (_term_width, term_height) = Notty_unix.Term.size ctx.term in
            CCInt.range'
              ctx.document_selected
              (min (ctx.document_selected + term_height / 2) image_count)
            |> CCList.of_iter
            |> List.map (fun j ->
                if Int.equal ctx.document_selected j then
                  images_selected.(j)
                else
                  images_unselected.(j)
              )
            |> List.map Nottui.Ui.atom
            |> Nottui.Ui.vcat
          )
        in
        Nottui.Ui.join_z (full_term_sized_background ctx') pane
        |> Nottui.Ui.mouse_area (mouse_handler ctx')
      )
      (Lwd.get ctx')
end

let content_view
    (ctx' : ctx Lwd.var)
  =
  Lwd.map ~f:(fun ctx ->
      if Array.length ctx.documents = 0 then (
        Nottui.Ui.empty
      ) else (
        let (_term_width, term_height) = Notty_unix.Term.size ctx.term in
        let render_seq s =
          s
          |> OSeq.take term_height
          |> Seq.map Misc_utils.sanitize_string_for_printing
          |> Seq.map (fun s -> Nottui.Ui.atom Notty.(I.string A.empty s))
          |> List.of_seq
          |> Nottui.Ui.vcat
        in
        let doc = ctx.documents.(ctx.document_selected) in
        let content =
          Content_index.lines doc.content_index
          |> render_seq
        in
        content
      )
    )
    (Lwd.get ctx')

module Content_search_results = struct
  let mouse_handler
      (ctx : ctx Lwd.var)
      ~x ~y
      (button : Notty.Unescape.button)
    =
    let _ = x in
    let _ = y in
    match button with
    | `Scroll `Down ->
      set_content_search_result_selected ctx
        ((Lwd.peek ctx).content_search_result_selected + 1);
      `Handled
    | `Scroll `Up ->
      set_content_search_result_selected ctx
        ((Lwd.peek ctx).content_search_result_selected - 1);
      `Handled
    | _ -> `Unhandled

  let f (ctx' : ctx Lwd.var)
    : Nottui.ui Lwd.t =
    Lwd.map ~f:(fun ctx ->
        if Array.length ctx.documents = 0 then (
          Nottui.Ui.empty
        ) else (
          let result_count =
            Array.length ctx.documents.(ctx.document_selected).content_search_results
          in
          if result_count = 0 then (
            Nottui.Ui.empty
          ) else (
            let (_term_width, term_height) = Notty_unix.Term.size ctx.term in
            let images =
              Render.content_search_results
                ~start:ctx.content_search_result_selected
                ~end_exc:(min (ctx.content_search_result_selected + term_height / 2) result_count)
                ctx.documents.(ctx.document_selected)
            in
            let pane =
              images
              |> Array.map (fun img ->
                  Nottui.Ui.atom (Notty.I.(img <-> strf ""))
                )
              |> Array.to_list
              |> Nottui.Ui.vcat
            in
            Nottui.Ui.join_z (full_term_sized_background ctx') pane
            |> Nottui.Ui.mouse_area (mouse_handler ctx')
          )
        )
      )
      (Lwd.get ctx')
end

let top_pane_keyboard_handler
    (ctx' : ctx Lwd.var)
    (key : Nottui.Ui.key)
  =
  let ctx = Lwd.peek ctx' in
  match ctx.input_mode with
  | Navigate -> (
      match key, ctx.ui_mode with
      | ((`Escape, []), _)
      | ((`ASCII 'q', []), _)
      | ((`ASCII 'C', [`Ctrl]), _) -> (
          Lwd.set ctx.quit true;
          `Handled
        )
      | ((`Tab, []), _) -> (
          (match ctx.init_ui_mode with
           | Ui_multi_file -> (
               match ctx.ui_mode with
               | Ui_multi_file -> Lwd.set ctx' { ctx with ui_mode = Ui_single_file }
               | Ui_single_file -> Lwd.set ctx' { ctx with ui_mode = Ui_multi_file }
             )
           | Ui_single_file -> ()
          );
          `Handled
        )
      | ((`ASCII 'j', []), Ui_multi_file)
      | ((`Arrow `Down, []), Ui_multi_file) -> (
          set_document_selected ctx' (ctx.document_selected + 1);
          `Handled
        )
      | ((`ASCII 'k', []), Ui_multi_file)
      | ((`Arrow `Up, []), Ui_multi_file) -> (
          set_document_selected ctx' (ctx.document_selected - 1);
          `Handled
        )
      | ((`ASCII 'J', []), Ui_multi_file)
      | ((`Arrow `Down, [`Shift]), Ui_multi_file)
      | ((`ASCII 'j', []), Ui_single_file)
      | ((`Arrow `Down, []), Ui_single_file) ->
        set_content_search_result_selected ctx'
          (ctx.content_search_result_selected + 1);
        `Handled
      | ((`ASCII 'K', []), Ui_multi_file)
      | ((`Arrow `Up, [`Shift]), Ui_multi_file)
      | ((`ASCII 'k', []), Ui_single_file)
      | ((`Arrow `Up, []), Ui_single_file) ->
        set_content_search_result_selected ctx'
          (ctx.content_search_result_selected - 1);
        `Handled
      | ((`ASCII '/', []), _) ->
        Nottui.Focus.request ctx.content_search_focus_handle;
        Lwd.set ctx' { ctx with input_mode = Search };
        `Handled
      | ((`ASCII 'x', []), _) ->
        Lwd.set ctx.content_search_field empty_search_field;
        update_content_search_constraints ctx' ();
        `Handled
      | ((`Enter, []), _) -> (
          match ctx.document_src with
          | Stdin -> `Handled
          | Files _ -> (
              Lwd.set ctx'
                { ctx with
                  file_to_open = Some ctx.documents.(ctx.document_selected);
                };
              Lwd.set ctx.quit true;
              `Handled
            )
        )
      | _ -> `Handled
    )
  | Search -> `Unhandled

module Key_binding_info = struct
  type key_msg = {
    key : string;
    msg : string;
  }

  type key_msg_line = key_msg list

  let grid_contents (ctx : ctx) : ((input_mode * ui_mode) * (key_msg_line list)) list =
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
       (match ctx.init_ui_mode with
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

  let grid_height ctx =
    grid_contents ctx
    |> List.hd
    |> snd
    |> List.length

  let max_key_msg_len_lookup ctx =
    grid_contents ctx
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

  let key_msg_pair (ctx : ctx) modes { key; msg } : Nottui.ui Lwd.t =
    let (max_key_len, max_msg_len) =
      List.assoc modes (max_key_msg_len_lookup ctx)
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

  let f (ctx' : ctx Lwd.var) =
    let ctx = Lwd.peek ctx' in
    let grid =
      List.map (fun (modes, grid_contents) ->
          (modes,
           grid_contents
           |> List.map (fun l ->
               List.map (key_msg_pair ctx modes) l
             )
           |> Nottui_widgets.grid
             ~pad:(Nottui.Gravity.make ~h:`Negative ~v:`Negative)
          )
        )
        (grid_contents ctx)
    in
    let grid =
      Lwd.map ~f:(fun ctx ->
          List.assoc (ctx.input_mode, ctx.ui_mode) grid)
        (Lwd.get ctx')
    in
    (* (Lwd.join grid, grid_height) *)
    Lwd.join grid
end

module Search_field = struct
  let make_label_widget ~s ~len ~(highlight_on_mode : input_mode) (ctx' : ctx Lwd.var) =
    Lwd.map ~f:(fun ctx ->
        (if highlight_on_mode = ctx.input_mode then
           Notty.(I.string A.(st bold) s)
         else
           Notty.(I.string A.empty s))
        |> Notty.I.hsnap ~align:`Left len
        |> Nottui.Ui.atom
      ) (Lwd.get ctx')

  let make_search_field ~edit_field ~focus_handle ~f (ctx' : ctx Lwd.var) =
    Nottui_widgets.edit_field (Lwd.get edit_field)
      ~focus:focus_handle
      ~on_change:(fun (text, x) -> Lwd.set edit_field (text, x))
      ~on_submit:(fun _ ->
          f ();
          let ctx = Lwd.peek ctx' in
          Nottui.Focus.release ctx.content_search_focus_handle;
          Lwd.set ctx' { ctx with input_mode = Navigate }
        )

  let content_search_label (ctx : ctx Lwd.var) : Nottui.ui Lwd.t =
    let content_search_label_str = "Search:" in
    let label_strs =
      [ content_search_label_str ]
    in
    let max_label_len =
      List.fold_left (fun x s ->
          max x (String.length s))
        0
        label_strs
    in
    let label_widget_len = max_label_len + 1 in
    make_label_widget
      ~s:content_search_label_str
      ~len:label_widget_len
      ~highlight_on_mode:Search
      ctx

  let f (ctx' : ctx Lwd.var) : Nottui.ui Lwd.t =
    let ctx = Lwd.peek ctx' in
    Nottui_widgets.hbox
      [
        content_search_label ctx';
        make_search_field
          ~edit_field:ctx.content_search_field
          ~focus_handle:ctx.content_search_focus_handle
          ~f:(update_content_search_constraints ctx')
          ctx';
      ]
end

module Bottom_pane = struct
  let status_bar (ctx' : ctx Lwd.var) =
    let ctx = Lwd.peek ctx' in
    let fg_color = Notty.A.black in
    let bg_color = Notty.A.white in
    let background_bar () =
      let (term_width, _term_height) = Notty_unix.Term.size ctx.term in
      Notty.I.char Notty.A.(bg bg_color) ' ' term_width 1
      |> Nottui.Ui.atom
    in
    let element_spacing = 4 in
    let element_spacer =
      Notty.(I.string A.(bg bg_color ++ fg fg_color))
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
      ~f:(fun ctx ->
          let file_shown_count =
            Notty.I.strf ~attr:Notty.A.(bg bg_color ++ fg fg_color)
              "%5d/%d documents listed"
              (Array.length ctx.documents) (Array.length ctx.all_documents)
          in
          let index_of_selected =
            Notty.I.strf ~attr:Notty.A.(bg bg_color ++ fg fg_color)
              "index of document selected: %d"
              ctx.document_selected
          in
          let path_of_selected =
            Notty.I.strf ~attr:Notty.A.(bg bg_color ++ fg fg_color)
              "document selected: %s"
              (match ctx.documents.(ctx.document_selected).path with
               | Some s -> s
               | None -> "<stdin>")
          in
          let content =
            [ Some [ List.assoc ctx.input_mode input_mode_strings ]
            ; Some [ element_spacer; file_shown_count ]
            ; (match ctx.ui_mode with
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
      (Lwd.get ctx')

  let f (ctx' : ctx Lwd.var) : Nottui.ui Lwd.t =
    Nottui_widgets.vbox
      [
        status_bar ctx';
        Key_binding_info.f ctx';
        Search_field.f ctx';
      ]
end
