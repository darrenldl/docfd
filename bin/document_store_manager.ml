open Docfd_lib

type store_typ = [
  | `Multi_file_view
  | `Single_file_view
]

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

let multi_file_view_search_request : string Lock_protected_cell.t =
  Lock_protected_cell.make ()

let single_file_view_filter_request : string Lock_protected_cell.t =
  Lock_protected_cell.make ()

let multi_file_view_filter_request : string Lock_protected_cell.t =
  Lock_protected_cell.make ()

type synchronous_op = [
  | `Update of Document_store_snapshot.t
  | `Update_starting_snapshot of Document_store_snapshot.t
  | `Take_snapshot
  | `Take_snapshot_if_input_fields_changed
  | `Switch_version of int
]

let single_file_view_synchronous_op_request : synchronous_op Lock_protected_cell.t =
  Lock_protected_cell.make ()

let multi_file_view_synchronous_op_request : synchronous_op Lock_protected_cell.t =
  Lock_protected_cell.make ()

let multi_file_view_snapshot_request : Document_store_snapshot.t Lock_protected_cell.t =
  Lock_protected_cell.make ()

let request_lock = Eio.Mutex.create ()

let worker_ping : Ping.t = Ping.make ()

let requester_ping : Ping.t = Ping.make ()

type egress_payload =
  | Search_exp_parse_error
  | Searching
  | Search_done of store_typ * Document_store_snapshot.t
  | Filter_glob_parse_error
  | Filtering_done of store_typ * Document_store_snapshot.t
  | Update of store_typ * int option * Document_store_snapshot.t

let egress : egress_payload Eio.Stream.t =
  Eio.Stream.create 0

let egress_ack : unit Eio.Stream.t =
  Eio.Stream.create 0

let search_stop_signal = Atomic.make (Stop_signal.make ())

let signal_search_stop () =
  let x = Atomic.exchange search_stop_signal (Stop_signal.make ()) in
  Stop_signal.broadcast x

let single_file_view_store_snapshot = Lwd.var Document_store_snapshot.empty

let single_file_view_store_cur_ver = Lwd.var 0

let multi_file_view_store_snapshot = Lwd.var Document_store_snapshot.empty

let multi_file_view_store_cur_ver = Lwd.var 0

let single_file_view_store_snapshots = Dynarray.create ()

let multi_file_view_store_snapshots = Dynarray.create ()

let manager_fiber () =
  (* This fiber handles updates of Lwd.var which are not thread-safe,
     and thus cannot be done by worker_fiber directly
  *)
  let update_store (store_typ : store_typ) ver snapshot =
    match store_typ with
    | `Multi_file_view -> (
        Lwd.set multi_file_view_store_snapshot snapshot;
        Option.iter (fun ver ->
            Lwd.set multi_file_view_store_cur_ver ver)
          ver;
      )
    | `Single_file_view -> (
        Lwd.set single_file_view_store_snapshot snapshot;
        Option.iter (fun ver ->
            Lwd.set single_file_view_store_cur_ver ver)
          ver;
      )
  in
  while true do
    let payload = Eio.Stream.take egress in
    (match payload with
    | Search_exp_parse_error -> (
        Lwd.set search_ui_status `Parse_error
      )
    | Searching -> (
        Lwd.set search_ui_status `Searching
      )
    | Search_done (store_typ, snapshot) -> (
        update_store store_typ None snapshot;
        Lwd.set search_ui_status `Idle
      )
    | Filter_glob_parse_error -> (
        Lwd.set filter_ui_status `Parse_error
      )
    | Filtering_done (store_typ, snapshot) -> (
        update_store store_typ None snapshot;
        Lwd.set filter_ui_status `Ok
      )
    | Update (store_typ, ver, snapshot) -> (
        update_store store_typ ver snapshot;
    ));
    Eio.Stream.add egress_ack ();
  done

let worker_fiber pool =
  (* This fiber runs in a background domain to allow the UI code in the main
     domain to immediately continue running after key presses that trigger
     searches or search cancellations.

     This removes the need to make the code of document store always yield
     frequently.
  *)
  Dynarray.set single_file_view_store_snapshots 0 Document_store_snapshot.empty;
  let single_file_view_store_ver = ref 0 in
  Dynarray.set multi_file_view_store_snapshots 0 Document_store_snapshot.empty;
  let multi_file_view_store_ver = ref 0 in
  let process_search_req search_stop_signal (store_typ : store_typ) (s : string) =
    match Search_exp.make s with
    | None -> (
        Eio.Stream.add egress Search_exp_parse_error
      )
    | Some search_exp -> (
        Eio.Stream.add egress Searching;
        let store =
          (match store_typ with
           | `Single_file_view ->
             Dynarray.get
               single_file_view_store_snapshots
               !single_file_view_store_ver
           | `Multi_file_view ->
             Dynarray.get
               multi_file_view_store_snapshots
               !multi_file_view_store_ver)
          |> (fun x -> x.store)
          |> Document_store.update_search_exp
            pool
            search_stop_signal
            s
            search_exp
        in
        let action = Some (`Search s) in
        let snapshot = Document_store_snapshot.make action store in
        (match store_typ with
         | `Single_file_view ->
           Dynarray.set
             single_file_view_store_snapshots
             !single_file_view_store_ver
             snapshot
         | `Multi_file_view ->
           Dynarray.set
             multi_file_view_store_snapshots
             !multi_file_view_store_ver
             snapshot);
        Eio.Stream.add egress (Search_done (store_typ, snapshot))
      )
  in
  let process_filter_req search_stop_signal (store_typ : store_typ) (original_string : string) =
    let s = Misc_utils.normalize_filter_glob_if_not_empty original_string in
    match Glob.make s with
    | Some glob -> (
        let store =
          (match store_typ with
           | `Single_file_view ->
             Dynarray.get
               single_file_view_store_snapshots
               !single_file_view_store_ver
           | `Multi_file_view ->
             Dynarray.get
               multi_file_view_store_snapshots
               !multi_file_view_store_ver)
          |> (fun x -> x.store)
          |> Document_store.update_file_path_filter_glob
            pool
            search_stop_signal
            original_string
            glob
        in
        let action = Some (`Filter original_string) in
        let snapshot = Document_store_snapshot.make action store in
        (match store_typ with
         | `Single_file_view ->
           Dynarray.set
             single_file_view_store_snapshots
             !single_file_view_store_ver
             snapshot
         | `Multi_file_view ->
           Dynarray.set
             multi_file_view_store_snapshots
             !multi_file_view_store_ver
             snapshot);
        Dynarray.truncate snapshots (!cur_ver + 1);
        Eio.Stream.add egress (Filtering_done (store_typ, snapshot))
      )
    | None -> (
        Eio.Stream.add egress Filter_glob_parse_error
      )
  in
  let process_synchronous_op_req (store_typ : store_typ) (x : synchronous_op) =
    let snapshots, cur_ver =
      match store_typ with
      | `Single_file_view ->
        (single_file_view_store_snapshots, single_file_view_store_ver)
      | `Multi_file_view ->
        (multi_file_view_store_snapshots, multi_file_view_store_ver)
    in
  let take_snapshot () =
      let cur_snapshot = Dynarray.get snapshots !cur_ver in
      Dynarray.add_last snapshots cur_snapshot;
      cur_ver := !cur_ver + 1;
      Eio.Stream.add egress (Update (store_typ, Some !cur_ver, cur_snapshot))
    in
    match x with
    | `Update snapshot -> (
        Dynarray.set
          snapshots
          !multi_file_view_store_ver
          snapshot;
        Eio.Stream.add egress (Update (store_typ, None, snapshot))
      )
    | `Update_starting_snapshot starting_snapshot -> (
      let pool = Global_vars.task_pool () in
  Dynarray.set snapshots 0 starting_snapshot;
  for i=1 to Dynarray.length snapshots - 1 do
    let prev = Dynarray.get snapshots (i - 1) in
    let cur = Dynarray.get snapshots i in
    let store =
      match cur.last_action with
      | None -> prev.store
      | Some action ->
        Option.value ~default:prev.store
          (Document_store.play_action pool action prev.store)
    in
    Dynarray.set snapshots i Document_store_snapshot.{ cur with store }
  done;
    )
    | `Take_snapshot -> (
      take_snapshot ()
      )
    | `Take_snapshot_if_input_fields_changed -> (
      if !cur_ver = 0 then (
        take_snapshot ()
      ) else (
      let cur_snapshot = Dynarray.get snapshots !cur_ver in
    let prev_snapshot =
      Dynarray.get snapshots (!cur_ver - 1)
    in
    let filter_changed =
      Document_store.file_path_filter_glob_string prev_snapshot.store
      <> Document_store.file_path_filter_glob_string cur_snapshot.store
    in
    let search_changed =
      Document_store.search_exp_string prev_snapshot.store
      <> Document_store.search_exp_string cur_snapshot.store
    in
    if filter_changed || search_changed then (
      take_snapshot ()
    )
      )
    )
    | `Switch_version x -> (
        if 0 <= x && x < Dynarray.length snapshots then (
          let cur_snapshot = Dynarray.get snapshots !cur_ver in
          cur_ver := x;
          Eio.Stream.add egress (Update (store_typ, Some !cur_ver, cur_snapshot))
        )
      )
  in
  while true do
    Ping.wait worker_ping;
    Ping.clear requester_ping;
    let search_stop_signal' = Atomic.get search_stop_signal in
    (match Lock_protected_cell.get single_file_view_filter_request with
     | None -> ()
     | Some s -> process_filter_req search_stop_signal' `Single_file_view s
    );
    (match Lock_protected_cell.get multi_file_view_filter_request with
     | None -> ()
     | Some s -> process_filter_req search_stop_signal' `Multi_file_view s
    );
    (match Lock_protected_cell.get single_file_view_search_request with
     | None -> ()
     | Some s -> process_search_req search_stop_signal' `Single_file_view s
    );
    (match Lock_protected_cell.get multi_file_view_search_request with
     | None -> ()
     | Some s -> process_search_req search_stop_signal' `Multi_file_view s
    );
    (match Lock_protected_cell.get single_file_view_synchronous_op_request with
     | None -> ()
     | Some req -> process_synchronous_op_req `Single_file_view req
    );
    (match Lock_protected_cell.get multi_file_view_synchronous_op_request with
     | None -> ()
     | Some req -> process_synchronous_op_req `Multi_file_view req
    );
    Eio.Stream.take egress_ack;
    Ping.ping requester_ping
  done

let submit_filter_req (store_typ : store_typ) (s : string) =
  Eio.Mutex.use_rw request_lock ~protect:false (fun () ->
      signal_search_stop ();
      (match store_typ with
       | `Multi_file_view -> (
           Lock_protected_cell.set multi_file_view_filter_request s;
         )
       | `Single_file_view -> (
           Lock_protected_cell.set single_file_view_filter_request s;
         )
      );
      Ping.ping worker_ping
    )

let submit_search_req (store_typ : store_typ) (s : string) =
  Eio.Mutex.use_rw request_lock ~protect:false (fun () ->
      signal_search_stop ();
      (match store_typ with
       | `Multi_file_view -> (
           Lock_protected_cell.set multi_file_view_search_request s;
         )
       | `Single_file_view -> (
           Lock_protected_cell.set single_file_view_search_request s;
         )
      );
      Ping.ping worker_ping
    )

let submit_synchronous_op_req store_typ op =
  Eio.Mutex.use_rw request_lock ~protect:false (fun () ->
      signal_search_stop ();
      (match store_typ with
       | `Multi_file_view -> (
           Lock_protected_cell.unset multi_file_view_search_request;
           Lock_protected_cell.unset multi_file_view_filter_request;
           Lock_protected_cell.set multi_file_view_synchronous_op_request op;
         )
       | `Single_file_view -> (
           Lock_protected_cell.unset single_file_view_search_request;
           Lock_protected_cell.unset single_file_view_filter_request;
           Lock_protected_cell.set single_file_view_synchronous_op_request op;
         )
      );
      Ping.clear requester_ping;
      Ping.ping worker_ping;
      Ping.wait requester_ping
    )

let submit_update_req (store_typ : store_typ) snapshot =
  submit_synchronous_op_req store_typ (`Update snapshot)

let submit_update_starting_snapshot_req (store_typ : store_typ) snapshot =
  submit_synchronous_op_req store_typ (`Update_starting_snapshot snapshot)

let submit_snapshot_req (store_typ : store_typ) =
  submit_synchronous_op_req store_typ `Take_snapshot

let submit_snapshot_if_input_fields_changed_req (store_typ : store_typ) =
  submit_synchronous_op_req store_typ `Take_snapshot_if_input_fields_changed

let submit_switch_version_req (store_typ : store_typ) x =
  submit_synchronous_op_req store_typ (`Switch_version x)
