let pool : Docfd_lib.Task_pool.t option ref = ref None

let eio_env : Eio_unix.Stdenv.base option ref = ref None

let term : Notty_unix.Term.t option ref = ref None

let task_pool () =
  Option.get !pool

let eio_env () =
  Option.get !eio_env

let term () =
  Option.get !term
