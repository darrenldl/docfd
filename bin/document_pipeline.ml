open Docfd_lib
open Debug_utils

type t = {
  env : Eio_unix.Stdenv.base;
  pool : Task_pool.t;
  ir0_queue : Document.Ir0.t option Eio.Stream.t;
  ir1_of_ir0_workers_batch_release : Eio.Semaphore.t;
  ir1_queue : Document.Ir1.t option Eio.Stream.t;
  ir2_of_ir1_workers_batch_release : Eio.Semaphore.t;
  ir2_queue : Document.Ir2.t option Eio.Stream.t;
  documents : Document.t Dynarray.t;
  result : Document.t Dynarray.t Eio.Stream.t;
}

let make ~env pool : t =
  {
    env;
    pool;
    ir0_queue = Eio.Stream.create 100;
    ir1_of_ir0_workers_batch_release = Eio.Semaphore.make 0;
    ir1_queue = Eio.Stream.create 100;
    ir2_of_ir1_workers_batch_release = Eio.Semaphore.make 0;
    ir2_queue = Eio.Stream.create 100;
    documents = Dynarray.create ();
    result = Eio.Stream.create 1;
  }

let ir1_of_ir0_worker (t : t) =
  let run = ref true in
  while !run do
    match Eio.Stream.take t.ir0_queue with
    | None -> (
        Eio.Semaphore.release t.ir1_of_ir0_workers_batch_release;
        run := false
      )
    | Some ir0 -> (
        match Document.Ir1.of_ir0 ~env:t.env ir0 with
        | Error msg -> (
            do_if_debug (fun oc ->
                Printf.fprintf oc "Error: %s\n" msg
              )
          )
        | Ok ir1 -> (
            Eio.Stream.add t.ir1_queue (Some ir1)
          )
      )
  done

let ir2_of_ir1_worker (t : t) =
  let run = ref true in
  while !run do
    match Eio.Stream.take t.ir1_queue with
    | None -> (
        Eio.Semaphore.release t.ir2_of_ir1_workers_batch_release;
        run := false
      )
    | Some ir -> (
        Eio.Stream.add t.ir2_queue (Some (Document.Ir2.of_ir1 t.pool ir))
      )
  done

let document_of_ir2_worker (t : t) =
  let open Sqlite3_utils in
  let run = ref true in
  let counter = ref 0 in
  let outstanding_transaction = ref false in
  with_db (fun db ->
      while !run do
        if !counter = 0 then (
          step_stmt ~db "BEGIN IMMEDIATE" ignore;
          outstanding_transaction := true;
        );
        (match Eio.Stream.take t.ir2_queue with
         | None -> (
             run := false
           )
         | Some ir -> (
             let doc = Document.of_ir2 db ~already_in_transaction:true ir in
             Dynarray.add_last t.documents doc;
             do_if_debug (fun oc ->
                 Printf.fprintf oc "Document %s loaded successfully\n" (Filename.quote (Document.path doc));
               );
           ));
        if !counter >= 100 then (
          step_stmt ~db "COMMIT" ignore;
          outstanding_transaction := false;
          counter := 0;
        ) else (
          incr counter;
        );
      done;
      if !outstanding_transaction then (
        step_stmt ~db "COMMIT" ignore;
      )
    )

let feed (t : t) search_mode ~doc_hash path =
  do_if_debug (fun oc ->
      Printf.fprintf oc "Loading document: %s\n" (Filename.quote path);
    );
  do_if_debug (fun oc ->
      Printf.fprintf oc "Using %s search mode for document %s\n"
        (match search_mode with
         | `Single_line -> "single line"
         | `Multiline -> "multiline"
        )
        (Filename.quote path)
    );
  match Document.Ir0.of_path ~env:t.env search_mode ~doc_hash path with
  | Error msg -> (
      do_if_debug (fun oc ->
          Printf.fprintf oc "Error: %s\n" msg
        )
    )
  | Ok ir0 -> (
      Eio.Stream.add t.ir0_queue (Some ir0)
    )

let run (t : t) =
  Word_db.read_from_db ();
  Eio.Fiber.all
    (List.concat
       [ CCList.(0 --^ Task_pool.size)
         |> List.map (fun _ -> (fun () -> ir1_of_ir0_worker t))
       ; CCList.(0 --^ Task_pool.size)
         |> List.map (fun _ -> (fun () -> ir2_of_ir1_worker t))
       ; [ fun () -> document_of_ir2_worker t ]
       ]
    );
  Eio.Stream.add t.result t.documents

let finalize (t : t) =
  for _ = 0 to Task_pool.size - 1 do
    Eio.Stream.add t.ir0_queue None;
  done;
  for _ = 0 to Task_pool.size - 1 do
    Eio.Semaphore.acquire t.ir1_of_ir0_workers_batch_release;
  done;
  for _ = 0 to Task_pool.size - 1 do
    Eio.Stream.add t.ir1_queue None;
  done;
  for _ = 0 to Task_pool.size - 1 do
    Eio.Semaphore.acquire t.ir2_of_ir1_workers_batch_release;
  done;
  Eio.Stream.add t.ir2_queue None;
  let res = Dynarray.to_list (Eio.Stream.take t.result) in
  Word_db.write_to_db ();
  res
