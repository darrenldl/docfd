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

let single_file_view_update_request : (string * Document_store.t) Lock_protected_cell.t =
  Lock_protected_cell.make ()

let multi_file_view_update_request : (string * Document_store.t) Lock_protected_cell.t =
  Lock_protected_cell.make ()

let worker_ping : Ping.t = Ping.make ()

let requester_ping : Ping.t = Ping.make ()

type egress_payload =
  | Search_exp_parse_error
  | Searching
  | Search_done of store_typ * string * Document_store.t
  | Filter_glob_parse_error
  | Filtering_done of store_typ * string * Document_store.t
  | Update of store_typ * string * Document_store.t

let egress_mailbox : egress_payload Eio.Stream.t =
  Eio.Stream.create 1

let search_stop_signal = Atomic.make (Stop_signal.make ())

let signal_search_stop () =
  let x = Atomic.exchange search_stop_signal (Stop_signal.make ()) in
  Stop_signal.broadcast x

let single_file_view_document_store = Lwd.var ("", Document_store.empty)

let multi_file_view_document_store = Lwd.var ("", Document_store.empty)

let manager_fiber () =
  (* This fiber handles updates of Lwd.var which are not thread-safe,
     and thus cannot be done by worker_fiber directly
  *)
  let update_store (store_typ : store_typ) desc store =
    match store_typ with
    | `Multi_file_view -> (
        Lwd.set multi_file_view_document_store (desc, store);
      )
    | `Single_file_view -> (
        Lwd.set single_file_view_document_store (desc, store);
      )
  in
  while true do
    let payload = Eio.Stream.take egress_mailbox in
    match payload with
    | Search_exp_parse_error -> (
        Lwd.set search_ui_status `Parse_error
      )
    | Searching -> (
        Lwd.set search_ui_status `Searching
      )
    | Search_done (store_typ, desc, document_store) -> (
        update_store store_typ desc document_store;
        Lwd.set search_ui_status `Idle
      )
    | Filter_glob_parse_error -> (
        Lwd.set filter_ui_status `Parse_error
      )
    | Filtering_done (store_typ, desc, document_store) -> (
        update_store store_typ desc document_store;
        Lwd.set filter_ui_status `Ok
      )
    | Update (store_typ, desc, document_store) -> (
        update_store store_typ desc document_store;
      )
  done

let worker_fiber pool =
  (* This fiber runs in a background domain to allow the UI code in the main
     domain to immediately continue running after key presses that trigger
     searches or search cancellations.

     This removes the need to make the code of document store always yield
     frequently.
  *)
  let single_file_view_store = ref ("", Document_store.empty) in
  let multi_file_view_store = ref ("", Document_store.empty) in
  let process_search_req search_stop_signal (store_typ : store_typ) (s : string) =
    match Search_exp.make s with
    | None -> (
        Eio.Stream.add egress_mailbox Search_exp_parse_error
      )
    | Some search_exp -> (
        Eio.Stream.add egress_mailbox Searching;
        let store =
          (match store_typ with
           | `Single_file_view -> !single_file_view_store
           | `Multi_file_view -> !multi_file_view_store)
          |> snd
          |> Document_store.update_search_exp
            pool
            search_stop_signal
            s
            search_exp
        in
        let desc =
          if String.length s = 0 then (
            "clear search"
          ) else (
            Fmt.str "search \"%s\"" s
          )
        in
        (match store_typ with
         | `Single_file_view -> single_file_view_store := (desc, store)
         | `Multi_file_view -> multi_file_view_store := (desc, store));
        Eio.Stream.add egress_mailbox
          (Search_done (store_typ, desc, store))
      )
  in
  let process_filter_req search_stop_signal (store_typ : store_typ) (original_string : string) =
    let s =
      if String.length original_string = 0 then (
        original_string
      ) else (
        Misc_utils.normalize_glob_to_absolute original_string
      )
    in
    match Glob.make s with
    | Some glob -> (
        let store =
          (match store_typ with
           | `Single_file_view -> !single_file_view_store
           | `Multi_file_view -> !multi_file_view_store)
          |> snd
          |> Document_store.update_file_path_filter_glob
            pool
            search_stop_signal
            original_string
            glob
        in
        let desc =
          if String.length original_string = 0 then (
            Fmt.str "clear filter"
          ) else (
            Fmt.str "filter \"%s\"" original_string
          )
        in
        (match store_typ with
         | `Single_file_view -> single_file_view_store := (desc, store)
         | `Multi_file_view -> multi_file_view_store := (desc, store));
        Eio.Stream.add egress_mailbox (Filtering_done (store_typ, desc, store))
      )
    | None -> (
        Eio.Stream.add egress_mailbox Filter_glob_parse_error
      )
  in
  let process_update_req (store_typ : store_typ) desc store =
    (match store_typ with
     | `Single_file_view -> single_file_view_store := (desc, store)
     | `Multi_file_view -> multi_file_view_store := (desc, store)
    );
    Eio.Stream.add egress_mailbox (Update (store_typ, desc, store))
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
    (match Lock_protected_cell.get single_file_view_update_request with
     | None -> ()
     | Some (desc, store) -> process_update_req `Single_file_view desc store
    );
    (match Lock_protected_cell.get multi_file_view_update_request with
     | None -> ()
     | Some (desc, store) -> process_update_req `Multi_file_view desc store
    );
    Ping.ping requester_ping
  done

let submit_filter_req (store_typ : store_typ) (s : string) =
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

let submit_search_req (store_typ : store_typ) (s : string) =
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

let submit_update_req ?(wait_for_completion = false) (store_typ : store_typ) (desc : string) (store : Document_store.t) =
  signal_search_stop ();
  (match store_typ with
   | `Multi_file_view -> (
       Lock_protected_cell.unset multi_file_view_search_request;
       Lock_protected_cell.unset multi_file_view_filter_request;
       Lock_protected_cell.set multi_file_view_update_request (desc, store);
     )
   | `Single_file_view -> (
       Lock_protected_cell.unset single_file_view_search_request;
       Lock_protected_cell.unset single_file_view_filter_request;
       Lock_protected_cell.set single_file_view_update_request (desc, store);
     )
  );
  Ping.clear requester_ping;
  Ping.ping worker_ping;
  if wait_for_completion then (
    Ping.wait requester_ping
  )
