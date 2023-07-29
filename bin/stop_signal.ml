type t = {
  mutable stop : bool;
  mutex : Eio.Mutex.t;
  cond : Eio.Condition.t;
}

let make () =
  {
    stop = false;
    mutex = Eio.Mutex.create ();
    cond = Eio.Condition.create ();
  }

let signal (t : t) =
  Eio.Mutex.use_rw ~protect:true t.mutex (fun () ->
      t.stop <- true;
      Eio.Condition.broadcast t.cond;
    )

let await (t : t) =
  Eio.Mutex.use_ro t.mutex (fun () ->
      while not t.stop do
        Eio.Condition.await t.cond t.mutex;
      done
    )
