open Docfd_lib
open Debug_utils

type t = {
  env : Eio_unix.Stdenv.base;
  pool : Task_pool.t;
  ir0_queue : Document.Ir0.t option Eio.Stream.t;
  ir1_queue : Document.Ir1.t option Eio.Stream.t;
  ir2_queue : Document.Ir2.t option Eio.Stream.t;
  documents : Document.t Dynarray.t;
  result : Document.t Dynarray.t Eio.Stream.t;
  lock : Eio.Mutex.t;
}

let make ~env pool : t =
  {
    env;
    pool;
    ir0_queue = Eio.Stream.create 100;
    ir1_queue = Eio.Stream.create 100;
    ir2_queue = Eio.Stream.create 100;
    documents = Dynarray.create ();
    result = Eio.Stream.create 1;
    lock = Eio.Mutex.create ();
  }

let ir1_of_ir0_worker (t : t) =
  let run = ref true in
  while !run do
    match Eio.Stream.take t.ir0_queue with
    | None -> (
        Eio.Stream.add t.ir0_queue None;
        Eio.Stream.add t.ir1_queue None;
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
      )
  done

let ir2_of_ir1_worker (t : t) =
  let run = ref true in
  while !run do
    match Eio.Stream.take t.ir1_queue with
    | None -> (
        Eio.Stream.add t.ir2_queue None;
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
  with_db (fun db ->
      while !run do
        if !counter = 0 then (
          step_stmt ~db "BEGIN IMMEDIATE" ignore;
        );
        (match Eio.Stream.take t.ir2_queue with
         | None -> (
             run := false
           )
         | Some ir -> (
             Eio.Mutex.use_rw t.lock ~protect:true (fun () ->
                 Dynarray.add_last t.documents (Document.of_ir2 db ir)
               )
           ));
        if !counter >= 100 then (
          step_stmt ~db "COMMIT" ignore;
          counter := 0;
        ) else (
          incr counter;
        );
      done;
    )

let feed (t : t) search_mode ~doc_hash path =
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
  Eio.Fiber.all
    (List.concat
       [ CCList.(0 --^ Task_pool.size)
         |> List.map (fun _ -> (fun () -> ir1_of_ir0_worker t))
       ; CCList.(0 --^ Task_pool.size)
         |> List.map (fun _ -> (fun () -> ir2_of_ir1_worker t))
       ; CCList.(0 --^ 1)
         |> List.map (fun _ -> (fun () -> document_of_ir2_worker t))
       ]
    );
  Eio.Stream.add t.result t.documents

let finalize (t : t) =
  Eio.Stream.add t.ir0_queue None;
  Dynarray.to_list (Eio.Stream.take t.result)
