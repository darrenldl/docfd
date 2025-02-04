include Sqlite3

let db_pool =
  Eio.Pool.create
    (* This is not ideal since validate is not called until next use of the
       pool, so an idle DB connection could be held for a lot longer than
       described here. But this seems to be the best we can do.
    *)
    ~validate:(fun (last_used, _db) ->
        Unix.time () -. !last_used <= 30.0
      )
    ~dispose:(fun (_last_used, db) ->
        while not (db_close db) do Unix.sleepf 0.01 done
      )
    Task_pool.size
    (fun () ->
       (ref (Unix.time ()),
        db_open
          ~mutex:`FULL
          (CCOption.get_exn_or "Docfd_lib.Params.db_path uninitialized" !Params.db_path)
       )
    )

let with_db : type a. ?db:db -> (db -> a) -> a =
  fun ?db f ->
  match db with
  | None -> (
      Eio.Pool.use db_pool (fun (last_used, db) ->
          last_used := Unix.time ();
          f db
        )
    )
  | Some db -> (
      f db
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

let with_stmt : type a. ?db:db -> string -> ?names:((string * Sqlite3.Data.t) list) -> (Sqlite3.stmt -> a) -> a =
  fun ?db s ?names f ->
  with_db ?db (fun db ->
      let stmt = prepare db s in
      Option.iter
        (fun names -> bind_names stmt names)
        names;
      let res = f stmt in
      finalize stmt;
      res
    )

let step_stmt : type a. ?db:db -> string -> ?names:((string * Data.t) list) -> (stmt -> a) -> a =
  fun ?db s ?names f ->
  with_stmt ?db s ?names
    (fun stmt ->
       step stmt;
       f stmt
    )

let iter_stmt ?db s ?names (f : Data.t array -> unit) =
  with_stmt ?db s ?names
    (fun stmt ->
       Rc.check (Sqlite3.iter stmt ~f)
    )

let fold_stmt : type a. ?db:db -> string -> ?names:((string * Data.t) list) -> (a -> Sqlite3.Data.t array -> a) -> a -> a =
  fun ?db s ?names f init ->
  with_stmt ?db s ?names
    (fun stmt ->
       let rc, res = Sqlite3.fold stmt ~f ~init in
       Sqlite3.Rc.check rc;
       res
    )
