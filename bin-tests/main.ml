open Docfd_lib

let () =
  Eio_main.run (fun env ->
      Eio.Switch.run (fun sw ->
          let _task_pool = Task_pool.make ~sw (Eio.Stdenv.domain_mgr env) in
          let alco_suites =
            [
              ("Utils_tests.Alco", Utils_tests.Alco.suite);
            ]
          in
          let qc_suites =
            [
            ]
            |> List.map (fun (name, suite) ->
                (name, List.map QCheck_alcotest.to_alcotest suite))
          in
          let suites = alco_suites @ qc_suites in
          Alcotest.run "docfd-bin" suites
        )
    )
