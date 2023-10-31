open Docfd_lib

type key = string

type value = Document.t * Search_result.t array

type t = {
  all_documents : Document.t String_map.t;
  filtered_documents : Document.t String_map.t;
  content_reqs : Content_req_exp.t;
  search_phrase : Search_phrase.t;
  search_results : Search_result.t array String_map.t;
}

let size (t : t) =
  String_map.cardinal t.all_documents

let empty : t =
  {
    all_documents = String_map.empty;
    filtered_documents = String_map.empty;
    content_reqs = Content_req_exp.empty;
    search_phrase = Search_phrase.empty;
    search_results = String_map.empty;
  }

let content_reqs (t : t) = t.content_reqs

let search_phrase (t : t) = t.search_phrase

let single_out ~path (t : t) =
  match String_map.find_opt path t.filtered_documents with
  | None -> None
  | Some doc ->
    let search_results = String_map.find path t.search_results in
    let all_documents = String_map.(add path doc empty) in
    Some
      {
        all_documents;
        filtered_documents = all_documents;
        content_reqs = t.content_reqs;
        search_phrase = t.search_phrase;
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

let update_content_reqs
    ~(stop_signal : Stop_signal.t)
    (content_reqs : Content_req_exp.t)
    (t : t)
  : t =
  if Content_req_exp.equal content_reqs t.content_reqs then (
    t
  ) else (
    let filtered_documents =
      if Content_req_exp.is_empty content_reqs then (
        t.all_documents
      ) else (
        Eio.Fiber.first
          (fun () ->
             Stop_signal.await stop_signal;
             String_map.empty
          )
          (fun () ->
             t.all_documents
             |> String_map.to_list
             |> Eio.Fiber.List.filter_map ~max_fibers:Task_pool.size
               (fun (path, doc) ->
                  if Index.fulfills_content_reqs content_reqs doc.Document.index then
                    Some (path, doc)
                  else
                    None
               )
             |> String_map.of_list
          )
      )
    in
    let search_results =
      Eio.Fiber.first
        (fun () ->
           Stop_signal.await stop_signal;
           String_map.empty
        )
        (fun () ->
           filtered_documents
           |> String_map.to_list
           |> Eio.Fiber.List.map ~max_fibers:Task_pool.size
             (fun (path, doc) ->
                (path, Index.search t.search_phrase doc.Document.index)
             )
           |> String_map.of_list
        )
    in
    { t with
      content_reqs;
      filtered_documents;
      search_results;
    }
  )

let update_search_phrase ~(stop_signal : Stop_signal.t) search_phrase (t : t) : t =
  if Search_phrase.equal search_phrase t.search_phrase then (
    t
  ) else (
    let search_results =
      Eio.Fiber.first
        (fun () ->
           Stop_signal.await stop_signal;
           String_map.empty
        )
        (fun () ->
           t.filtered_documents
           |> String_map.to_list
           |> Eio.Fiber.List.map ~max_fibers:Task_pool.size
             (fun (path, doc) ->
                (path, Index.search search_phrase doc.Document.index)
             )
           |> String_map.of_list
        )
    in
    { t with
      search_phrase;
      search_results;
    }
  )

let add_document ~(stop_signal : Stop_signal.t) (doc : Document.t) (t : t) : t =
  let filtered_documents =
    Eio.Fiber.first
      (fun () ->
         Stop_signal.await stop_signal;
         String_map.empty
      )
      (fun () ->
         if Index.fulfills_content_reqs t.content_reqs doc.index then
           String_map.add doc.path doc t.filtered_documents
         else
           t.filtered_documents
      )
  in
  let search_results =
    Eio.Fiber.first
      (fun () ->
         Stop_signal.await stop_signal;
         String_map.empty
      )
      (fun () ->
         String_map.add
           doc.path
           (Index.search t.search_phrase doc.index)
           t.search_results
      )
  in
  { t with
    all_documents =
      String_map.add
        doc.path
        doc
        t.all_documents;
    filtered_documents;
    search_results;
  }

let of_seq (s : Document.t Seq.t) =
  let dummy_stop_signal = Stop_signal.make () in
  Seq.fold_left (fun t doc ->
      add_document ~stop_signal:dummy_stop_signal doc t
    )
    empty
    s

let usable_documents (t : t) : (Document.t * Search_result.t array) array =
  if Search_phrase.is_empty t.search_phrase then (
    t.filtered_documents
    |> String_map.to_seq
    |> Seq.map (fun (_path, doc) -> (doc, [||]))
    |> Array.of_seq
  ) else (
    let arr =
      t.filtered_documents
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
