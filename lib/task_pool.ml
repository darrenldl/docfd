let pool =
  Domainslib.Task.setup_pool
    ~num_domains:(max 1 (Domain.recommended_domain_count () - 1))
    ()

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
  Eio.Fiber.List.map (fun x -> f x) l

let filter_list : 'a 'b . ('a -> bool) -> 'a list -> 'a list =
  fun f l ->
  Eio.Fiber.List.filter (fun x -> f x) l

let filter_map_list : 'a 'b . ('a -> 'b option) -> 'a list -> 'b list =
  fun f l ->
  Eio.Fiber.List.filter_map (fun x -> f x) l
