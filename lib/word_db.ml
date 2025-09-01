type t = {
  lock : Eio.Mutex.t;
  word_of_index : string Dynarray.t;
  index_of_word : (string, int) Hashtbl.t;
}

let t : t =
  {
    lock = Eio.Mutex.create ();
    word_of_index = Dynarray.create ();
    index_of_word = Hashtbl.create 10_000;
  }

let lock : type a. (unit -> a) -> a =
  fun f ->
  Eio.Mutex.use_rw ~protect:false t.lock f

let filter pool (f : string -> bool) : Int_set.t =
  lock (fun () ->
      Dynarray.to_seq t.word_of_index
      |> Seq.mapi (fun i word -> (i, word))
      |> OSeq.chunks !Params.index_chunk_size
      |> List.of_seq
    )
  |> Task_pool.map_list pool (fun chunk ->
      Array.fold_left (fun acc (i, word) ->
          if f word then (
            Int_set.add i acc
          ) else (
            acc
          )
        )
        Int_set.empty
        chunk
    )
  |> List.fold_left Int_set.union Int_set.empty

let add (word : string) : int =
  lock (fun () ->
      match Hashtbl.find_opt t.index_of_word word with
      | Some index -> index
      | None -> (
          let index = Dynarray.length t.word_of_index in
          Dynarray.add_last t.word_of_index word;
          Hashtbl.replace t.index_of_word word index;
          index
        )
    )

let word_of_index i : string =
  lock (fun () ->
      Dynarray.get t.word_of_index i
    )

let index_of_word s : int =
  lock (fun () ->
      Hashtbl.find t.index_of_word s
    )

let read_from_db () : unit =
  let open Sqlite3_utils in
  lock (fun () ->
      with_db (fun db ->
          Dynarray.clear t.word_of_index;
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
               Dynarray.add_last t.word_of_index word;
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
               Dynarray.iteri (fun id word ->
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
