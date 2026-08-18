include Sqlite3

type t = {
  free : Sqlite3.db Dynarray.t;
  lock : Eio.Mutex.t;
}

let t : t = {
  free = Dynarray.create ();
  lock = Eio.Mutex.create ();
}

let close_db () =
  Eio.Mutex.use_rw ~protect:true t.lock (fun () ->
      Dynarray.iter (fun db ->
          let try_count = ref 0 in
          while !try_count < 10 && not (db_close db) do
            Unix.sleepf 0.1;
            incr try_count;
          done
        ) t.free
    )

let with_db : type a. (db -> a) -> a =
  fun f ->
  let db =
    Eio.Mutex.use_rw ~protect:true t.lock (fun () ->
        match Dynarray.pop_last_opt t.free with
        | None -> (
            db_open
              ~mutex:`FULL
              (CCOption.get_exn_or "Docfd_lib.Params.db_path uninitialized" !Params.db_path)
          )
        | Some db -> db
      )
  in
  let return_to_pool () =
    Eio.Mutex.use_rw ~protect:true t.lock (fun () ->
        Dynarray.add_last t.free db
      )
  in
  match f db with
  | res -> (
      return_to_pool ();
      res
    )
  | exception exn -> (
      let backtrace = Printexc.get_raw_backtrace () in
      (* The callback may have left a transaction open. Do not make that
         connection available to another caller. Roll back and close it on a
         best-effort basis while preserving the callback's exception.
      *)
      (try ignore (Sqlite3.exec db "ROLLBACK") with _ -> ());
      (try ignore (Sqlite3.db_close db) with _ -> ());
      Printexc.raise_with_backtrace exn backtrace
    )

let retry_if_busy (f : unit -> Sqlite3.Rc.t) =
  let rec aux () =
    let r = f () in
    match r with
    | BUSY -> (
        Unix.sleepf (0.1 +. Random.float 0.1);
        aux ()
      )
    | _ -> r
  in
  aux ()

module Stmt = struct
  let bind_names stmt l =
    Sqlite3.bind_names stmt l
    |> Sqlite3.Rc.check

  let reset stmt =
    Sqlite3.reset stmt
    |> Sqlite3.Rc.check

  let step stmt =
    match retry_if_busy (fun () -> Sqlite3.step stmt) with
    | OK | DONE | ROW -> ()
    | x -> Sqlite3.Rc.check x

  let iter stmt f =
    Rc.check (Sqlite3.iter stmt ~f)

  let finalize stmt =
    Sqlite3.finalize stmt
    |> Sqlite3.Rc.check

  let column_int64 = Sqlite3.column_int64

  let column_int = Sqlite3.column_int

  let column_text = Sqlite3.column_text

  let data_count = Sqlite3.data_count
end

let exec db s =
  retry_if_busy (fun () -> Sqlite3.exec db s)
  |> Sqlite3.Rc.check

let with_stmt : type a. db -> string -> ?names:((string * Sqlite3.Data.t) list) -> (Sqlite3.stmt -> a) -> a =
  fun db s ?names f ->
  let stmt = prepare db s in
  match
    Option.iter
      (fun names -> Stmt.bind_names stmt names)
      names;
    f stmt
  with
  | res -> (
      Stmt.finalize stmt;
      res
    )
  | exception exn -> (
      let backtrace = Printexc.get_raw_backtrace () in
      (* A cleanup failure should not hide the exception raised while binding or
         using the statement.
      *)
      (try Stmt.finalize stmt with _ -> ());
      Printexc.raise_with_backtrace exn backtrace
    )

let step_stmt : type a. db -> string -> ?names:((string * Data.t) list) -> (stmt -> a) -> a =
  fun db s ?names f ->
  with_stmt db s ?names
    (fun stmt ->
       Stmt.step stmt;
       f stmt
    )

let iter_stmt db s ?names (f : Data.t array -> unit) =
  with_stmt db s ?names
    (fun stmt ->
       Stmt.iter stmt f
    )

let fold_stmt : type a. db -> string -> ?names:((string * Data.t) list) -> (a -> Sqlite3.Data.t array -> a) -> a -> a =
  fun db s ?names f init ->
  with_stmt db s ?names
    (fun stmt ->
       let rc, res = Sqlite3.fold stmt ~f ~init in
       Sqlite3.Rc.check rc;
       res
    )
