type t = {
  lock : Eio.Mutex.t;
  doc_id_of_doc_hash : (string, int64) Hashtbl.t;
}

let t : t =
  {
    lock = Eio.Mutex.create ();
    doc_id_of_doc_hash = Hashtbl.create 10_000;
  }

let lock : type a. (unit -> a) -> a =
  fun f ->
  Eio.Mutex.use_rw ~protect:true t.lock f

let allocate_bulk (doc_hashes : string Seq.t) : unit =
  let open Sqlite3_utils in
  lock (fun () ->
      with_db (fun db ->
          with_stmt ~db
            {|
  INSERT INTO doc_info
  (id, hash, status)
  VALUES
  (
    (SELECT
      IFNULL(
        (
          SELECT a.id - 1 AS id
          FROM doc_info a
          LEFT JOIN doc_info b ON a.id - 1 = b.id
          WHERE b.id IS NULL AND a.id - 1 >= 0

          UNION

          SELECT a.id + 1 AS id
          FROM doc_info a
          LEFT JOIN doc_info b ON a.id + 1 = b.id
          WHERE b.id IS NULL

          ORDER BY id
          LIMIT 1
        ),
        0
      )
    ),
    @doc_hash,
    'ONGOING'
  )
  ON CONFLICT(hash) DO NOTHING
  |}
            (fun stmt ->
               Seq.iter (fun doc_hash ->
                   bind_names stmt [ ("@doc_hash", TEXT doc_hash) ];
                   step stmt;
                   reset stmt;
                 )
                 doc_hashes
            );
          with_stmt ~db
            {|
    SELECT id
    FROM doc_info
    WHERE hash = @doc_hash
    |}
            (fun stmt ->
               Seq.iter (fun doc_hash ->
                   bind_names stmt [ ("@doc_hash", TEXT doc_hash) ];
                   step stmt;
                   Hashtbl.add t.doc_id_of_doc_hash doc_hash (column_int64 stmt 0);
                   reset stmt;
                 )
                 doc_hashes
            )
        )
    )

let doc_id_of_doc_hash (doc_hash : string) : int64 =
  let test =
    lock (fun () ->
        Hashtbl.find_opt t.doc_id_of_doc_hash doc_hash
      )
  in
  match test with
  | Some id -> id
  | None -> (
      allocate_bulk (Seq.return doc_hash);
      lock (fun () ->
          Hashtbl.find t.doc_id_of_doc_hash doc_hash
        )
    )
