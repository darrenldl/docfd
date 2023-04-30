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

  let file_to_open : Document.t option ref = ref None

  let input_mode : input_mode Lwd.var = Lwd.var Navigate

  let init_ui_mode : ui_mode ref = ref Ui_multi_file

  let ui_mode : ui_mode Lwd.var = Lwd.var Ui_multi_file

  let document_src : document_src ref = ref (Files [])

  let term : Notty_unix.Term.t option ref = ref None

  let all_documents : Document.t list ref = ref []

  let total_document_count : int ref = ref 0

  let document_selected : Document.t Lwd.var = Lwd.var (Document.make_empty ())

  module Single_file = struct
    let search_field = Lwd.var empty_search_field

    let index_of_search_result_selected = Lwd.var 0
  end
end

let get_term () =
  Option.get !Vars.term

let full_term_sized_background () =
  let (term_width, term_height) = Notty_unix.Term.size (get_term ()) in
  Notty.I.void term_width term_height
  |> Nottui.Ui.atom

module Content_view = struct
  let main
      ~(document : Document.t)
      ~(search_result_selected : int)
    : Nottui.ui Lwd.t =
    let (_term_width, term_height) = Notty_unix.Term.size (get_term ()) in
    let height = term_height / 2 in
    let search_result =
      if Array.length document.search_results = 0 then
        None
      else
        Some document.search_results.(search_result_selected)
    in
    let content =
      Content_and_search_result_render.content_snippet
        ?search_result
        ~height
        document.index
    in
    Lwd.return (Nottui.Ui.atom content)
end

let mouse_handler
    ~(choice_count : int)
    ~(current_choice : int Lwd.var)
    ~x ~y
    (button : Notty.Unescape.button)
  =
  let _ = x in
  let _ = y in
  let n = Lwd.peek current_choice in
  match button with
  | `Scroll `Down -> (
      Lwd.set current_choice (Misc_utils.bound_selection ~choice_count (n + 1));
      `Handled
    )
  | `Scroll `Up -> (
      Lwd.set current_choice (Misc_utils.bound_selection ~choice_count (n - 1));
      `Handled
    )
  | _ -> `Unhandled

module Search_result_list = struct
  let main
      ~(document : Document.t)
      ~(search_result_selected : int)
    : Nottui.ui Lwd.t =
    let search_results = document.search_results in
    let result_count = Array.length search_results in
    if result_count = 0 then (
      Lwd.return Nottui.Ui.empty
    ) else (
      let (_term_width, term_height) = Notty_unix.Term.size (get_term ()) in
      let images =
        Content_and_search_result_render.search_results
          ~start:search_result_selected
          ~end_exc:(min (search_result_selected + term_height / 2) result_count)
          document.index
          search_results
      in
      let pane =
        images
        |> List.map (fun img ->
            Nottui.Ui.atom (Notty.I.(img <-> strf ""))
          )
        |> Nottui.Ui.vcat
      in
      Lwd.return
        (Nottui.Ui.join_z (full_term_sized_background ()) pane)
        (* |> Nottui.Ui.mouse_area
           (mouse_handler
             ~choice_count:result_count
             ~current_choice:search_result_selected) *)
    )
end

module Status_bar = struct
  let fg_color = Notty.A.black

  let bg_color = Notty.A.white

  let attr = Notty.A.(bg bg_color ++ fg fg_color)

  let background_bar () =
    let (term_width, _term_height) = Notty_unix.Term.size (get_term ()) in
    Notty.I.char Notty.A.(bg bg_color) ' ' term_width 1
    |> Nottui.Ui.atom

  let element_spacing = 4

  let element_spacer =
    Notty.(I.string
             A.(bg bg_color ++ fg fg_color))
      (String.make element_spacing ' ')

  let input_mode_images =
    let l =
      [ (Navigate, "NAVIGATE")
      ; (Search, "SEARCH")
      ]
    in
    let max_input_mode_string_len =
      List.fold_left (fun acc (_, s) ->
          max acc (String.length s)
        )
        0
        l
    in
    let input_mode_string_background =
      Notty.I.char Notty.A.(bg bg_color) ' ' max_input_mode_string_len 1
    in
    List.map (fun (mode, s) ->
        let s = Notty.(I.string A.(bg bg_color ++ fg fg_color ++ st bold) s) in
        (mode, Notty.I.(s </> input_mode_string_background))
      )
      l

      (*
  let main
      ~(input_mode : input_mode Lwd.var)
    : Nottui.ui Lwd.t =
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
             [
               Some [ List.assoc input_mode input_mode_strings ];
               (match ui_mode with
                | Ui_single_file -> None
                | Ui_multi_file ->
                  Some [ element_spacer; file_shown_count ]
               );
               (match ui_mode with
                | Ui_single_file ->
                  Some [ element_spacer; path_of_selected ]
                | Ui_multi_file ->
                  Some [ element_spacer; index_of_selected ]
               );
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
                       *)
end

module Key_binding_info = struct
  type label_msg = {
    label : string;
    msg : string;
  }

  type label_msg_line = label_msg list

  type grid_key = {
    input_mode : input_mode;
    init_ui_mode : ui_mode;
  }

  type grid_contents = (grid_key * (label_msg_line list)) list

  type grid_lookup = (grid_key * Nottui.ui Lwd.t) list

  let make_grid_lookup grid_contents : grid_lookup =
    let max_label_msg_len_lookup =
      grid_contents
      |> List.map (fun (mode, grid) ->
          let max_label_len, max_msg_len =
            List.fold_left (fun (max_label_len, max_msg_len) row ->
                List.fold_left (fun (max_label_len, max_msg_len) { label; msg } ->
                    (max max_label_len (String.length label),
                     max max_msg_len (String.length msg))
                  )
                  (max_label_len, max_msg_len)
                  row
              )
              (0, 0)
              grid
          in
          (mode, (max_label_len, max_msg_len))
        )
    in
    let label_msg_pair modes { label; msg } : Nottui.ui Lwd.t =
      let (max_label_len, max_msg_len) =
        List.assoc modes max_label_msg_len_lookup
      in
      let label_attr = Notty.A.(fg lightyellow ++ st bold) in
      let msg_attr = Notty.A.empty in
      let msg = String.capitalize_ascii msg in
      let label_background = Notty.I.void max_label_len 1 in
      let content = Notty.(I.hcat
                             [ I.(string label_attr label </> label_background)
                             ; I.string A.empty "  "
                             ; I.string msg_attr msg
                             ]
                          )
      in
      let full_background =
        Notty.I.void (max_label_len + 2 + max_msg_len + 2) 1
      in
      Notty.I.(content </> full_background)
      |> Nottui.Ui.atom
      |> Lwd.return
    in
    List.map (fun (mode, grid_contents) ->
        (mode,
         grid_contents
         |> List.map (fun l ->
             List.map (label_msg_pair mode) l
           )
         |> Nottui_widgets.grid
           ~pad:(Nottui.Gravity.make ~h:`Negative ~v:`Negative)
        )
      )
      grid_contents

  let main ~(grid_lookup : grid_lookup) ~(input_mode : input_mode) =
    List.assoc { input_mode; init_ui_mode = !Vars.init_ui_mode } grid_lookup
end

module Search_bar = struct
  let search_label ~(input_mode : input_mode) =
    let attr =
      match input_mode with
      | Search -> Notty.A.(st bold)
      | _ -> Notty.A.empty
    in
    (Notty.I.string attr "Search: ")
    |> Nottui.Ui.atom
    |> Lwd.return

  let main
      ~input_mode
      ~(edit_field : (string * int) Lwd.var)
      ~focus_handle
      ~f
    : Nottui.ui Lwd.t =
    Nottui_widgets.hbox
      [
        search_label ~input_mode;
        Nottui_widgets.edit_field (Lwd.get edit_field)
          ~focus:focus_handle
          ~on_change:(fun (text, x) -> Lwd.set edit_field (text, x))
          ~on_submit:(fun _ ->
              f ();
              Nottui.Focus.release focus_handle;
              Lwd.set Vars.input_mode Navigate
            );
      ]
end

(*
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
                          Vars.Single_file.search_results
                          (Array.copy document.Document.search_results);
                     )
                     document;
                   Lwd.set
                     Vars.Single_file.search_field
                     (Lwd.peek Vars.Multi_file.search_field);
                   Lwd.set Vars.ui_mode Ui_single_file;
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
*)
