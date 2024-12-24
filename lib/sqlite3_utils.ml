include Sqlite3

let mutex = Eio.Mutex.create ()

let use_db : type a. ?no_lock:bool -> ?db:db -> (db -> a) -> a =
  let open Sqlite3 in
  fun ?(no_lock = false) ?db f ->
    let db_path =
      CCOption.get_exn_or "Docfd_lib.Params.db_path uninitialized" !Params.db_path
    in
    let body () =
      let& db =
        match db with
        | Some db -> db
        | None -> db_open db_path
      in
      f db
    in
    if no_lock then (
      body ()
    ) else (
      Eio.Mutex.use_rw ~protect:true mutex body
    )

let exec db s =
  Sqlite3.Rc.check (Sqlite3.exec db s)

let prepare db s =
  Sqlite3.prepare db s

let bind_names stmt l =
  Sqlite3.Rc.check (Sqlite3.bind_names stmt l)

let reset stmt =
  Sqlite3.Rc.check (Sqlite3.reset stmt)

let step stmt =
  match Sqlite3.step stmt with
  | OK | DONE | ROW -> ()
  | x -> Sqlite3.Rc.check x

let finalize stmt =
  Sqlite3.Rc.check (Sqlite3.finalize stmt)

let with_stmt : type a. db -> string -> ?names:((string * Sqlite3.Data.t) list) -> (Sqlite3.stmt -> a) -> a =
  fun db s ?names f ->
  let stmt = prepare db s in
  Option.iter
    (fun names -> bind_names stmt names)
    names;
  let res = f stmt in
  finalize stmt;
  res

let step_stmt : type a. db -> string -> ?names:((string * Data.t) list) -> (stmt -> a) -> a =
  fun db s ?names f ->
  with_stmt db s ?names
    (fun stmt ->
       step stmt;
       f stmt
    )

let iter_stmt db s ?names (f : Data.t array -> unit) =
  with_stmt db s ?names
    (fun stmt ->
       Rc.check (Sqlite3.iter stmt ~f)
    )

let fold_stmt : type a. db -> string -> ?names:((string * Data.t) list) -> (a -> Sqlite3.Data.t array -> a) -> a -> a =
  fun db s ?names f init ->
  with_stmt db s ?names
    (fun stmt ->
       let rc, res = Sqlite3.fold stmt ~f ~init in
       Sqlite3.Rc.check rc;
       res
    )
