include Sqlite3

let prepare s =
  Sqlite3.prepare (Params.get_db ()) s

let bind_names stmt l =
  Sqlite3.Rc.check (Sqlite3.bind_names stmt l)

let finalize stmt =
  Sqlite3.Rc.check (Sqlite3.finalize stmt)

let with_stmt : type a. string -> ?names:((string * Sqlite3.Data.t) list) -> (Sqlite3.stmt -> a) -> a =
  fun s ?names f ->
  let stmt = prepare s in
  Option.iter
  (fun names -> bind_names stmt names)
  names;
  let res = f stmt in
  finalize stmt;
  res

let step_stmt : type a. string -> ?names:((string * Data.t) list) -> (stmt -> a) -> a =
  fun s ?names f ->
  with_stmt s ?names
  (fun stmt ->
    Rc.check (Sqlite3.step stmt);
    f stmt
  )

let iter_stmt s ?names (f : Data.t array -> unit) =
  with_stmt s ?names
  (fun stmt ->
    Rc.check (Sqlite3.iter stmt ~f)
  )

let fold_stmt : type a. string -> ?names:((string * Data.t) list) -> (a -> Sqlite3.Data.t array -> a) -> a -> a =
  fun s ?names f init ->
    with_stmt s ?names
    (fun stmt ->
    let rc, res = Sqlite3.fold stmt ~f ~init in
    Sqlite3.Rc.check rc;
    res
    )
