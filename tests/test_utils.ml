open Docfd_lib

let enriched_token_testable : (module Alcotest.TESTABLE with type t = Search_phrase.Enriched_token.t) =
  (module Search_phrase.Enriched_token)

let search_phrase_testable : (module Alcotest.TESTABLE with type t = Search_phrase.t) =
  (module Search_phrase)
