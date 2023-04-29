module Vars = struct
  let index_of_document_selected = Lwd.var 0

  let index_of_search_result_selected = Lwd.var 0

  let search_field = Lwd.var Ui_base.empty_search_field

  let search_constraints =
    Lwd.var (Search_constraints.make
               ~fuzzy_max_edit_distance:0
               ~phrase:"")

  let focus_handle = Nottui.Focus.make ()
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
    let main ~documents =
      let document_count = Array.length documents in
      Lwd.map ~f:(fun document_selected ->
          let pane =
            if document_count = 0 then (
              Nottui.Ui.empty
            ) else (
              let (images_selected, images_unselected) =
                Render.documents documents
              in
              let (_term_width, term_height) = Notty_unix.Term.size !Ui_base.Vars.term in
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
              (Ui_base.Search_result_list.main ~document ~search_result_selected)
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
  let main ~documents =
    Nottui_widgets.empty_lwd
end

let main : Nottui.ui Lwd.t =
  Lwd.map ~f:(fun documents ->
  Nottui_widgets.hbox
    [
      Top_pane.main ~documents;
      Bottom_pane.main ~documents;
    ]
  )
  documents
              |> Lwd.join
