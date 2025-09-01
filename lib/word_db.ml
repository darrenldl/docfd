type t = {
  lock : Eio.Mutex.t;
  word_of_index : string Dynarray.t;
  index_of_word : (string, int) Hashtbl.t;
  reductions : (int, String_set.t) Hashtbl.t;
  mutable index_of_first_word_new_to_db : int;
}

let t : t =
  {
    lock = Eio.Mutex.create ();
    word_of_index = Dynarray.create ();
    index_of_word = Hashtbl.create 10_000;
    reductions = Hashtbl.create 10_000;
    index_of_first_word_new_to_db = 0;
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
          if String.for_all Parser_components.is_letter word then (
            Hashtbl.replace
              t.reductions
              index
              (Misc_utils.delete_reductions
                 ~edit_dist:Params.max_fuzzy_edit_dist
                 word);
          );
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
          Hashtbl.clear t.reductions;
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
            );
          t.index_of_first_word_new_to_db := Dynarray.length t.word_of_index;
        )
    )

let write_to_db () : unit =
  let open Sqlite3_utils in
  lock (fun () ->
      with_db (fun db ->
          let total_word_count = Dynarray.length t.word_of_index in
          let counter = ref 0 in
          let outstanding_transaction = ref false in
          with_stmt ~db
            {|
    INSERT INTO word_delete_reduction
    (word_id, reduced)
    VALUES
    (@word_id, @reduced)
  ON CONFLICT(word_id, reduced) DO NOTHING
    |}
            (fun stmt ->
               for id = t.index_of_first_word_new_to_db to total_word_count-1 do
                 match Hashtbl.find_opt t.reductions id with
                 | None -> ()
                 | Some reductions -> (
                     String_set.iter (fun s ->
                         if !counter = 0 then (
                           step_stmt ~db "BEGIN IMMEDIATE" ignore;
                           outstanding_transaction := true;
                         );
                         bind_names stmt
                           [ ("@word_id", INT (Int64.of_int id))
                           ; ("@reduced", TEXT s)
                           ];
                         step stmt;
                         reset stmt;
                         if !counter >= 10_000 then (
                           step_stmt ~db "COMMIT" ignore;
                           outstanding_transaction := false;
                           counter := 0;
                         ) else (
                           incr counter;
                         );
                       ) reductions
                   )
               done;
               if !outstanding_transaction then (
                 step_stmt ~db "COMMIT" ignore;
               );
            );
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
          t.index_of_first_word_new_to_db <- Dynarray.length t.word_of_index;
        )
    )
