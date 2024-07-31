open Docfd_lib

let enriched_token_testable : (module Alcotest.TESTABLE with type t = Search_phrase.Enriched_token.t) =
  (module Search_phrase.Enriched_token)

let search_phrase_testable : (module Alcotest.TESTABLE with type t = Search_phrase.t) =
  (module Search_phrase)

let index_testable : (module Alcotest.TESTABLE with type t = Index.t) =
  (module struct
    include Index

    let pp _formatter _index = ()
  end)

let index_gen_from_pages task_pool =
  let open QCheck2.Gen in
  map
    (fun pages ->
       pages
       |> List.to_seq
       |> Index.of_pages task_pool)
    (list_size (int_bound 20) (list_size small_nat (string_size nat)))

let index_gen_from_lines task_pool =
  let open QCheck2.Gen in
  map
    (fun lines ->
       lines
       |> List.to_seq
       |> Index.of_lines task_pool)
    (list_size small_nat (string_size nat))
