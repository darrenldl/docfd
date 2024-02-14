let () =
  let alco_suites =
    [
      ("Search_exp_tests.Alco", Search_exp_tests.Alco.suite);
    ]
  in
  let qc_suites =
    [
    ]
    |> List.map (fun (name, suite) ->
        (name, List.map QCheck_alcotest.to_alcotest suite))
  in
  let suites = alco_suites @ qc_suites in
  Alcotest.run "docfd-lib" suites
