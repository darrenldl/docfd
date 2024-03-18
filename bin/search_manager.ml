open Docfd_lib

type status = [
  | `Idle
  | `Searching
  | `Parse_error
]

let status : status Lwd.var = Lwd.var `Idle

let status_mailbox : status Eio.Stream.t = Eio.Stream.create 1

let ingress_queue : (string * Document_store.t Lwd.var) Eio.Stream.t =
  Eio.Stream.create 128

let egress_queue : (Document_store.t * Document_store.t Lwd.var) Eio.Stream.t =
  Eio.Stream.create 1

let cancel_mailbox : unit Eio.Stream.t = Eio.Stream.create 1

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
         Lwd.set status (Eio.Stream.take status_mailbox)
       done)
    (fun () ->
       while true do
         let (document_store, document_store_var) = Eio.Stream.take egress_queue in
         Lwd.set document_store_var document_store;
         Lwd.set status `Idle;
       done)

let search_fiber () =
  let rec aux () =
    let (s, document_store_var) = get_newest ingress_queue in
    (match
       Search_exp.make
         ~fuzzy_max_edit_distance:!Params.max_fuzzy_edit_distance
         s
     with
     | None -> (
         Eio.Stream.add status_mailbox `Parse_error
       )
     | Some search_exp -> (
         Eio.Fiber.first
           (fun () ->
              Eio.Stream.take cancel_mailbox
           )
           (fun () ->
              Eio.Stream.add status_mailbox `Searching;
              let document_store =
                Lwd.peek document_store_var
                |> Document_store.update_search_exp search_exp
              in
              Eio.Stream.add egress_queue (document_store, document_store_var))
       )
    );
    aux ()
  in
  aux ()

let submit_search_req (s : string) (store : Document_store.t Lwd.var) =
  Eio.Stream.add ingress_queue (s, store)
