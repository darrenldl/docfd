open Docfd_lib

let () =
  Eio_main.run (fun env ->
      Eio.Switch.run (fun sw ->
          let task_pool = Task_pool.make ~sw (Eio.Stdenv.domain_mgr env) in
          let alco_suites =
            [
              ("Search_exp_tests.Alco", Search_exp_tests.Alco.suite);
              ("Index_tests.Alco", Index_tests.Alco.suite task_pool);
              ("Utils_tests.Alco", Utils_tests.Alco.suite);
            ]
          in
          let qc_suites =
            [
              ("Index_tests.Qc", Index_tests.Qc.suite task_pool);
            ]
            |> List.map (fun (name, suite) ->
                (name, List.map QCheck_alcotest.to_alcotest suite))
          in
          let suites = alco_suites @ qc_suites in
          Alcotest.run "docfd-lib" suites
        )
    )
