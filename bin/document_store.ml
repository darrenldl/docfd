open Docfd_lib

type key = string option

type value = Document.t * Search_result.t array

type t = {
  all_documents : Document.t String_option_map.t;
  filtered_documents : Document.t String_option_map.t;
  content_reqs : Content_req_exp.t;
  search_phrase : Search_phrase.t;
  search_results : Search_result.t array String_option_map.t;
}

let empty : t =
  {
    all_documents = String_option_map.empty;
    filtered_documents = String_option_map.empty;
    content_reqs = Content_req_exp.empty;
    search_phrase = Search_phrase.empty;
    search_results = String_option_map.empty;
  }

let search_phrase (t : t) = t.search_phrase

let single_out ~path (t : t) =
  match String_option_map.find_opt path t.filtered_documents with
  | None -> None
  | Some doc ->
    let search_results = String_option_map.find path t.search_results in
    let all_documents = String_option_map.(add path doc empty) in
    Some
      {
        all_documents;
        filtered_documents = all_documents;
        content_reqs = t.content_reqs;
        search_phrase = t.search_phrase;
        search_results = String_option_map.(add path search_results empty);
      }

let min_binding (t : t) =
  match String_option_map.min_binding_opt t.all_documents with
  | None -> None
  | Some (path, doc) -> (
      let search_results =
        String_option_map.find path t.search_results
      in
      Some (path, (doc, search_results))
    )

let update_content_reqs (content_reqs : Content_req_exp.t) (t : t) : t =
  if Content_req_exp.equal content_reqs t.content_reqs then (
    t
  ) else (
    let filtered_documents =
      if Content_req_exp.is_empty content_reqs then (
        t.all_documents
      ) else (
        String_option_map.filter_map (fun _path doc ->
            if Index.fulfills_content_reqs content_reqs doc.Document.index then
              Some doc
            else
              None
          )
          t.all_documents
      )
    in
    { t with
      content_reqs;
      filtered_documents;
      search_results =
        String_option_map.mapi (fun _path doc ->
            Index.search t.search_phrase doc.Document.index
          )
          filtered_documents;
    }
  )

let update_search_phrase search_phrase (t : t) : t =
  if Search_phrase.equal search_phrase t.search_phrase then (
    t
  ) else (
    { t with
      search_phrase;
      search_results =
        String_option_map.mapi (fun _path doc ->
            Index.search search_phrase doc.Document.index
          )
          t.filtered_documents;
    }
  )

let add_document (doc : Document.t) (t : t) : t =
  { t with
    all_documents =
      String_option_map.add
        doc.path
        doc
        t.all_documents;
    filtered_documents =
      (if Index.fulfills_content_reqs t.content_reqs doc.index then
         String_option_map.add doc.path doc t.filtered_documents
       else
         t.filtered_documents
      );
    search_results =
      String_option_map.add
        doc.path
        (Index.search t.search_phrase doc.index)
        t.search_results;
  }

let of_seq (s : Document.t Seq.t) =
  Seq.fold_left (fun t doc ->
      add_document doc t
    )
    empty
    s

let usable_documents (t : t) : (Document.t * Search_result.t array) array =
  if Search_phrase.is_empty t.search_phrase then (
    t.filtered_documents
    |> String_option_map.to_seq
    |> Seq.map (fun (_path, doc) -> (doc, [||]))
    |> Array.of_seq
  ) else (
    let arr =
      t.filtered_documents
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
  )
