type t = {
  lock : Eio.Mutex.t;
  snapshots : Document_store_snapshot.t Dynarray.t;
}

let make () =
  {
    lock = Eio.Mutex.create ();
    snapshots = Dynarray.create ();
  }

let lock (type a) (t : t) (f : unit -> a) : a =
  Eio.Mutex.use_rw ~protect:false t.lock (fun () ->
    f t
  )

let length (t : t) =
  lock t (fun () ->
    Dynarray.length t.snapshots
  )

let get (t : t) i =
  lock t (fun () ->
    Dynarray.get t.snapshots i
  )

let get_last (t : t) =
  lock t (fun () ->
    Dynarray.get_last t.snapshots
  )

let set (t : t) (_ : lock_token) i snapshot =
  lock t (fun () ->
  Dynarray.set t.snapshots i snapshot
  )

let add_last (t : t) (_ : lock_token) snapshot =
  lock t (fun () ->
  Dynarray.add_last t.snapshots snapshot
  )

let iter (t : t) (_ : lock_token) =
  lock t (fun () ->
  Dynarray.to_seq t.snapshots
  )
