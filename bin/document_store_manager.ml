open Docfd_lib

type search_status = [
  | `Idle
  | `Searching
  | `Parse_error
]

type filter_status = [ `Ok | `Parse_error ]

type request =
  | Filter of string * Document_store.t * Document_store.t Lwd.var
  | Search of string * Document_store.t * Document_store.t Lwd.var
  | Update of Document_store.t * Document_store.t Lwd.var

let search_ui_status : search_status Lwd.var = Lwd.var `Idle

let filter_ui_status : filter_status Lwd.var = Lwd.var `Ok

let ingress : request Eio.Stream.t =
  Eio.Stream.create 0

type egress_payload =
  | Search_exp_parse_error
  | Searching
  | Search_done of Document_store.t * Document_store.t Lwd.var
  | Filter_glob_parse_error
  | Filtering_done of Document_store.t * Document_store.t Lwd.var
  | Update of Document_store.t * Document_store.t Lwd.var

let egress_mailbox : egress_payload Eio.Stream.t =
  Eio.Stream.create 1

let stop_signal = Atomic.make (Stop_signal.make ())

let stop_signal_swap_completed : unit Eio.Stream.t = Eio.Stream.create 0

let store_update_lock = Eio.Mutex.create ()

let manager_fiber () =
  let update_store document_store_var document_store =
    Eio.Mutex.use_rw store_update_lock ~protect:false (fun () ->
        Lwd.set document_store_var document_store;
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
    | Search_done (document_store, document_store_var) -> (
        update_store document_store_var document_store;
        Lwd.set search_ui_status `Idle
      )
    | Filter_glob_parse_error -> (
        Lwd.set filter_ui_status `Parse_error
      )
    | Filtering_done (document_store, document_store_var) -> (
        update_store document_store_var document_store;
        Lwd.set filter_ui_status `Ok
      )
    | Update (document_store, document_store_var) -> (
        update_store document_store_var document_store;
      )
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
    | Filter (s, document_store, document_store_var) -> (
        let s =
          if String.length s = 0 then (
            s
          ) else (
            Misc_utils.normalize_glob_to_absolute s
          )
        in
        match Misc_utils.compile_glob_re s with
        | Some re -> (
            let document_store =
              document_store
              |> Document_store.update_file_path_filter_glob pool stop_signal' s re
            in
            Eio.Stream.add egress_mailbox (Filtering_done (document_store, document_store_var))
          )
        | None -> (
            Eio.Stream.add egress_mailbox Filter_glob_parse_error
          )
      )
    | Search (s, document_store, document_store_var) -> (
        match Search_exp.make s with
        | None -> (
            Eio.Stream.add egress_mailbox Search_exp_parse_error
          )
        | Some search_exp -> (
            Eio.Stream.add egress_mailbox Searching;
            let document_store =
              document_store
              |> Document_store.update_search_exp pool stop_signal' s search_exp
            in
            Eio.Stream.add egress_mailbox
              (Search_done (document_store, document_store_var))
          )
      )
    | Update (document_store, document_store_var) -> (
        Eio.Stream.add egress_mailbox (Update (document_store, document_store_var))
      )
  done

let submit_filter_req (s : string) (store_var : Document_store.t Lwd.var) =
  Eio.Mutex.use_rw store_update_lock ~protect:false (fun () ->
      let store = Lwd.peek store_var in
      Stop_signal.broadcast (Atomic.get stop_signal);
      Eio.Stream.add ingress (Filter (s, store, store_var));
      Eio.Stream.take stop_signal_swap_completed;
    )

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
