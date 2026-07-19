include Sqlite3

let requests : (db -> unit) option Eio.Stream.t =
  Eio.Stream.create Int.max_int

let fiber () =
  let db = ref None in
  while true do
    match Eio.Stream.take requests with
    | None -> (
      Option.iter (fun db ->
          let try_count = ref 0 in
          while !try_count < 10 && not (db_close db) do
            Unix.sleepf 0.01;
            incr try_count;
          done
        ) !db
    )
    | Some f -> (
  failwith "test 0";
      db := Some
          (match !db with
           | None -> (
               db_open
                 ~mutex:`FULL
                 (CCOption.get_exn_or "Docfd_lib.Params.db_path uninitialized" !Params.db_path)
             )
           | Some db -> db);
  failwith "test";
      f (Option.get !db)
    )
  done

let close_db () =
  Eio.Stream.add requests None

let with_db : type a. (db -> a) -> a =
  fun f ->
    let waiter, resolver = Eio.Promise.create () in
    let f db =
      let x = f db in
      Eio.Promise.resolve resolver x
    in
    Eio.Stream.add requests (Some f);
    Eio.Promise.await waiter

let retry_if_busy (f : unit -> Sqlite3.Rc.t) =
  let rec aux tries_left =
    let r = f () in
    if tries_left > 0 then (
      match r with
      | BUSY -> (
          Unix.sleepf 0.1;
          aux (tries_left - 1)
        )
      | _ -> r
    ) else (
      r
    )
  in
  aux 50

module Stmt = struct
  let bind_names stmt l =
    retry_if_busy (fun () -> Sqlite3.bind_names stmt l)
    |> Sqlite3.Rc.check

  let reset stmt =
    retry_if_busy (fun () -> Sqlite3.reset stmt)
    |> Sqlite3.Rc.check

  let step stmt =
    match retry_if_busy (fun () -> Sqlite3.step stmt) with
    | OK | DONE | ROW -> ()
    | x -> Sqlite3.Rc.check x

  let iter stmt f =
    Rc.check (Sqlite3.iter stmt ~f)

  let finalize stmt =
    retry_if_busy (fun () -> Sqlite3.finalize stmt)
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
  Option.iter
    (fun names -> Stmt.bind_names stmt names)
    names;
  let res = f stmt in
  Stmt.finalize stmt;
  res

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
