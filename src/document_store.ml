type t = {
  documents : Document.t String_option_map.t;
  search_constraints : Search_constraints.t;
  search_results : Search_result.t array String_option_map.t;
}

let empty : t =
  {
    documents = String_option_map.empty;
    search_constraints = Search_constraints.empty;
    search_results = String_option_map.empty;
}

let update_search_constraints search_constraints (t : t) : t =
  { t with search_constraints }

let add_document (doc : Document.t) (t : t) : t =
  { t with
  documents =
    String_option_map.add
    doc.path
    doc
    t.documents;
  search_results =
    String_option_map.add
    doc.path
    (Index.search t.search_constraints doc.index)
    t.search_results;
  }

let usable_documents (t : t) : (Document.t * Search_result.t array) array =
  let arr =
  t.documents
  |> String_option_map.to_seq
  |> Seq.filter_map (fun (path, doc) ->
      let search_results = String_option_map.find path t.search_results in
      if Array.length search_results = 0 then
        None
      else
        Some (doc, search_results)
  )
  |> Array.of_seq
  in
  Array.sort (fun (_d0, s0) (_d1, s1) ->
    Search_result.compare s0.(0) s1.(0)
  )
  arr;
  arr
