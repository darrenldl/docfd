open Docfd_lib

type t

val parse : path:string -> (t, string) result

val run :
  Task_pool.t ->
  init_state:Session.State.t ->
  t ->
  (Session.Snapshot.t Dynarray.t, string) result
