type t = {
  lock : Eio.Mutex.t;
  mutable size : int;
  mutable size_written_to_db : int;
  mutable word_of_id : string Int_map.t;
  id_of_word : (string, int) Hashtbl.t;
}

let t : t =
  {
    lock = Eio.Mutex.create ();
    size = 0;
    size_written_to_db = 0;
    word_of_id = Int_map.empty;
    id_of_word = Hashtbl.create 100_000;
  }

let lock : type a. (unit -> a) -> a =
  fun f ->
  Eio.Mutex.use_rw ~protect:true t.lock f

let filter pool (f : string -> bool) : (int * string) Dynarray.t =
  let word_of_id =
    lock (fun () ->
        t.word_of_id
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
  let batches =
    chunk_start_end_exc_ranges
    |> Task_pool.map_list pool (fun (start, end_exc) ->
        let acc = Dynarray.create () in
        for i=start to end_exc-1 do
          let word = Int_map.find i word_of_id in
          if f word then (
            Dynarray.add_last acc (i, word)
          )
        done;
        acc
      )
  in
  let acc = Dynarray.create () in
  List.iter (fun batch ->
      Dynarray.append acc batch
    ) batches;
  acc

let add (word : string) : int =
  lock (fun () ->
      match Hashtbl.find_opt t.id_of_word word with
      | Some id -> id
      | None -> (
          let id = t.size in
          t.size <- t.size + 1;
          t.word_of_id <- Int_map.add id word t.word_of_id;
          Hashtbl.replace t.id_of_word word id;
          id
        )
    )

let word_of_id i : string =
  lock (fun () ->
      Int_map.find i t.word_of_id
    )

let id_of_word s : int option =
  lock (fun () ->
      Hashtbl.find_opt t.id_of_word s
    )

let read_from_db () : unit =
  let open Sqlite3_utils in
  lock (fun () ->
      with_db (fun db ->
          t.word_of_id <- Int_map.empty;
          Hashtbl.clear t.id_of_word;
          iter_stmt ~db
            {|
  SELECT id, word
  FROM word
  ORDER by id
  |}
            ~names:[]
            (fun data ->
               let id = Data.to_int_exn data.(0) in
               let word = Data.to_string_exn data.(1) in
               t.word_of_id <- Int_map.add id word t.word_of_id;
               Hashtbl.replace t.id_of_word word id;
            )
        );
      t.size <- Int_map.cardinal t.word_of_id;
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
             let word = Int_map.find id t.word_of_id in
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
