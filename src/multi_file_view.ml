module Vars = struct
  let index_of_document_selected = Lwd.var 0

  let index_of_search_result_selected = Lwd.var 0

  let search_field = Lwd.var empty_search_field

  let search_constraints =
    Lwd.var (Search_constraints.make
               ~fuzzy_max_edit_distance:0
               ~phrase:"")

  let focus_handle = Nottui.Focus.make ()

  let all_documents : Document.t list ref = ref []

  let total_document_count : int ref = ref 0
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
  Lwd.set Vars.Multi_file.search_constraints
    (Search_constraints.make
       ~fuzzy_max_edit_distance:!Params.max_fuzzy_edit_distance
       ~phrase:(fst @@ Lwd.peek Vars.Multi_file.search_field)
    )

let documents =
  Lwd.map
    ~f:(fun search_constraints ->
        !Vars.all_documents
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
    (Lwd.get Vars.search_constraints)

module Top_pane = struct
  module Right_pane = struct
    let main
      : Nottui.ui Lwd.t =
      Lwd.map ~f:(fun (documents, document_selected) ->
          if Array.length documents = 0 then
            Nottui_widgets.(v_pane [ empty_lwd; empty_lwd ])
          else (
            let document = documents.(document_selected) in
            Nottui_widgets.v_pane
              [
                Ui_base.Content_view.main ~document ~search_result_selected;
                Ui_base.Search_result_list.main ~document ~search_result_selected;
              ]
          )
        )
        Lwd.(pair
               documents
               Vars.document_selected)
  end
end

module Bottom_pane = struct
end

let main
    ~document
  : Nottui.ui Lwd.t =
  Lwd.set Vars.document document;
  Nottui_widgets.hbox
    [
      Top_pane.main;
      Bottom_pane.main ~document;
    ]
