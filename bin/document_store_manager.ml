open Docfd_lib

type search_status = [
  | `Idle
  | `Searching
  | `Parse_error
]

type filter_status = [ `Ok | `Parse_error ]

let search_ui_status : search_status Lwd.var = Lwd.var `Idle

let filter_ui_status : filter_status Lwd.var = Lwd.var `Ok

let single_file_view_search_request : string Lock_protected_cell.t =
  Lock_protected_cell.make ()

let search_request : string Lock_protected_cell.t =
  Lock_protected_cell.make ()

let filter_request : string Lock_protected_cell.t =
  Lock_protected_cell.make ()

let single_file_view_update_request : Document_store_snapshot.t Lock_protected_cell.t =
  Lock_protected_cell.make ()

let update_request : Document_store_snapshot.t Lock_protected_cell.t =
  Lock_protected_cell.make ()

let worker_ping : Ping.t = Ping.make ()

let requester_lock = Eio.Mutex.create ()

let requester_ping : Ping.t = Ping.make ()

type egress_payload =
  | Search_exp_parse_error
  | Searching
  | Search_done of Document_store_snapshot.t
  | Filter_glob_parse_error
  | Filtering_done of Document_store_snapshot.t
  | Update of Document_store_snapshot.t

let egress : egress_payload Eio.Stream.t =
  Eio.Stream.create 0

let egress_ack : unit Eio.Stream.t =
  Eio.Stream.create 0

let stop_signal = Atomic.make (Stop_signal.make ())

let signal_stop () =
  let x = Atomic.exchange stop_signal (Stop_signal.make ()) in
  Stop_signal.broadcast x

let document_store_snapshot =
  Lwd.var (Document_store_snapshot.make_empty ())

let manager_fiber () =
  (* This fiber handles updates of Lwd.var which are not thread-safe,
     and thus cannot be done by worker_fiber directly
  *)
  let update_store snapshot =
    Lwd.set document_store_snapshot snapshot;
  in
  while true do
    let payload = Eio.Stream.take egress in
    match payload with
    | Search_exp_parse_error -> (
        Lwd.set search_ui_status `Parse_error
      )
    | Searching -> (
        Lwd.set search_ui_status `Searching
      )
    | Search_done snapshot -> (
        update_store snapshot;
        Lwd.set search_ui_status `Idle
      )
    | Filter_glob_parse_error -> (
        Lwd.set filter_ui_status `Parse_error
      )
    | Filtering_done snapshot -> (
        update_store snapshot;
        Lwd.set search_ui_status `Idle;
        Lwd.set filter_ui_status `Ok
      )
    | Update snapshot -> (
        update_store snapshot;
        Lwd.set search_ui_status `Idle;
        Lwd.set filter_ui_status `Ok;
        Eio.Stream.add egress_ack ();
      )
  done

let worker_fiber pool =
  (* This fiber runs in a background domain to allow the UI code in the main
     domain to immediately continue running after key presses that trigger
     searches or search cancellations.

     This removes the need to make the code of document store always yield
     frequently.
  *)
  let store_snapshot =
    ref (Document_store_snapshot.make_empty ())
  in
  let process_search_req stop_signal (s : string) =
    match Search_exp.parse s with
    | None -> (
        Eio.Stream.add egress Search_exp_parse_error
      )
    | Some search_exp -> (
        Eio.Stream.add egress Searching;
        let store =
          !store_snapshot
          |> Document_store_snapshot.store
          |> Document_store.update_search_exp
            pool
            stop_signal
            s
            search_exp
        in
        let command = Some (`Search s) in
        let snapshot = Document_store_snapshot.make ~last_command:command store in
        store_snapshot := snapshot;
        Eio.Stream.add egress (Search_done snapshot)
      )
  in
  let process_filter_req stop_signal (s : string) =
    match Query_exp.parse s with
    | Some filter -> (
        Eio.Stream.add egress Searching;
        let store =
          !store_snapshot
          |> Document_store_snapshot.store
          |> Document_store.update_filter
            pool
            stop_signal
            s
            filter
        in
        let command = Some (`Filter s) in
        let snapshot = Document_store_snapshot.make ~last_command:command store in
        store_snapshot := snapshot;
        Eio.Stream.add egress (Filtering_done snapshot)
      )
    | None -> (
        Eio.Stream.add egress Filter_glob_parse_error
      )
  in
  let process_update_req snapshot =
    store_snapshot := snapshot;
    Eio.Stream.add egress (Update snapshot);
    Eio.Stream.take egress_ack;
  in
  while true do
    Ping.wait worker_ping;
    Ping.clear requester_ping;
    let stop_signal' = Atomic.get stop_signal in
    (match Lock_protected_cell.get filter_request with
     | None -> ()
     | Some s -> process_filter_req stop_signal' s
    );
    (match Lock_protected_cell.get search_request with
     | None -> ()
     | Some s -> process_search_req stop_signal' s
    );
    (match Lock_protected_cell.get update_request with
     | None -> ()
     | Some snapshot -> process_update_req snapshot
    );
    Ping.ping requester_ping
  done

let submit_filter_req (s : string) =
  Eio.Mutex.use_rw requester_lock ~protect:false (fun () ->
      signal_stop ();
      Lock_protected_cell.set filter_request s;
      Ping.ping worker_ping
    )

let submit_search_req (s : string) =
  Eio.Mutex.use_rw requester_lock ~protect:false (fun () ->
      signal_stop ();
      Lock_protected_cell.set search_request s;
      Ping.ping worker_ping
    )

let submit_update_req snapshot =
  Eio.Mutex.use_rw requester_lock ~protect:false (fun () ->
      signal_stop ();
      Lock_protected_cell.unset search_request;
      Lock_protected_cell.unset filter_request;
      Lock_protected_cell.set update_request snapshot;
      Ping.clear requester_ping;
      Ping.ping worker_ping;
      Ping.wait requester_ping
    )
