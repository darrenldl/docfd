type t = {
  lock : Eio.Mutex.t;
  mutable word_of_index : string Int_map.t;
  index_of_word : (string, int) Hashtbl.t;
}

let t : t =
  {
    lock = Eio.Mutex.create ();
    word_of_index = Int_map.empty;
    index_of_word = Hashtbl.create 10_000;
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
  let total_count = Int_map.cardinal word_of_index in
  let max_end_exc_seen = ref 0 in
  let chunk_size = !Params.index_chunk_size * 10 in
  let chunk_start_end_exc_ranges =
    OSeq.(0 -- (total_count - 1) / chunk_size)
    |> Seq.map (fun chunk_index ->
        let start = chunk_index * chunk_size in
        let end_exc =
          min
            ((chunk_index + 1) * chunk_size)
            total_count
        in
        max_end_exc_seen := max !max_end_exc_seen end_exc;
        (start, end_exc)
      )
    |> List.of_seq
  in
  assert (!max_end_exc_seen = total_count);
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
          let index = Int_map.cardinal t.word_of_index in
          t.word_of_index <- Int_map.add index word t.word_of_index;
          Hashtbl.replace t.index_of_word word index;
          index
        )
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
               t.word_of_index <- Int_map.add id word t.word_of_index;
               Hashtbl.replace t.index_of_word word id;
            )
        )
    )

let write_to_db () : unit =
  let open Sqlite3_utils in
  lock (fun () ->
      with_db (fun db ->
          step_stmt ~db "BEGIN IMMEDIATE" ignore;
          with_stmt ~db
            {|
  INSERT INTO word
  (id, word)
  VALUES
  (@id, @word)
  ON CONFLICT(id) DO NOTHING
  |}
            (fun stmt ->
               Int_map.iter (fun id word ->
                   bind_names
                     stmt
                     [ ("@id", INT (Int64.of_int id))
                     ; ("@word", TEXT word)
                     ];
                   step stmt;
                   reset stmt;
                 )
                 t.word_of_index
            );
          step_stmt ~db "COMMIT" ignore;
        )
    )
