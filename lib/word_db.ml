type t = {
  word_of_index : string CCVector.vector;
  mutable index_of_word : int String_map.t;
}

let equal (x : t) (y : t) =
  CCVector.equal String.equal x.word_of_index y.word_of_index
  &&
  String_map.equal Int.equal x.index_of_word y.index_of_word

let make () : t = {
  word_of_index = CCVector.create ();
  index_of_word = String_map.empty;
}

let add (t : t) (word : string) : int =
  match String_map.find_opt word t.index_of_word with
  | Some index -> index
  | None -> (
      let index = CCVector.length t.word_of_index in
      CCVector.push t.word_of_index word;
      t.index_of_word <- String_map.add word index t.index_of_word;
      index
    )

let word_of_index t i : string =
  CCVector.get t.word_of_index i

let index_of_word t s : int =
  String_map.find s t.index_of_word

let load_into_db ~db ~doc_id (t : t) : unit =
  let open Sqlite3_utils in
  with_stmt ~db
    {|
  INSERT INTO word
  (id, doc_id, word)
  VALUES
  (@id, @doc_id, @word)
  ON CONFLICT(doc_id, id) DO NOTHING
  |}
    (fun stmt ->
       CCVector.iteri (fun id word ->
           bind_names
             stmt
             [ ("@doc_id", INT doc_id)
             ; ("@id", INT (Int64.of_int id))
             ; ("@word", TEXT word)
             ];
           step stmt;
           reset stmt;
         )
         t.word_of_index
    )
