let pool_size = max 1 (Domain.recommended_domain_count () - 1)

let pool =
  Domainslib.Task.setup_pool ~num_domains:pool_size ()

let run (f : unit -> 'a) : 'a =
  let p, r = Eio.Promise.create () in
  let _ : unit Domainslib.Task.promise =
    Domainslib.Task.async pool (fun () ->
        Eio.Promise.resolve r (f ())
      )
  in
  Eio.Promise.await p

let map_list : 'a 'b . ('a -> 'b) -> 'a list -> 'b list =
  fun f l ->
  Eio.Fiber.List.map ~max_fibers:pool_size
    (fun x -> run (fun () -> f x)) l

let filter_list : 'a 'b . ('a -> bool) -> 'a list -> 'a list =
  fun f l ->
  Eio.Fiber.List.filter ~max_fibers:pool_size
    (fun x -> run (fun () -> f x)) l

let filter_map_list : 'a 'b . ('a -> 'b option) -> 'a list -> 'b list =
  fun f l ->
  Eio.Fiber.List.filter_map ~max_fibers:pool_size
    (fun x -> run (fun () -> f x)) l
