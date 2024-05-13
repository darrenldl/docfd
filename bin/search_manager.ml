open Docfd_lib

type status = [
  | `Idle
  | `Searching
  | `Parse_error
]

let ui_status : status Lwd.var = Lwd.var `Idle

let internal_status_mailbox : status Eio.Stream.t = Eio.Stream.create 1

let ingress : (string * Document_store.t * Document_store.t Lwd.var) Eio.Stream.t =
  Eio.Stream.create 0

let egress_mailbox : (Document_store.t * Document_store.t Lwd.var) Eio.Stream.t =
  Eio.Stream.create 1

let stop_signal = Atomic.make (Stop_signal.make ())

let stop_signal_swap_completed : unit Eio.Stream.t = Eio.Stream.create 0

let manager_fiber () =
  while true do
    let status = Eio.Stream.take internal_status_mailbox in
    (match status with
     | `Idle -> (
         let (document_store, document_store_var) = Eio.Stream.take egress_mailbox in
         Lwd.set document_store_var document_store;
       )
     | _ -> ());
    Lwd.set ui_status status
  done

let search_fiber pool =
  (* This fiber runs in a background domain to allow the UI code in the main
     domain to immediately continue running after key presses that trigger
     searches or search cancellations.

     This is mainly to remove the need to structure document store operations
     to always yield frequently.
  *)
  while true do
    let (s, document_store, document_store_var) = Eio.Stream.take ingress in
    let stop_signal' = Stop_signal.make () in
    Atomic.set stop_signal stop_signal';
    Eio.Stream.add stop_signal_swap_completed ();
    match
      Search_exp.make
        ~fuzzy_max_edit_dist:!Params.max_fuzzy_edit_dist
        s
    with
    | None -> (
        Eio.Stream.add internal_status_mailbox `Parse_error
      )
    | Some search_exp -> (
        Eio.Stream.add internal_status_mailbox `Searching;
        let document_store =
          document_store
          |> Document_store.update_search_exp pool stop_signal' search_exp
        in
        Eio.Stream.add internal_status_mailbox `Idle;
        Eio.Stream.add egress_mailbox (document_store, document_store_var)
      )
  done

let submit_search_req =
  let req_lock = Eio.Mutex.create () in
  fun
    (s : string)
    (store_var : Document_store.t Lwd.var) ->
    let store = Lwd.peek store_var in
    Eio.Mutex.use_rw req_lock ~protect:false (fun () ->
        Stop_signal.broadcast (Atomic.get stop_signal);
        Eio.Stream.add ingress (s, store, store_var);
        Eio.Stream.take stop_signal_swap_completed;
      )
