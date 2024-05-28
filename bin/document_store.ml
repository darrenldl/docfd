open Docfd_lib

type key = string

type document_info = Document.t * Search_result.t array

type t = {
  all_documents : Document.t String_map.t;
  search_exp : Search_exp.t;
  search_results : Search_result.t array String_map.t;
}

let size (t : t) =
  String_map.cardinal t.all_documents

let empty : t =
  {
    all_documents = String_map.empty;
    search_exp = Search_exp.empty;
    search_results = String_map.empty;
  }

let search_exp (t : t) = t.search_exp

let single_out ~path (t : t) =
  match String_map.find_opt path t.all_documents with
  | None -> None
  | Some doc ->
    let search_results = String_map.find path t.search_results in
    let all_documents = String_map.(add path doc empty) in
    Some
      {
        all_documents;
        search_exp = t.search_exp;
        search_results = String_map.(add path search_results empty);
      }

let min_binding (t : t) =
  match String_map.min_binding_opt t.all_documents with
  | None -> None
  | Some (path, doc) -> (
      let search_results =
        String_map.find path t.search_results
      in
      Some (path, (doc, search_results))
    )

let update_search_exp pool stop_signal search_exp (t : t) : t =
  if Search_exp.equal search_exp t.search_exp then (
    t
  ) else (
    let search_results =
      t.all_documents
      |> String_map.to_list
      |> Eio.Fiber.List.map ~max_fibers:Task_pool.size
        (fun (path, doc) ->
           let within_same_line =
             match Document.search_mode doc with
             | `Single_line -> true
             | `Multiline -> false
           in
           (path, Index.search pool stop_signal ~within_same_line search_exp (Document.index doc))
        )
      |> String_map.of_list
    in
    { t with
      search_exp;
      search_results;
    }
  )

let add_document pool (doc : Document.t) (t : t) : t =
  let within_same_line =
    match Document.search_mode doc with
    | `Single_line -> true
    | `Multiline -> false
  in
  let search_results =
    String_map.add
      (Document.path doc)
      (Index.search pool (Stop_signal.make ()) ~within_same_line t.search_exp (Document.index doc))
      t.search_results
  in
  { t with
    all_documents =
      String_map.add
        (Document.path doc)
        doc
        t.all_documents;
    search_results;
  }

let of_seq pool (s : Document.t Seq.t) =
  Seq.fold_left (fun t doc ->
      add_document pool doc t
    )
    empty
    s

let usable_documents (t : t) : (Document.t * Search_result.t array) array =
  if Search_exp.is_empty t.search_exp then (
    t.all_documents
    |> String_map.to_seq
    |> Seq.map (fun (_path, doc) -> (doc, [||]))
    |> Array.of_seq
  ) else (
    let arr =
      t.all_documents
      |> String_map.to_seq
      |> Seq.filter_map (fun (path, doc) ->
          let search_results = String_map.find path t.search_results in
          if Array.length search_results = 0 then
            None
          else
            Some (doc, search_results)
        )
      |> Array.of_seq
    in
    Array.sort (fun (_d0, s0) (_d1, s1) ->
        Search_result.compare_relevance s0.(0) s1.(0)
      )
      arr;
    arr
  )

let commit (t : t) : t =
  let documents_to_keep =
    usable_documents t
    |> Array.to_seq
    |> Seq.map (fun (doc, _) -> Document.path doc)
    |> String_set.of_seq
  in
  { all_documents = String_map.filter (fun path _ ->
        String_set.mem path documents_to_keep) t.all_documents;
    search_exp = t.search_exp;
    search_results = String_map.filter (fun path _ ->
        String_set.mem path documents_to_keep) t.search_results;
  }
