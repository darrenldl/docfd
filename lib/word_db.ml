type t = {
  lock : Eio.Mutex.t;
  mutable size : int;
  mutable size_written_to_db : int;
  mutable word_of_index : string Int_map.t;
  index_of_word : (string, int) Hashtbl.t;
  doc_ids_of_word_id : (int, CCBV.t) Hashtbl.t;
}

let t : t =
  {
    lock = Eio.Mutex.create ();
    size = 0;
    size_written_to_db = 0;
    word_of_index = Int_map.empty;
    index_of_word = Hashtbl.create 10_000;
    doc_ids_of_word_id = Hashtbl.create 10_000;
  }

let lock : type a. (unit -> a) -> a =
  fun f ->
  Eio.Mutex.use_rw ~protect:true t.lock f

let filter pool (f : string -> bool) : Int_set.t =
  let word_of_index =
    lock (fun () ->
        t.word_of_index
      )
  in
  let max_end_exc_seen = ref 0 in
  let chunk_size = !Params.index_chunk_size * 10 in
  let chunk_start_end_exc_ranges =
    OSeq.(0 -- (t.size - 1) / chunk_size)
    |> Seq.map (fun chunk_index ->
        let start = chunk_index * chunk_size in
        let end_exc =
          min
            ((chunk_index + 1) * chunk_size)
            t.size
        in
        max_end_exc_seen := max !max_end_exc_seen end_exc;
        (start, end_exc)
      )
    |> List.of_seq
  in
  assert (!max_end_exc_seen = t.size);
  chunk_start_end_exc_ranges
  |> Task_pool.map_list pool (fun (start, end_exc) ->
      let acc = ref Int_set.empty in
      for i=start to end_exc-1 do
        if f (Int_map.find i word_of_index) then (
          acc := Int_set.add i !acc
        )
      done;
      !acc
    )
  |> List.fold_left Int_set.union Int_set.empty

let add (word : string) : int =
  lock (fun () ->
      match Hashtbl.find_opt t.index_of_word word with
      | Some index -> index
      | None -> (
          let index = t.size in
          t.size <- t.size + 1;
          t.word_of_index <- Int_map.add index word t.word_of_index;
          Hashtbl.replace t.index_of_word word index;
          index
        )
    )

let doc_ids_of_word_id ~word_id =
  Hashtbl.find t.doc_ids_of_word_id word_id

let add_word_id_doc_id_link ~word_id ~doc_id =
  lock (fun () ->
      let doc_ids =
        match Hashtbl.find_opt t.doc_ids_of_word_id word_id with
        | Some doc_ids -> doc_ids
        | None -> (
            let bv = CCBV.empty () in
            Hashtbl.replace t.doc_ids_of_word_id word_id bv;
            bv
          )
      in
      CCBV.set doc_ids (Int64.to_int doc_id)
    )

let word_of_index i : string =
  lock (fun () ->
      Int_map.find i t.word_of_index
    )

let index_of_word s : int =
  lock (fun () ->
      Hashtbl.find t.index_of_word s
    )

let read_from_db () : unit =
  let open Sqlite3_utils in
  lock (fun () ->
      with_db (fun db ->
          t.word_of_index <- Int_map.empty;
          Hashtbl.clear t.index_of_word;
          Hashtbl.clear t.doc_ids_of_word_id;
          iter_stmt ~db
            {|
  SELECT id, word
  FROM word
  |}
            ~names:[]
            (fun data ->
               let id = Data.to_int_exn data.(0) in
               let word = Data.to_string_exn data.(1) in
               t.word_of_index <- Int_map.add id word t.word_of_index;
               Hashtbl.replace t.index_of_word word id;
            );
          iter_stmt ~db
            {|
  SELECT word_id, doc_id
  FROM word_id_doc_id_link
  |}
            ~names:[]
            (fun data ->
               let word_id = Data.to_int_exn data.(0) in
               let doc_id = Data.to_int_exn data.(1) in
               let doc_ids =
                 match Hashtbl.find_opt t.doc_ids_of_word_id word_id with
                 | Some doc_ids -> doc_ids
                 | None -> (
                     let bv = CCBV.empty () in
                     Hashtbl.replace t.doc_ids_of_word_id word_id bv;
                     bv
                   )
               in
               CCBV.set doc_ids doc_id
            )
        );
      t.size <- Int_map.cardinal t.word_of_index;
      t.size_written_to_db <- t.size;
    )

let write_to_db db ~already_in_transaction : unit =
  let open Sqlite3_utils in
  lock (fun () ->
      if not already_in_transaction then (
        step_stmt ~db "BEGIN IMMEDIATE" ignore;
      );
      let word_table_size =
        step_stmt ~db
          {|
      SELECT COUNT(1) FROM word
      |}
          (fun stmt ->
             Int64.to_int (column_int64 stmt 0)
          )
      in
      if word_table_size <> t.size_written_to_db then (
        Misc_utils.exit_with_error_msg
          "unexpected change in word table, likely due to indexing from another Docfd instance";
      );
      with_stmt ~db
        {|
  INSERT INTO word
  (id, word)
  VALUES
  (@id, @word)
  ON CONFLICT(id) DO NOTHING
  |}
        (fun stmt ->
           for id = t.size_written_to_db to t.size-1 do
             let word = Int_map.find id t.word_of_index in
             bind_names
               stmt
               [ ("@id", INT (Int64.of_int id))
               ; ("@word", TEXT word)
               ];
             step stmt;
             reset stmt;
           done
        );
      if not already_in_transaction then (
        step_stmt ~db "COMMIT" ignore;
      );
      t.size_written_to_db <- t.size;
    )
