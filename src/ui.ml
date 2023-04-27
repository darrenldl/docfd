type input_mode =
  | Navigate
  | Search

type ui_mode =
  | Ui_single_file
  | Ui_multi_file

type document_src =
  | Stdin
  | Files of string list

type key_msg = {
  key : string;
  msg : string;
}

type key_msg_line = key_msg list

let make_label_widget ~s ~len (mode : input_mode) (v : input_mode Lwd.var) =
  Lwd.map ~f:(fun mode' ->
      (if mode = mode' then
         Notty.(I.string A.(st bold) s)
       else
         Notty.(I.string A.empty s))
      |> Notty.I.hsnap ~align:`Left len
      |> Nottui.Ui.atom
    ) (Lwd.get v)

let empty_search_field = ("", 0)

module Vars = struct
  let quit = Lwd.var false

  let document_selected = Lwd.var 0

  module Multi_file = struct

    let content_search_result_selected = Lwd.var 0

    let content_search_field = Lwd.var empty_search_field

    let content_search_constraints =
      Lwd.var (Content_search_constraints.make
                 ~fuzzy_max_edit_distance:0
                 ~phrase:"")
  end

  module Single_file = struct
    let content_search_result_selected = Lwd.var 0

    let content_search_field = Lwd.var empty_search_field

    let content_search_constraints =
      Lwd.var (Content_search_constraints.make
                 ~fuzzy_max_edit_distance:0
                 ~phrase:"")
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

let documents =
  Lwd.map2
    ~f:(fun all_documents content_constraints ->
        all_documents
        |> List.filter_map (fun doc ->
            if Content_search_constraints.is_empty content_constraints then
              Some doc
            else (
              match Document.content_search_results content_constraints doc () with
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
        |> (fun l ->
            if Content_search_constraints.is_empty content_constraints then
              l
            else
              List.sort (fun (doc1 : Document.t) (doc2 : Document.t) ->
                  Content_search_result.compare
                    (doc1.content_search_results.(0))
                    (doc2.content_search_results.(0))
                ) l
          )
        |> Array.of_list
      )
    (Lwd.get Vars.all_documents)
    (Lwd.get Vars.Multi_file.content_search_constraints)

let bound_selection ~choice_count (x : int) : int =
  max 0 (min (choice_count - 1) x)

module Multi_file = struct
  let set_document_selected ~choice_count n =
    let n = bound_selection ~choice_count n in
    Lwd.set Vars.document_selected n;
    Lwd.set Vars.Multi_file.content_search_result_selected 0

  let reset_document_selected () =
    Lwd.set Vars.document_selected 0;
    Lwd.set Vars.Multi_file.content_search_result_selected 0

  let set_content_search_result_selected ~choice_count n =
    let n = bound_selection ~choice_count n in
    Lwd.set Vars.Multi_file.content_search_result_selected n

  let update_content_search_constraints () =
    reset_document_selected ();
    Lwd.set Vars.Multi_file.content_search_constraints
      (Content_search_constraints.make
         ~fuzzy_max_edit_distance:!Params.max_fuzzy_edit_distance
         ~phrase:(fst @@ Lwd.peek Vars.Multi_file.content_search_field)
      )
end

module Single_file = struct
  let set_content_search_result_selected ~choice_count n =
    let n = bound_selection ~choice_count n in
    Lwd.set Vars.Single_file.content_search_result_selected n

  let reset_content_search_result_selected () =
    Lwd.set Vars.Single_file.content_search_result_selected 0

  let update_content_search_constraints () =
    Lwd.set Vars.Single_file.content_search_result_selected 0;
    Lwd.set Vars.Single_file.content_search_constraints
      (Content_search_constraints.make
         ~fuzzy_max_edit_distance:!Params.max_fuzzy_edit_distance
         ~phrase:(fst @@ Lwd.peek Vars.Single_file.content_search_field)
      )
end

let content_focus_handle = Nottui.Focus.make ()

module Document_list = struct
  let mouse_handler
      ~document_choice_count
      ~document_current_choice
      ~x ~y
      (button : Notty.Unescape.button)
    =
    let _ = x in
    let _ = y in
    match button with
    | `Scroll `Down ->
      Multi_file.set_document_selected
        ~choice_count:document_choice_count (document_current_choice+1);
      `Handled
    | `Scroll `Up ->
      Multi_file.set_document_selected
        ~choice_count:document_choice_count (document_current_choice-1);
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
        |> Nottui.Ui.mouse_area
          (mouse_handler
             ~document_choice_count:image_count
             ~document_current_choice:i)
      )
      documents
      (Lwd.get Vars.document_selected)
end

module Content_view = struct
let main =
  Lwd.map2 ~f:(fun documents i ->
      if Array.length documents = 0 then (
        Nottui.Ui.empty
      ) else (
        let (_term_width, term_height) = Notty_unix.Term.size !Vars.term in
        let render_seq s =
          s
          |> OSeq.take term_height
          |> Seq.map Misc_utils.sanitize_string_for_printing
          |> Seq.map (fun s -> Nottui.Ui.atom Notty.(I.string A.empty s))
          |> List.of_seq
          |> Nottui.Ui.vcat
        in
        let doc = documents.(i) in
        let content =
          Content_index.lines doc.content_index
          |> render_seq
        in
        content
      )
    )
    documents
    (Lwd.get Vars.document_selected)
end

module Content_search_result_list = struct
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
           Single_file.set_content_search_result_selected
             ~choice_count
             (current_choice + 1)
         | Ui_multi_file ->
           Multi_file.set_content_search_result_selected
             ~choice_count
             (current_choice + 1)
        );
        `Handled
      )
    | `Scroll `Up -> (
        (match Lwd.peek Vars.ui_mode with
         | Ui_single_file ->
           Single_file.set_content_search_result_selected
             ~choice_count
             (current_choice - 1)
         | Ui_multi_file ->
           Multi_file.set_content_search_result_selected
             ~choice_count
             (current_choice - 1)
        );
        `Handled
      )
    | _ -> `Unhandled

  let main =
    Lwd.map ~f:(fun (ui_mode, (documents, (i, (mf_search_res_i, sf_search_res_i)))) ->
        if Array.length documents = 0 then (
          Nottui.Ui.empty
        ) else (
          let result_count =
            Array.length documents.(i).content_search_results
          in
          if result_count = 0 then (
            Nottui.Ui.empty
          ) else (
            let search_res_i =
              match ui_mode with
              | Ui_multi_file -> mf_search_res_i
              | Ui_single_file -> sf_search_res_i
            in
            let (_term_width, term_height) = Notty_unix.Term.size !Vars.term in
            let images =
              Render.content_search_results
                ~start:search_res_i
                ~end_exc:(min (search_res_i + term_height / 2) result_count)
                documents.(i)
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
                 ~current_choice:search_res_i)
          )
        )
      )
      Lwd.(pair
      (Lwd.get Vars.ui_mode)
      (pair
             documents
             (pair
                (Lwd.get Vars.document_selected)
                (pair
                   (Lwd.get Vars.Multi_file.content_search_result_selected)
                   (Lwd.get Vars.Single_file.content_search_result_selected)))))
end

let keyboard_handler
    ~document_choice_count
    ~document_current_choice
    ~content_search_result_current_choice
    (documents : Document.t array)
    (key : Nottui.Ui.key)
  =
  let content_search_result_choice_count =
    Array.length documents.(document_current_choice).content_search_results
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
               | Ui_multi_file -> Lwd.set Vars.ui_mode Ui_single_file
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
      | ((`ASCII 'J', []), _)
      | ((`Arrow `Down, [`Shift]), _) -> (
        Multi_file.set_content_search_result_selected
             ~choice_count:content_search_result_choice_count
             (content_search_result_current_choice+1);
        `Handled
      )
      | ((`ASCII 'j', []), Ui_single_file)
      | ((`Arrow `Down, []), Ui_single_file) -> (
        Single_file.set_content_search_result_selected
             ~choice_count:content_search_result_choice_count
             (content_search_result_current_choice+1);
        `Handled
      )
      | ((`ASCII 'K', []), _)
      | ((`Arrow `Up, [`Shift]), _) -> (
        Multi_file.set_content_search_result_selected
             ~choice_count:content_search_result_choice_count
             (content_search_result_current_choice-1);
        `Handled
      )
      | ((`ASCII 'k', []), Ui_single_file)
      | ((`Arrow `Up, []), Ui_single_file) -> (
        Single_file.set_content_search_result_selected
             ~choice_count:content_search_result_choice_count
             (content_search_result_current_choice-1);
        `Handled
      )
      | ((`ASCII '/', []), _) ->
        Nottui.Focus.request content_focus_handle;
        Lwd.set Vars.input_mode Search;
        `Handled
      | ((`ASCII 'x', []), Ui_single_file) ->
        Lwd.set Vars.Single_file.content_search_field empty_search_field;
        Single_file.update_content_search_constraints ();
        `Handled
      | ((`ASCII 'x', []), Ui_multi_file) ->
        Lwd.set Vars.Multi_file.content_search_field empty_search_field;
        Multi_file.update_content_search_constraints ();
        `Handled
      | ((`Enter, []), _) -> (
          match !Vars.document_src with
          | Stdin -> `Handled
          | Files _ -> (
              Lwd.set Vars.quit true;
              Vars.file_to_open := Some documents.(document_current_choice);
              `Handled
            )
        )
      | _ -> `Handled
    )
  | Search -> `Unhandled
