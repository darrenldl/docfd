open Docfd_lib

type status = [
  | `Idle
  | `Searching
  | `Parse_error
]

let status : status Lwd.var = Lwd.var `Idle

let internal_status_mailbox : status Eio.Stream.t = Eio.Stream.create 1

let ui_status_mailbox : status Eio.Stream.t = Eio.Stream.create 1

let ingress_queue : (string * Document_store.t Lwd.var) Eio.Stream.t =
  Eio.Stream.create 100

let egress_mailbox : (Document_store.t * Document_store.t Lwd.var) Eio.Stream.t =
  Eio.Stream.create 1

let cancel_req : unit Eio.Stream.t = Eio.Stream.create 0

let cancel_ack : unit Eio.Stream.t = Eio.Stream.create 0

let get_newest queue =
  let rec aux item =
    match Eio.Stream.take_nonblocking queue with
    | None -> (
        match item with
        | None -> Eio.Stream.take queue
        | Some x -> x
      )
    | Some x -> aux (Some x)
  in
  aux None

let manager_fiber () =
  Eio.Fiber.both
    (fun () ->
       while true do
         Lwd.set status (Eio.Stream.take ui_status_mailbox)
       done)
    (fun () ->
       while true do
         let status = Eio.Stream.take internal_status_mailbox in
         match status with
         | `Searching | `Parse_error -> (
             Eio.Stream.add ui_status_mailbox status;
           )
         | `Idle -> (
             let (document_store, document_store_var) = Eio.Stream.take egress_mailbox in
             Lwd.set document_store_var document_store;
             Eio.Stream.add ui_status_mailbox `Idle;
           )
       done)

let search_fiber pool =
  let rec aux () =
    let stop_signal = Stop_signal.make () in
    let canceled =
      Eio.Fiber.first
        (fun () ->
           Eio.Stream.take cancel_req;
           Stop_signal.broadcast stop_signal;
           true
        )
        (fun () ->
           let (s, document_store_var) = get_newest ingress_queue in
           (match
              Search_exp.make
                ~fuzzy_max_edit_distance:!Params.max_fuzzy_edit_distance
                s
            with
            | None -> (
                Eio.Stream.add internal_status_mailbox `Parse_error
              )
            | Some search_exp -> (
                Eio.Stream.add internal_status_mailbox `Searching;
                let document_store =
                  Lwd.peek document_store_var
                  |> Document_store.update_search_exp pool stop_signal search_exp
                in
                Eio.Stream.add internal_status_mailbox `Idle;
                Eio.Stream.add egress_mailbox (document_store, document_store_var)
              )
           );
           false
        )
    in
    if canceled then (
      Eio.Stream.add cancel_ack ()
    );
    aux ()
  in
  aux ()

let submit_search_req (s : string) (store : Document_store.t Lwd.var) =
  Eio.Stream.add cancel_req ();
  Eio.Stream.take cancel_ack;
  Eio.Stream.add ingress_queue (s, store)
