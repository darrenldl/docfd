type t = Eio.Executor_pool.t

let size = max 1 (Domain.recommended_domain_count () - 1)

let make ~sw mgr =
  Eio.Executor_pool.create ~sw ~domain_count:size mgr

let run (t : t) (f : unit -> 'a) : 'a =
  Eio.Executor_pool.submit_exn t ~weight:1.0 f

let map_list : 'a 'b . t -> ('a -> 'b) -> 'a list -> 'b list =
  fun t f l ->
  Eio.Fiber.List.map ~max_fibers:size
    (fun x ->
       Eio.Fiber.yield ();
       run t (fun () -> f x))
    l

let filter_list : 'a 'b . t -> ('a -> bool) -> 'a list -> 'a list =
  fun t f l ->
  Eio.Fiber.List.filter ~max_fibers:size
    (fun x ->
       Eio.Fiber.yield ();
       run t (fun () -> f x))
    l

let filter_map_list : 'a 'b . t -> ('a -> 'b option) -> 'a list -> 'b list =
  fun t f l ->
  Eio.Fiber.List.filter_map ~max_fibers:size
    (fun x ->
       Eio.Fiber.yield ();
       run t (fun () -> f x))
    l
