open Docfd_lib

type key = string

type document_info = Document.t * Search_result.t array

type t = {
  all_documents : Document.t String_map.t;
  file_path_filter_glob : Glob.t;
  documents_passing_filter : String_set.t;
  search_exp : Search_exp.t;
  search_exp_string : string;
  search_results : Search_result.t array String_map.t;
}

let size (t : t) =
  String_map.cardinal t.all_documents

let empty : t =
  {
    all_documents = String_map.empty;
    file_path_filter_glob = Option.get (Glob.make "");
    documents_passing_filter = String_set.empty;
    search_exp = Search_exp.empty;
    search_exp_string = "";
    search_results = String_map.empty;
  }

let file_path_filter_glob (t : t) = t.file_path_filter_glob

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

let refresh_search_results pool stop_signal (t : t) : t =
  let updates =
    t.documents_passing_filter
    |> String_set.to_seq
    |> Seq.filter (fun path ->
        Option.is_none (String_map.find_opt path t.search_results)
      )
    |> List.of_seq
    |> Eio.Fiber.List.map ~max_fibers:Task_pool.size
      (fun path ->
         let doc = String_map.find path t.all_documents in
         let within_same_line =
           match Document.search_mode doc with
           | `Single_line -> true
           | `Multiline -> false
         in
         (path,
          Index.search
            pool
            stop_signal
            ~within_same_line
            t.search_exp
            (Document.index doc))
      )
    |> String_map.of_list
  in
  let search_results =
    String_map.union (fun _k v1 _v2 -> Some v1)
      updates
      t.search_results
  in
  { t with search_results }

let update_file_path_filter_glob
    pool
    stop_signal
    file_path_filter_glob
    (t : t)
  : t =
  let documents_passing_filter =
    t.all_documents
    |> String_map.to_seq
    |> Seq.map fst
    |> (fun s ->
        if Glob.is_empty file_path_filter_glob then (
          s
        ) else (
          Seq.filter (Glob.match_ file_path_filter_glob) s
        )
      )
    |> String_set.of_seq
  in
  { t with
    file_path_filter_glob;
    documents_passing_filter;
  }
  |> refresh_search_results pool stop_signal

let update_search_exp pool stop_signal search_exp_string search_exp (t : t) : t =
  if Search_exp.equal search_exp t.search_exp then (
    t
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
    if Glob.match_ t.file_path_filter_glob path
    then
      String_set.add path t.documents_passing_filter
    else
      t.documents_passing_filter
  in
  let search_results =
    String_map.add
      path
      (Index.search pool (Stop_signal.make ()) ~within_same_line t.search_exp (Document.index doc))
      t.search_results
  in
  { t with
    all_documents =
      String_map.add
        (Document.path doc)
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

let usable_documents (t : t) : (Document.t * Search_result.t array) array =
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
              let search_results = String_map.find path t.search_results in
              if Array.length search_results = 0 then
                None
              else
                Some (doc, search_results)
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

let usable_documents_paths (t : t) : String_set.t =
  usable_documents t
  |> Array.to_seq
  |> Seq.map (fun (doc, _) -> Document.path doc)
  |> String_set.of_seq

let all_documents_paths (t : t) : string Seq.t =
  t.all_documents
  |> String_map.to_seq
  |> Seq.map fst

let unusable_documents_paths (t : t) =
  let s = usable_documents_paths t in
  all_documents_paths t
  |> Seq.filter (fun path ->
      not (String_set.mem path s))

let drop (choice : [ `Single of string | `Usable | `Unusable ]) (t : t) : t =
  match choice with
  | `Single path -> (
      { all_documents = String_map.remove path t.all_documents;
        file_path_filter_glob = t.file_path_filter_glob;
        documents_passing_filter = String_set.remove path t.documents_passing_filter;
        search_exp = t.search_exp;
        search_exp_string = t.search_exp_string;
        search_results = String_map.remove path t.search_results;
      }
    )
  | `Usable | `Unusable -> (
      let usable_documents_paths =
        usable_documents_paths t
      in
      let document_is_usable path =
        String_set.mem path usable_documents_paths
      in
      let f1 path =
        match choice with
        | `Usable -> not (document_is_usable path)
        | `Unusable -> document_is_usable path
        | _ -> failwith "unexpected case"
      in
      let f2 : 'a. string -> 'a -> bool =
        fun path _ ->
          f1 path
      in
      { all_documents = String_map.filter f2 t.all_documents;
        file_path_filter_glob = t.file_path_filter_glob;
        documents_passing_filter = String_set.filter f1 t.documents_passing_filter;
        search_exp = t.search_exp;
        search_exp_string = t.search_exp_string;
        search_results = String_map.filter f2 t.search_results;
      }
    )
