open Docfd_lib

type t = {
  pool : Task_pool.t;
  stop_signal : Stop_signal.t;
  cancellation_notifier : bool Atomic.t;
  search_exp : Search_exp.t;
  search_job_group_queue : (string * Index.Search_job_group.t) option Eio.Stream.t;
  search_job_group_workers_batch_release : Eio.Semaphore.t;
  search_result_heap_queue : (string * Search_result_heap.t) option Eio.Stream.t;
  search_result_heap_workers_batch_release : Eio.Semaphore.t;
  result : Search_result.t array String_map.t Eio.Stream.t;
}

let make pool stop_signal ~cancellation_notifier search_exp : t =
  {
    pool;
    stop_signal;
    cancellation_notifier;
    search_exp;
    search_job_group_queue = Eio.Stream.create 10;
    search_job_group_workers_batch_release = Eio.Semaphore.make 0;
    search_result_heap_queue = Eio.Stream.create 10;
    search_result_heap_workers_batch_release = Eio.Semaphore.make 0;
    result = Eio.Stream.create 1;
  }

let search_job_group_worker (t : t) =
  let run = ref true in
  while !run do
    match Eio.Stream.take t.search_job_group_queue with
    | None -> (
        Eio.Semaphore.release t.search_job_group_workers_batch_release;
        run := false;
      )
    | Some (path, search_job_group) -> (
        Index.Search_job_group.unpack search_job_group
        |> Seq.map Index.Search_job.run
        |> Seq.iter (fun heap ->
            Eio.Stream.add t.search_result_heap_queue (Some (path, heap))
          )
      )
  done

let search_result_heap_worker (t : t) =
  let run = ref true in
  let acc = ref String_map.empty in
  while !run do
    match Eio.Stream.take t.search_result_heap_queue with
    | None -> (
        Eio.Semaphore.release t.search_result_heap_workers_batch_release;
        run := false;
        String_map.map (fun heap ->
            let arr =
              Search_result_heap.to_seq heap
              |> Array.of_seq
            in
            Array.sort Search_result.compare_relevance arr;
            arr
          ) !acc
        |> Eio.Stream.add t.result;
      )
    | Some (path, heap) -> (
        let heap =
          String_map.find_opt path !acc
          |> Option.value ~default:Search_result_heap.empty
          |> Search_result_heap.merge heap
        in
        acc := String_map.add path heap !acc
      )
  done

let run (t : t) (documents : Document.t Seq.t) =
  let search_job_group_worker_count = max 1 (Task_pool.size - 2) in
  Eio.Fiber.all
    (List.concat
       [
         [ (fun () ->
               Seq.iter (fun doc ->
                   let within_same_line =
                     match Document.search_mode doc with
                     | `Single_line -> true
                     | `Multiline -> false
                   in
                   Index.make_search_job_groups
                     t.stop_signal
                     ~cancellation_notifier:t.cancellation_notifier
                     ~doc_hash:(Document.doc_hash doc)
                     ~within_same_line
                     ~search_scope:(Document.search_scope doc)
                     t.search_exp
                   |> Seq.iter (fun x ->
                       Eio.Stream.add t.search_job_group_queue (Some (Document.path doc, x))
                     )
                 ) documents;
               for _ = 0 to Task_pool.size - 1 do
                 Eio.Stream.add t.search_job_group_queue None;
               done
             )
         ]
       ; CCList.(0 --^ search_job_group_worker_count)
         |> List.map (fun _ -> (fun () ->
             Task_pool.run t.pool (fun () ->
                 search_job_group_worker t)))
       ; [ fun () -> search_result_heap_worker t ]
       ; [ (fun () ->
           for _ = 0 to search_job_group_worker_count - 1 do
             Eio.Semaphore.acquire t.search_job_group_workers_batch_release;
           done;
           Eio.Stream.add t.search_result_heap_queue None;
           Eio.Semaphore.acquire t.search_result_heap_workers_batch_release
         )
         ]
       ]);
  Eio.Stream.take t.result
