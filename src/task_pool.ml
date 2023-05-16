let pool = Domainslib.Task.setup_pool
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
