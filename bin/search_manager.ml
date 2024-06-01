open Docfd_lib

type status = [
  | `Idle
  | `Searching
  | `Parse_error
]

type request =
  | Search of string * Document_store.t * Document_store.t Lwd.var
  | Update of Document_store.t * Document_store.t Lwd.var

let ui_status : status Lwd.var = Lwd.var `Idle

let internal_status_mailbox : status Eio.Stream.t = Eio.Stream.create 1

let ingress : request Eio.Stream.t =
  Eio.Stream.create 0

let egress_mailbox : (Document_store.t * Document_store.t Lwd.var) Eio.Stream.t =
  Eio.Stream.create 1

let stop_signal = Atomic.make (Stop_signal.make ())

let stop_signal_swap_completed : unit Eio.Stream.t = Eio.Stream.create 0

let store_update_lock = Eio.Mutex.create ()

let manager_fiber () =
  while true do
    let status = Eio.Stream.take internal_status_mailbox in
    (match status with
     | `Idle -> (
         let (document_store, document_store_var) = Eio.Stream.take egress_mailbox in
         Eio.Mutex.use_rw store_update_lock ~protect:false (fun () ->
             Lwd.set document_store_var document_store;
           )
       )
     | _ -> ());
    Lwd.set ui_status status
  done

let search_fiber pool =
  (* This fiber runs in a background domain to allow the UI code in the main
     domain to immediately continue running after key presses that trigger
     searches or search cancellations.

     This removes the need to make the code of document store always yield
     frequently.
  *)
  while true do
    let req = Eio.Stream.take ingress in
    let stop_signal' = Stop_signal.make () in
    Atomic.set stop_signal stop_signal';
    Eio.Stream.add stop_signal_swap_completed ();
    match req with
    | Search (s, document_store, document_store_var) -> (
        match
          Search_exp.make
            ~max_fuzzy_edit_dist:!Params.max_fuzzy_edit_dist
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
      )
    | Update (document_store, document_store_var) -> (
        Eio.Stream.add internal_status_mailbox `Idle;
        Eio.Stream.add egress_mailbox (document_store, document_store_var)
      )
  done

let submit_search_req (s : string) (store_var : Document_store.t Lwd.var) =
  Eio.Mutex.use_rw store_update_lock ~protect:false (fun () ->
      let store = Lwd.peek store_var in
      Stop_signal.broadcast (Atomic.get stop_signal);
      Eio.Stream.add ingress (Search (s, store, store_var));
      Eio.Stream.take stop_signal_swap_completed;
    )

let submit_update_req (store : Document_store.t) (store_var : Document_store.t Lwd.var) =
  Eio.Mutex.use_rw store_update_lock ~protect:false (fun () ->
      Stop_signal.broadcast (Atomic.get stop_signal);
      Eio.Stream.add ingress (Update (store, store_var));
      Eio.Stream.take stop_signal_swap_completed;
    )
