type t = {
  mutable stop : bool;
  cond : Eio.Condition.t;
  mutex : Eio.Mutex.t;
}

let make () =
  {
    stop = false;
    cond = Eio.Condition.create ();
    mutex = Eio.Mutex.create ();
  }

let await (t : t) =
  Eio.Mutex.use_ro t.mutex (fun () ->
      while not t.stop do
        Eio.Condition.await t.cond t.mutex
      done
    )

let broadcast (t : t) =
  Eio.Mutex.use_rw ~protect:false t.mutex
    (fun () -> t.stop <- true);
  Eio.Condition.broadcast t.cond
