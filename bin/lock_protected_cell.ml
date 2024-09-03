type 'a t = {
  lock : Eio.Mutex.t;
  mutable data : 'a option;
}

let make () =
  {
    lock = Eio.Mutex.create ();
    data = None;
  }

let set (t : 'a t) (x : 'a) =
  Eio.Mutex.use_rw t.lock ~protect:false (fun () ->
      t.data <- Some x
    )

let unset (t : 'a t) =
  Eio.Mutex.use_rw t.lock ~protect:false (fun () ->
      t.data <- None
    )

let get (t : 'a t) : 'a option =
  Eio.Mutex.use_rw t.lock ~protect:false (fun () ->
      let x = t.data in
      t.data <- None;
      x
    )
