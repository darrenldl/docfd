type t = {
  lock : Eio.Mutex.t;
  word_of_index : string Dynarray.t;
  index_of_word : (string, int) Hashtbl.t;
  new_reductions : (int, String_set.t) Hashtbl.t;
}

let t : t =
  {
    lock = Eio.Mutex.create ();
    word_of_index = Dynarray.create ();
    index_of_word = Hashtbl.create 10_000;
    new_reductions = Hashtbl.create 10_000;
  }

let lock : type a. (unit -> a) -> a =
  fun f ->
  Eio.Mutex.use_rw ~protect:false t.lock f

let add (word : string) : int =
  lock (fun () ->
      match Hashtbl.find_opt t.index_of_word word with
      | Some index -> index
      | None -> (
          let index = Dynarray.length t.word_of_index in
          Dynarray.add_last t.word_of_index word;
          Hashtbl.replace t.index_of_word word index;
          Hashtbl.replace
            t.new_reductions
            index
            (Misc_utils.delete_reductions
               ~edit_dist:!Params.max_fuzzy_edit_dist
               word);
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
  (* We don't load reductions from DB as
     we don't make use of reductions within Word_db.

     Index will make use of reductions only at
     DB level.
  *)
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
          Hashtbl.iter (fun id reductions ->
              if id mod 100 = 0 then (
                step_stmt ~db "COMMIT" ignore;
                step_stmt ~db "BEGIN IMMEDIATE" ignore;
              );
              String_set.iter (fun s ->
                  step_stmt ~db
                    {|
    INSERT INTO word_delete_reduction
    (word_id, reduced)
    VALUES
    (@word_id, @reduced)
  ON CONFLICT(word_id, reduced) DO NOTHING
    |}
                    ~names:[ ("@word_id", INT (Int64.of_int id))
                           ; ("@reduced", TEXT s)
                           ]
                    ignore;
                ) reductions
            )
            t.new_reductions;
          step_stmt ~db "COMMIT" ignore;
          Hashtbl.clear t.new_reductions;
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
                   if id mod 5000 = 0 then (
                     step_stmt ~db "COMMIT" ignore;
                     step_stmt ~db "BEGIN IMMEDIATE" ignore;
                   );
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
