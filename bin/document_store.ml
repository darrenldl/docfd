open Docfd_lib

type key = string

type search_result_group = Document.t * Search_result.t array

module Sort_by = struct
  type typ = [
    | `Path_date
    | `Path
    | `Score
    | `Mod_time
    | `Fzf_ranking of int String_map.t
  ]

  type t = typ * Document.Compare.order
end

type t = {
  all_documents : Document.t String_map.t;
  filter_exp : Filter_exp.t;
  filter_exp_string : string;
  documents_passing_filter : String_set.t;
  documents_marked : String_set.t;
  search_exp : Search_exp.t;
  search_exp_string : string;
  search_results : Search_result.t array String_map.t;
  sort_by : Sort_by.t;
  sort_by_no_score : Sort_by.t;
  focus_list : string list;
}

let equal (x : t) (y : t) =
  String_map.equal Document.equal x.all_documents y.all_documents
  &&
  String.equal x.filter_exp_string y.filter_exp_string
  &&
  String_set.equal x.documents_passing_filter y.documents_passing_filter
  &&
  String_set.equal x.documents_marked y.documents_marked
  &&
  String.equal x.search_exp_string y.search_exp_string
  &&
  String_map.equal
    (Array.for_all2 Search_result.equal)
    x.search_results
    y.search_results

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
    sort_by = Command.Sort_by.default
      |> (fun (typ, order) -> ((typ :> Sort_by.typ), order));
    sort_by_no_score = Command.Sort_by.default_no_score
      |> (fun (typ, order) -> ((typ :> Sort_by.typ), order));
    focus_list = [];
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
         let global_first_word_candidates_lookup =
           Index.generate_global_first_word_candidates_lookup
             pool
             t.search_exp
         in
         let usable_doc_ids =
           let bv = CCBV.empty () in
           Search_phrase.Enriched_token.Data_map.iter
             (fun _word word_ids ->
                Int_set.iter (fun word_id ->
                    Index.State.union_doc_ids_of_word_id_into_bv ~word_id ~into:bv
                  )
                  word_ids
             )
             global_first_word_candidates_lookup;
           bv
         in
         let documents_to_search_through =
           t.documents_passing_filter
           |> String_set.to_seq
           |> Seq.map (fun path -> (path, String_map.find path t.all_documents))
           |> Seq.filter (fun (path, doc) ->
               Option.is_none (String_map.find_opt path t.search_results)
               && CCBV.get usable_doc_ids (Int64.to_int @@ Document.doc_id doc)
             )
           |> List.of_seq
         in
         documents_to_search_through
         |> Task_pool.map_list pool (fun (path, doc) ->
             let within_same_line =
               match Document.search_mode doc with
               | `Single_line -> true
               | `Multiline -> false
             in
             Index.make_search_job_groups
               stop_signal
               ~cancellation_notifier
               ~doc_id:(Document.doc_id doc)
               ~doc_word_ids:(Document.word_ids doc)
               ~global_first_word_candidates_lookup
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
  if Filter_exp.equal filter_exp t.filter_exp then (
    Some { t with filter_exp_string }
  ) else (
    let cancellation_notifier = Atomic.make false in
    let documents_passing_filter =
      Eio.Fiber.first
        (fun () ->
           Stop_signal.await stop_signal;
           Atomic.set cancellation_notifier true;
           String_set.empty
        )
        (fun () ->
           let global_first_word_candidates_lookup =
             Filter_exp.all_content_search_exps filter_exp
             |> List.fold_left (fun acc search_exp ->
                 Index.generate_global_first_word_candidates_lookup
                   pool
                   ~acc
                   search_exp
               )
               Search_phrase.Enriched_token.Data_map.empty
           in
           t.all_documents
           |> String_map.to_seq
           |> Seq.map snd
           |> (fun s ->
               if Filter_exp.is_empty filter_exp then (
                 s
               ) else (
                 Seq.filter (fun s ->
                     Eio.Fiber.yield ();
                     Document.satisfies_filter_exp
                       pool
                       ~global_first_word_candidates_lookup
                       filter_exp
                       s
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
  )

let update_search_exp pool stop_signal search_exp_string search_exp (t : t) : t option =
  if Search_exp.equal search_exp t.search_exp then (
    Some { t with search_exp_string }
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
    let global_first_word_candidates_lookup =
      Filter_exp.all_content_search_exps t.filter_exp
      |> List.fold_left (fun acc search_exp ->
          Index.generate_global_first_word_candidates_lookup
            pool
            ~acc
            search_exp
        )
        Search_phrase.Enriched_token.Data_map.empty
    in
    if Document.satisfies_filter_exp pool ~global_first_word_candidates_lookup t.filter_exp doc
    then
      String_set.add path t.documents_passing_filter
    else
      t.documents_passing_filter
  in
  let search_results =
    let global_first_word_candidates_lookup =
      Index.generate_global_first_word_candidates_lookup
        pool
        t.search_exp
    in
    String_map.add
      path
      (Index.search
         pool
         (Stop_signal.make ())
         ~doc_id:(Document.doc_id doc)
         ~doc_word_ids:(Document.word_ids doc)
         ~global_first_word_candidates_lookup
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

module Compare_search_result_group = struct
  let mod_time order (d0, _s0) (d1, _s1) =
    Document.Compare.mod_time order d0 d1

  let path_date order (d0, _s0) (d1, _s1) =
    Document.Compare.path_date order d0 d1

  let path order (d0, _s0) (d1, _s1) =
    Document.Compare.path order d0 d1

  let fzf_ranking ranking order (d0, _s0) (d1, _s1) =
    match
      String_map.find_opt (Document.path d0) ranking,
      String_map.find_opt (Document.path d1) ranking
    with
    | None, None -> Document.Compare.path order d0 d1
    | None, Some _ -> (
        (* Always shuffle document with no fzf matches to the back. *)
        1
      )
    | Some _, None -> (
        (* Always shuffle document with no fzf matches to the back. *)
        -1
      )
    | Some x0, Some x1 -> (
        match order with
        | `Asc -> Int.compare x0 x1
        | `Desc -> Int.compare x1 x0
      )

  let score order (_d0, s0) (_d1, s1) =
    assert (Array.length s0 > 0);
    assert (Array.length s1 > 0);
    (* Search_result.compare_relevance puts the more relevant
       result to the front, so we flip the comparison here to
       obtain an ordering of "lowest score" first to match the
       usual definition of "sort by score in ascending order".
    *)
    match order with
    | `Asc -> Search_result.compare_relevance s1.(0) s0.(0)
    | `Desc -> Search_result.compare_relevance s0.(0) s1.(0)
end

let search_result_groups
    (t : t)
  : (Document.t * Search_result.t array) array =
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
  let rec f (sort_by_typ, sort_by_order) =
    match sort_by_typ with
    | `Path_date -> Compare_search_result_group.path_date sort_by_order
    | `Mod_time -> Compare_search_result_group.mod_time sort_by_order
    | `Path -> Compare_search_result_group.path sort_by_order
    | `Score -> (
        if no_search_exp then (
          f t.sort_by_no_score
        ) else (
          Compare_search_result_group.score sort_by_order
        )
      )
    | `Fzf_ranking ranking -> (
        Compare_search_result_group.fzf_ranking ranking sort_by_order
      )
  in
  Array.sort (f t.sort_by) arr;
  let focus_ranking =
    List.rev t.focus_list
    |> CCList.foldi (fun ranking i x ->
        String_map.add x i ranking) String_map.empty
  in
  Array.stable_sort (fun (d0, _) (d1, _) ->
      match
        String_map.find_opt (Document.path d0) focus_ranking,
        String_map.find_opt (Document.path d1) focus_ranking
      with
      | Some x0, Some x1 -> Int.compare x0 x1
      | Some _, None -> -1
      | None, Some _ -> 1
      | None, None -> 0
    ) arr;
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

let unusable_documents (t : t) =
  let s = usable_document_paths t in
  t.all_documents
  |> String_map.to_seq
  |> Seq.filter (fun (path, _doc) ->
      not (String_set.mem path s))
  |> Seq.map snd

let unusable_document_paths (t : t) =
  unusable_documents t
  |> Seq.map Document.path

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

let unmark
    (choice :
       [ `Path of string
       | `Usable
       | `Unusable
       | `All ])
    t
  : t =
  match choice with
  | `Path path -> (
      let documents_marked =
        String_set.remove path t.documents_marked
      in
      { t with documents_marked }
    )
  | `Usable -> (
      let documents_marked =
        String_set.diff
          t.documents_marked
          (usable_document_paths t)
      in
      { t with documents_marked }
    )
  | `Unusable -> (
      let documents_marked =
        Seq.fold_left
          (fun acc x -> String_set.remove x acc)
          t.documents_marked
          (unusable_document_paths t)
      in
      { t with documents_marked }
    )
  | `All -> (
      { t with documents_marked = String_set.empty }
    )

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
      sort_by = t.sort_by;
      sort_by_no_score = t.sort_by_no_score;
      focus_list = t.focus_list;
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
        sort_by = t.sort_by;
        sort_by_no_score = t.sort_by_no_score;
        focus_list = t.focus_list;
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
          let doc_id = Document.doc_id doc in
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
                        (max 0 (s - offset), min (Index.max_pos ~doc_id) (e + offset))
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

let run_command pool (command : Command.t) (t : t) : (Command.t * t) option =
  let reset_focus_list t = { t with focus_list = [] } in
  match command with
  | `Mark path -> (
      Some (command, mark (`Path path) t)
    )
  | `Mark_listed -> (
      Some (command, mark `Usable t)
    )
  | `Unmark path -> (
      Some (command, unmark (`Path path) t)
    )
  | `Unmark_listed -> (
      Some (command, unmark `Usable t)
    )
  | `Unmark_all -> (
      Some (command, unmark `All t)
    )
  | `Drop s -> (
      Some (command, drop (`Path s) t)
    )
  | `Drop_all_except s -> (
      Some (command, drop (`All_except s) t)
    )
  | `Drop_marked -> (
      Some (command, drop `Marked t)
    )
  | `Drop_unmarked -> (
      Some (command, drop `Unmarked t)
    )
  | `Drop_listed -> (
      Some (command, drop `Usable t)
    )
  | `Drop_unlisted -> (
      Some (command, drop `Unusable t)
    )
  | `Narrow_level level -> (
      Some (command, narrow_search_scope_to_level ~level t)
    )
  | `Focus path -> (
      let focus_list = path :: t.focus_list in
      Some (command, { t with focus_list })
    )
  | `Sort (sort_by, sort_by_no_score) -> (
      let t = reset_focus_list t in
      let sort_by =
        sort_by
        |> (fun (typ, order) -> ((typ :> Sort_by.typ), order))
      in
      let sort_by_no_score =
        sort_by_no_score
        |> (fun (typ, order) -> ((typ :> Sort_by.typ), order))
      in
      Some (command, { t with sort_by; sort_by_no_score })
    )
  | `Sort_by_fzf (query, ranking) -> (
      let t = reset_focus_list t in
      let ranking =
        match ranking with
        | None -> (
            usable_document_paths t
            |> String_set.to_seq
            |> Seq.map File_utils.remove_cwd_from_path
            |> Proc_utils.filter_via_fzf query
            |> List.map Misc_utils.normalize_path_to_absolute
            |> Misc_utils.ranking_of_ranked_document_list
          )
        | Some x -> x
      in
      let sort_by = (`Fzf_ranking ranking, `Asc) in
      let command = `Sort_by_fzf (query, Some ranking) in
      Some (command, { t with sort_by; sort_by_no_score = sort_by })
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
          |> Option.map (fun store -> (command, store))
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
          |> Option.map (fun store -> (command, store))
        )
    )
