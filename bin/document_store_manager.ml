open Docfd_lib

let single_file_view_search_request : string Lock_protected_cell.t =
  Lock_protected_cell.make ()

let search_request : (bool * string) Lock_protected_cell.t =
  Lock_protected_cell.make ()

let filter_request : (bool * string) Lock_protected_cell.t =
  Lock_protected_cell.make ()

let version_shift_request : int Lock_protected_cell.t =
  Lock_protected_cell.make ()

let update_request : (Document_store_snapshot.t -> Document_store_snapshot.t) Lock_protected_cell.t =
  Lock_protected_cell.make ()

let update_request_completion_ack : unit Eio.Stream.t =
  Eio.Stream.create 0

let worker_ping : Ping.t = Ping.make ()

let _requester_lock = Eio.Mutex.create ()

let lock_as_requester : type a. (unit -> a) -> a =
  fun f ->
  Eio.Mutex.use_rw ~protect:false _requester_lock f

(* let requester_ping : Ping.t = Ping.make () *)

type egress_payload =
  | Search_exp_parse_error
  | Searching
  | Search_cancelled
  | Search_done of int * Document_store_snapshot.t
  | Filter_glob_parse_error
  | Filtering
  | Filtering_cancelled
  | Filtering_done of int * Document_store_snapshot.t
  | Update of int * Document_store_snapshot.t

let egress : egress_payload Eio.Stream.t =
  Eio.Stream.create 0

let egress_ack : unit Eio.Stream.t =
  Eio.Stream.create 0

let stop_filter_signal = Atomic.make (Stop_signal.make ())

let stop_search_signal = Atomic.make (Stop_signal.make ())

let stop_filter () =
  let x = Atomic.exchange stop_filter_signal (Stop_signal.make ()) in
  Stop_signal.broadcast x

let stop_search () =
  let x = Atomic.exchange stop_search_signal (Stop_signal.make ()) in
  Stop_signal.broadcast x

let _worker_state_lock = Eio.Mutex.create ()

let lock_worker_state : type a. (unit -> a) -> a =
  fun f ->
  Eio.Mutex.use_rw ~protect:false _worker_state_lock f

let init_document_store : Document_store.t ref = ref Document_store.empty

(* Primary copy of snapshots.

   We leave this accessible to other modules to allow
   history construction even when worker fiber
   is inactive.
*)
let snapshots =
  let arr = Dynarray.create () in
  Dynarray.add_last arr (Document_store_snapshot.make_empty ());
  arr

let cur_ver = ref 0

let cur_snapshot_var = Lwd.var (0, Document_store_snapshot.make_empty ())

let cur_snapshot = Lwd.get cur_snapshot_var

type view = {
  init_document_store : Document_store.t;
  snapshots : Document_store_snapshot.t Dynarray.t;
  cur_ver : int;
}

let lock_for_external_editing f =
  (* This blocks further requests from being made. *)
  lock_as_requester (fun () ->
      (* We try to get worker to finish ASAP. *)
      stop_filter ();
      stop_search ();
      lock_worker_state (fun () ->
          (* There should not be any outstanding requests. *)
          assert (Option.is_none (Lock_protected_cell.get filter_request));
          assert (Option.is_none (Lock_protected_cell.get search_request));
          assert (Option.is_none (Lock_protected_cell.get update_request));
          f ()
        )
    )

let lock_with_view : type a. (view -> a) -> a =
  fun f ->
  lock_for_external_editing (fun () ->
      f
        {
          init_document_store = !init_document_store;
          snapshots = Dynarray.copy snapshots;
          cur_ver = !cur_ver;
        }
    )

let update_starting_store (starting_store : Document_store.t) =
  lock_for_external_editing (fun () ->
      let pool = UI_base.task_pool () in
      init_document_store := starting_store;
      let starting_snapshot =
        Document_store_snapshot.make
          ~last_command:None
          starting_store
      in
      Dynarray.set snapshots 0 starting_snapshot;
      for i=1 to Dynarray.length snapshots - 1 do
        let prev = Dynarray.get snapshots (i - 1) in
        let prev_store = Document_store_snapshot.store prev in
        let cur = Dynarray.get snapshots i in
        let store =
          match Document_store_snapshot.last_command cur with
          | None -> prev_store
          | Some command ->
            Option.value ~default:prev_store
              (Document_store.run_command pool command prev_store)
        in
        Dynarray.set
          snapshots
          i
          (Document_store_snapshot.update_store store cur)
      done;
      Lwd.set cur_snapshot_var (!cur_ver, Dynarray.get_last snapshots);
      UI_base.reset_document_selected ()
    )

let load_snapshots snapshots' =
  assert (Dynarray.length snapshots' > 0);
  lock_for_external_editing (fun () ->
      assert
        (Document_store.equal
           (Document_store_snapshot.store @@ Dynarray.get snapshots' 0)
           !init_document_store);
      Dynarray.clear snapshots;
      Dynarray.append snapshots snapshots';
      cur_ver := (Dynarray.length snapshots - 1);
      Lwd.set cur_snapshot_var (!cur_ver, Dynarray.get_last snapshots);
      UI_base.reset_document_selected ()
    )

let sync_input_fields_from_snapshot
    (x : Document_store_snapshot.t)
  =
  let store = Document_store_snapshot.store x in
  Document_store.filter_exp_string store
  |> (fun s ->
      Lwd.set UI_base.Vars.filter_field (s, String.length s));
  Document_store.search_exp_string store
  |> (fun s ->
      Lwd.set UI_base.Vars.search_field (s, String.length s))

let stop_filter_and_search_and_restore_input_fields () =
  lock_for_external_editing (fun () ->
      sync_input_fields_from_snapshot (Dynarray.get_last snapshots);
    )

let shift_ver ~offset =
  lock_for_external_editing (fun () ->
      let new_ver = !cur_ver + offset in
      if 0 <= new_ver && new_ver < Dynarray.length snapshots then (
        cur_ver := new_ver;
        let snapshot = Dynarray.get snapshots new_ver in
        Lwd.set cur_snapshot_var (new_ver, snapshot);
        UI_base.reset_document_selected ();
        sync_input_fields_from_snapshot snapshot;
      )
    )

let manager_fiber () =
  (* This fiber handles updates of Lwd.var which are not thread-safe,
     and thus cannot be done by worker_fiber directly
  *)
  let update_snapshot ver snapshot =
    UI_base.reset_document_selected ();
    Lwd.set cur_snapshot_var (ver, snapshot);
  in
  while true do
    let payload = Eio.Stream.take egress in
    (match payload with
     | Search_exp_parse_error -> (
         Lwd.set UI_base.Vars.search_ui_status `Parse_error
       )
     | Searching -> (
         Lwd.set UI_base.Vars.search_ui_status `Searching
       )
     | Filtering -> (
         Lwd.set UI_base.Vars.filter_ui_status `Filtering
       )
     | Search_cancelled -> (
       )
     | Search_done (ver, snapshot) -> (
         update_snapshot ver snapshot;
         Lwd.set UI_base.Vars.search_ui_status `Idle
       )
     | Filter_glob_parse_error -> (
         Lwd.set UI_base.Vars.filter_ui_status `Parse_error
       )
     | Filtering_cancelled -> (
       )
     | Filtering_done (ver, snapshot) -> (
         update_snapshot ver snapshot;
         Lwd.set UI_base.Vars.filter_ui_status `Idle
       )
     | Update (ver, snapshot) -> (
         update_snapshot ver snapshot;
         Lwd.set UI_base.Vars.search_ui_status `Idle;
         Lwd.set UI_base.Vars.filter_ui_status `Idle;
         sync_input_fields_from_snapshot snapshot;
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
  let get_cur_snapshot () =
    Dynarray.get snapshots !cur_ver
  in
  let add_snapshot
      ?(overwrite_if_last_snapshot_satisfies = fun _ -> false)
      snapshot
    =
    Dynarray.truncate snapshots (!cur_ver + 1);
    let last_snapshot = Dynarray.get_last snapshots in
    if !cur_ver > 0 && overwrite_if_last_snapshot_satisfies last_snapshot then (
      Dynarray.set snapshots !cur_ver snapshot;
    ) else (
      Dynarray.add_last snapshots snapshot;
      incr cur_ver;
    );
  in
  let send_to_manager x =
    Eio.Stream.add egress x;
    Eio.Stream.take egress_ack;
  in
  let process_search_req stop_signal ~commit (s : string) =
    match Search_exp.parse s with
    | None -> (
        send_to_manager Search_exp_parse_error
      )
    | Some search_exp -> (
        send_to_manager Searching;
        let store =
          get_cur_snapshot ()
          |> Document_store_snapshot.store
          |> Document_store.update_search_exp
            pool
            stop_signal
            s
            search_exp
        in
        match store with
        | None -> (
            send_to_manager Search_cancelled
          )
        | Some store -> (
            let command = Some (`Search s) in
            let snapshot =
              Document_store_snapshot.make
                ~committed:commit
                ~last_command:command
                store
            in
            add_snapshot
              ~overwrite_if_last_snapshot_satisfies:(fun snapshot ->
                  not (Document_store_snapshot.committed snapshot)
                  &&
                  (match Document_store_snapshot.last_command snapshot with
                   | Some (`Search _) -> true
                   | _ -> false)
                )
              snapshot;
            send_to_manager (Search_done (!cur_ver, snapshot))
          )
      )
  in
  let process_filter_req stop_signal ~commit (s : string) =
    match Filter_exp.parse s with
    | Some filter_exp -> (
        send_to_manager Filtering;
        let store =
          get_cur_snapshot ()
          |> Document_store_snapshot.store
          |> Document_store.update_filter_exp
            pool
            stop_signal
            s
            filter_exp
        in
        match store with
        | None -> (
            send_to_manager Filtering_cancelled
          )
        | Some store -> (
            let command = Some (`Filter s) in
            let snapshot =
              Document_store_snapshot.make
                ~committed:commit
                ~last_command:command
                store
            in
            add_snapshot
              ~overwrite_if_last_snapshot_satisfies:(fun snapshot ->
                  not (Document_store_snapshot.committed snapshot)
                  &&
                  (match Document_store_snapshot.last_command snapshot with
                   | Some (`Filter _) -> true
                   | _ -> false)
                )
              snapshot;
            send_to_manager (Filtering_done (!cur_ver, snapshot))
          )
      )
    | None -> (
        send_to_manager Filter_glob_parse_error
      )
  in
  let process_update_req f =
    let next_snapshot = f (Dynarray.get_last snapshots) in
    add_snapshot next_snapshot;
    send_to_manager (Update (!cur_ver, next_snapshot))
  in
  while true do
    Ping.wait worker_ping;
    lock_worker_state (fun () ->
        (match Lock_protected_cell.get filter_request with
         | None -> ()
         | Some (commit, s) -> (
             process_filter_req (Atomic.get stop_filter_signal) ~commit s
           )
        );
        (match Lock_protected_cell.get search_request with
         | None -> ()
         | Some (commit, s) -> (
             process_search_req (Atomic.get stop_search_signal) ~commit s
           )
        );
        (match Lock_protected_cell.get update_request with
         | None -> ()
         | Some snapshot -> (
             process_update_req snapshot;
             Eio.Stream.add update_request_completion_ack ();
           )
        );
      )
  done

let submit_filter_req ~commit (s : string) =
  lock_as_requester (fun () ->
      stop_filter ();
      stop_search ();
      Lock_protected_cell.set filter_request (commit, s);
      Ping.ping worker_ping
    )

let submit_search_req ~commit (s : string) =
  lock_as_requester (fun () ->
      stop_search ();
      Lock_protected_cell.set search_request (commit, s);
      Ping.ping worker_ping
    )

let submit_update_req f =
  lock_as_requester (fun () ->
      stop_filter ();
      stop_search ();
      Lock_protected_cell.unset search_request;
      Lock_protected_cell.unset filter_request;
      Lock_protected_cell.set update_request f;
      Ping.ping worker_ping;
      Eio.Stream.take update_request_completion_ack;
    )
