open Docfd_lib

type key = string

type search_result_group = Document.t * Search_result.t array

type t = {
  all_documents : Document.t String_map.t;
  filter_exp : Filter_exp.t;
  filter_exp_string : string;
  documents_passing_filter : String_set.t;
  documents_marked : String_set.t;
  search_exp : Search_exp.t;
  search_exp_string : string;
  search_results : Search_result.t array String_map.t;
}

let size (t : t) =
  String_map.cardinal t.all_documents

let empty : t =
  {
    all_documents = String_map.empty;
    filter_exp = Filter_exp.empty;
    filter_exp_string = "";
    documents_passing_filter = String_set.empty;
    documents_marked = String_set.empty;
    search_exp = Search_exp.empty;
    search_exp_string = "";
    search_results = String_map.empty;
  }

let filter_exp (t : t) = t.filter_exp

let filter_exp_string (t : t) = t.filter_exp_string

let search_exp (t : t) = t.search_exp

let search_exp_string (t : t) = t.search_exp_string

let single_out ~path (t : t) =
  match String_map.find_opt path t.all_documents with
  | None -> None
  | Some doc ->
    let search_results = String_map.find path t.search_results in
    let all_documents = String_map.(add path doc empty) in
    let documents_passing_filter =
      if String_set.mem path t.documents_passing_filter then (
        String_set.(add path empty)
      ) else (
        String_set.empty
      )
    in
    Some
      {
        t with
        all_documents;
        documents_passing_filter;
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

let refresh_search_results pool stop_signal (t : t) : t option =
  let cancellation_notifier = Atomic.make false in
  let updates =
    Eio.Fiber.first
      (fun () ->
         Stop_signal.await stop_signal;
         Atomic.set cancellation_notifier true;
         String_map.empty)
      (fun () ->
         t.documents_passing_filter
         |> String_set.to_seq
         |> Seq.filter (fun path ->
             Option.is_none (String_map.find_opt path t.search_results)
           )
         |> List.of_seq
         |> Task_pool.map_list pool (fun path ->
             let doc = String_map.find path t.all_documents in
             let within_same_line =
               match Document.search_mode doc with
               | `Single_line -> true
               | `Multiline -> false
             in
             Index.make_search_job_groups
               stop_signal
               ~cancellation_notifier
               ~doc_hash:(Document.doc_hash doc)
               ~within_same_line
               ~search_scope:(Document.search_scope doc)
               t.search_exp
             |> Seq.map (fun x -> (path, x))
             |> List.of_seq
           )
         |> List.concat
         |> Task_pool.map_list pool (fun (path, search_job_group) ->
             let heap = Index.Search_job_group.run search_job_group in
             (path, heap)
           )
         |> List.fold_left (fun acc (path, heap) ->
             Eio.Fiber.yield ();
             let heap =
               String_map.find_opt path acc
               |> Option.value ~default:Search_result_heap.empty
               |> Search_result_heap.merge heap
             in
             String_map.add path heap acc
           )
           String_map.empty
         |> String_map.map (fun v ->
             Eio.Fiber.yield ();
             let arr =
               Search_result_heap.to_seq v
               |> Array.of_seq
             in
             Array.sort Search_result.compare_relevance arr;
             arr
           )
      )
  in
  if Atomic.get cancellation_notifier then (
    None
  ) else (
    let search_results =
      String_map.union (fun _k v1 _v2 -> Some v1)
        updates
        t.search_results
    in
    Some { t with search_results }
  )

let update_filter_exp
    pool
    stop_signal
    filter_exp_string
    filter_exp
    (t : t)
  : t option =
  let cancellation_notifier = Atomic.make false in
  let documents_passing_filter =
    Eio.Fiber.first
      (fun () ->
         Stop_signal.await stop_signal;
         Atomic.set cancellation_notifier true;
         String_set.empty
      )
      (fun () ->
         t.all_documents
         |> String_map.to_seq
         |> Seq.map snd
         |> (fun s ->
             if Filter_exp.is_empty filter_exp then (
               s
             ) else (
               Seq.filter (fun s ->
                   Eio.Fiber.yield ();
                   Document.satisfies_filter_exp pool filter_exp s
                 ) s
             )
           )
         |> Seq.map Document.path
         |> String_set.of_seq
      )
  in
  if Atomic.get cancellation_notifier then (
    None
  ) else (
    { t with
      filter_exp_string;
      filter_exp;
      documents_passing_filter;
    }
    |> refresh_search_results pool stop_signal
  )

let update_search_exp pool stop_signal search_exp_string search_exp (t : t) : t option =
  if Search_exp.equal search_exp t.search_exp then (
    Some t
  ) else (
    { t with
      search_exp;
      search_exp_string;
      search_results = String_map.empty;
    }
    |> refresh_search_results pool stop_signal
  )

let add_document pool (doc : Document.t) (t : t) : t =
  let within_same_line =
    match Document.search_mode doc with
    | `Single_line -> true
    | `Multiline -> false
  in
  let path = Document.path doc in
  let documents_passing_filter =
    if Document.satisfies_filter_exp pool t.filter_exp doc
    then
      String_set.add path t.documents_passing_filter
    else
      t.documents_passing_filter
  in
  let search_results =
    String_map.add
      path
      (Index.search
         pool
         (Stop_signal.make ())
         ~doc_hash:(Document.doc_hash doc)
         ~within_same_line
         ~search_scope:(Document.search_scope doc)
         t.search_exp
       |> Option.get
      )
      t.search_results
  in
  { t with
    all_documents =
      String_map.add
        path
        doc
        t.all_documents;
    documents_passing_filter;
    search_results;
  }

let of_seq pool (s : Document.t Seq.t) =
  Seq.fold_left (fun t doc ->
      add_document pool doc t
    )
    empty
    s

let search_result_groups (t : t) : (Document.t * Search_result.t array) array =
  let no_search_exp = Search_exp.is_empty t.search_exp in
  let arr =
    t.documents_passing_filter
    |> String_set.to_seq
    |> Seq.map (fun path ->
        (path, String_map.find path t.all_documents)
      )
    |> (fun s ->
        if no_search_exp then (
          Seq.map (fun (_path, doc) -> (doc, [||])) s
        ) else (
          Seq.filter_map (fun (path, doc) ->
              match String_map.find_opt path t.search_results with
              | None -> None
              | Some search_results -> (
                  if Array.length search_results = 0 then
                    None
                  else
                    Some (doc, search_results)
                )
            ) s
        )
      )
    |> Array.of_seq
  in
  if not no_search_exp then (
    Array.sort (fun (_d0, s0) (_d1, s1) ->
        Search_result.compare_relevance s0.(0) s1.(0)
      )
      arr
  );
  arr

let usable_document_paths (t : t) : String_set.t =
  search_result_groups t
  |> Array.to_seq
  |> Seq.map (fun (doc, _) -> Document.path doc)
  |> String_set.of_seq

let marked_document_paths (t : t) =
  t.documents_marked

let all_document_paths (t : t) : string Seq.t =
  t.all_documents
  |> String_map.to_seq
  |> Seq.map fst

let unusable_document_paths (t : t) =
  let s = usable_document_paths t in
  all_document_paths t
  |> Seq.filter (fun path ->
      not (String_set.mem path s))

let mark
    (choice :
       [ `Path of string
       | `Usable
       | `Unusable ])
    t
  : t =
  match choice with
  | `Path path -> (
      match String_map.find_opt path t.all_documents with
      | None -> t
      | Some _ -> (
          let documents_marked =
            String_set.add path t.documents_marked
          in
          { t with documents_marked }
        )
    )
  | `Usable -> (
      let documents_marked =
        String_set.union
          t.documents_marked
          (usable_document_paths t)
      in
      { t with documents_marked }
    )
  | `Unusable -> (
      let documents_marked =
        Seq.fold_left
          (fun acc x -> String_set.add x acc)
          t.documents_marked
          (unusable_document_paths t)
      in
      { t with documents_marked }
    )

let unmark ~path t =
  let documents_marked =
    String_set.remove path t.documents_marked
  in
  { t with documents_marked }

let toggle_mark ~path t =
  if String_set.mem path t.documents_marked then (
    unmark ~path t
  ) else (
    mark ~path t
  )

let unmark_all t =
  {t with documents_marked = String_set.empty }

let drop
    (choice :
       [ `Path of string
       | `All_except of string
       | `Marked
       | `Unmarked
       | `Usable
       | `Unusable ])
    (t : t)
  : t =
  let aux ~(keep : string -> bool) =
    let keep' : 'a. string -> 'a -> bool =
      fun path _ ->
        keep path
    in
    { all_documents = String_map.filter keep' t.all_documents;
      filter_exp = t.filter_exp;
      filter_exp_string = t.filter_exp_string;
      documents_passing_filter = String_set.filter keep t.documents_passing_filter;
      documents_marked = String_set.filter keep t.documents_marked;
      search_exp = t.search_exp;
      search_exp_string = t.search_exp_string;
      search_results = String_map.filter keep' t.search_results;
    }
  in
  match choice with
  | `Path path -> (
      { all_documents = String_map.remove path t.all_documents;
        filter_exp = t.filter_exp;
        filter_exp_string = t.filter_exp_string;
        documents_passing_filter = String_set.remove path t.documents_passing_filter;
        documents_marked = String_set.remove path t.documents_marked;
        search_exp = t.search_exp;
        search_exp_string = t.search_exp_string;
        search_results = String_map.remove path t.search_results;
      }
    )
  | `All_except path -> (
      let keep path' =
        String.equal path' path
      in
      aux ~keep
    )
  | `Marked -> (
      let keep path =
        not (String_set.mem path t.documents_marked)
      in
      aux ~keep
    )
  | `Unmarked -> (
      let keep path =
        String_set.mem path t.documents_marked
      in
      aux ~keep
    )
  | `Usable | `Unusable -> (
      let usable_document_paths =
        usable_document_paths t
      in
      let document_is_usable path =
        String_set.mem path usable_document_paths
      in
      let keep path =
        match choice with
        | `Usable -> not (document_is_usable path)
        | `Unusable -> document_is_usable path
        | _ -> failwith "unexpected case"
      in
      aux ~keep
    )

let narrow_search_scope_to_level ~level (t : t) : t =
  let all_documents =
    if level = 0 then (
      String_map.mapi (fun _path doc ->
          Document.reset_search_scope_to_full doc
        )
        t.all_documents
    ) else (
      String_map.mapi (fun path doc ->
          let doc_hash = Document.doc_hash doc in
          let search_scope =
            match String_map.find_opt path t.search_results with
            | None -> Diet.Int.empty
            | Some search_results -> (
                if String_set.mem path t.documents_passing_filter then (
                  Array.fold_left (fun scope search_result ->
                      let s, e =
                        List.fold_left (fun s_e Search_result.{ found_word_pos; _ } ->
                            match s_e with
                            | None -> Some (found_word_pos, found_word_pos)
                            | Some (s, e) -> (
                                Some (min s found_word_pos, max found_word_pos e)
                              )
                          )
                          None
                          (Search_result.found_phrase search_result)
                        |> Option.get
                      in
                      let offset = level * !Params.tokens_per_search_scope_level in
                      let s, e =
                        (max 0 (s - offset), min (Index.max_pos ~doc_hash) (e + offset))
                      in
                      Diet.Int.add
                        (Diet.Int.Interval.make s e)
                        scope
                    )
                    Diet.Int.empty
                    search_results
                ) else (
                  Diet.Int.empty
                )
              )
          in
          Document.inter_search_scope
            search_scope
            doc
        )
        t.all_documents
    )
  in
  { t with all_documents }

let run_command pool (command : Command.t) (t : t) : t option =
  match command with
  | `Mark path -> (
      Some (mark ~path t)
    )
  | `Unmark path -> (
      Some (unmark ~path t)
    )
  | `Unmark_all -> (
      Some (unmark_all t)
    )
  | `Drop s -> (
      Some (drop (`Path s) t)
    )
  | `Drop_all_except s -> (
      Some (drop (`All_except s) t)
    )
  | `Drop_marked -> (
      Some (drop `Marked t)
    )
  | `Drop_unmarked -> (
      Some (drop `Unmarked t)
    )
  | `Drop_listed -> (
      Some (drop `Usable t)
    )
  | `Drop_unlisted -> (
      Some (drop `Unusable t)
    )
  | `Narrow_level level -> (
      Some (narrow_search_scope_to_level ~level t)
    )
  | `Search s -> (
      match Search_exp.parse s with
      | None -> None
      | Some search_exp -> (
          update_search_exp
            pool
            (Stop_signal.make ())
            s
            search_exp
            t
        )
    )
  | `Filter s -> (
      match Filter_exp.parse s with
      | None -> None
      | Some exp -> (
          update_filter_exp
            pool
            (Stop_signal.make ())
            s
            exp
            t
        )
    )
