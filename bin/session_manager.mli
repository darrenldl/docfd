open Docfd_lib

val manager_fiber : unit -> unit

val worker_fiber : Task_pool.t -> unit

val cur_snapshot : (int * Session.Snapshot.t) Lwd.t

type view = {
  init_state : Session.State.t;
  snapshots : Session.Snapshot.t Dynarray.t;
  cur_ver : int;
}

val lock_with_view : (view -> 'a) -> 'a

val update_starting_state : Session.State.t -> unit

val load_snapshots : Session.Snapshot.t Dynarray.t -> unit

val shift_ver : offset:int -> unit

val update_from_cur_snapshot : (Session.Snapshot.t -> Session.Snapshot.t) -> unit

val submit_filter_req : commit:bool -> string -> unit

val submit_search_req : commit:bool -> string -> unit

val stop_filter_and_search_and_restore_input_fields : unit -> unit
