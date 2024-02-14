open Docfd_lib

let search_phrase_testable : (module Alcotest.TESTABLE with type t = Search_phrase.t) =
  (module struct
    type t = Search_phrase.t

    let pp = Search_phrase.pp

    let equal = Search_phrase.equal
  end)
