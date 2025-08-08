open Docfd_lib

val manager_fiber : unit -> unit

val worker_fiber : Task_pool.t -> unit

val cur_snapshot : (int * Document_store_snapshot.t) Lwd.var

type view = {
  init_document_store : Document_store.t;
  snapshots : Document_store_snapshot.t Dynarray.t;
  cur_ver : int;
}

val lock_with_view : (view -> 'a) -> 'a

val update_starting_store : Document_store.t -> unit

val load_snapshots : Document_store_snapshot.t Dynarray.t -> unit

val shift_ver : offset:int -> unit

val submit_filter_req : commit:bool -> string -> unit

val submit_search_req : commit:bool -> string -> unit

val submit_update_req : (Document_store_snapshot.t -> Document_store_snapshot.t) -> unit

