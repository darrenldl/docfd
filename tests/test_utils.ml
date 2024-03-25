open Docfd_lib

let enriched_token_testable : (module Alcotest.TESTABLE with type t = Search_phrase.enriched_token) =
  (module struct
    type t = Search_phrase.enriched_token

    let pp = Search_phrase.pp_enriched_token

    let equal = Search_phrase.equal_enriched_token
  end)

let search_phrase_testable : (module Alcotest.TESTABLE with type t = Search_phrase.t) =
  (module struct
    type t = Search_phrase.t

    let pp = Search_phrase.pp

    let equal = Search_phrase.equal
  end)
