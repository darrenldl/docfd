type t = {
  queue : unit Eio.Stream.t;
}

let make () =
  {
    queue = Eio.Stream.create Int.max_int;
  }

let ping (t : t) =
  Eio.Stream.add t.queue ()

let wait (t : t) =
  Eio.Stream.take t.queue;
  Misc_utils.drain_eio_stream t.queue

let clear (t : t) =
  Misc_utils.drain_eio_stream t.queue
