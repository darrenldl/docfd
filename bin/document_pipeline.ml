let path_queue : (Search_mode.t * string * string) option Eio.Stream.t =
  Eio.Stream.create 100

let ir_queue : Document.ir option Eio.Stream.t = Eio.Stream.create 100

let documents : Document.t Dynarray.t = Dynarray.create ()

let result : Document.t Dynarray.t Eio.Stream.t = Eio.Stream.create 1

let worker_stage0 ~env =
  let open Debug_utils in
  let run = ref true in
  while !run do
    match Eio.Stream.take path_queue with
    | None -> (
        Eio.Stream.add ir_queue None;
        run := false
      )
    | Some (search_mode, doc_hash, path) -> (
        match Document.ir_of_path ~env search_mode ~doc_hash path with
        | Error msg -> (
            do_if_debug (fun oc ->
                Printf.fprintf oc "Error: %s\n" msg
              )
          )
        | Ok ir -> (
            Eio.Stream.add
              ir_queue
              (Some ir)
          )
      )
  done

let worker_stage1 pool =
  let run = ref true in
  while !run do
    match Eio.Stream.take ir_queue with
    | None -> (
        Eio.Stream.add result documents;
        run := false
      )
    | Some ir -> (
        Dynarray.add_last documents (Document.of_ir pool ir)
      )
  done

let feed_document ~env search_mode ~doc_hash path =
  Eio.Stream.add path_queue (Some (search_mode, doc_hash, path))

let finalize () =
  Eio.Stream.add path_queue None;
  Dynarray.to_list (Eio.Stream.take result)
