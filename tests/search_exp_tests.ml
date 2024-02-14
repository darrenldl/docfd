open Docfd_lib
open Test_utils

module Alco = struct
  let test_exp (s : string) (l : string list) =
    let fuzzy_max_edit_distance = 0 in
    Alcotest.(check (list search_phrase_testable))
      "equal"
      (List.map (Search_phrase.make ~fuzzy_max_edit_distance) l
       |> List.sort Search_phrase.compare)
      (Search_exp.make ~fuzzy_max_edit_distance s
       |> Search_exp.flattened
       |> List.sort Search_phrase.compare
      )

  let corpus () =
    test_exp "?hello"
      [ ""; "hello" ];
    test_exp "?hello world"
      [ "world"; "hello world" ];
    test_exp "?(hello) world"
      [ "world"; "hello world" ];
    test_exp "?(hello world) abcd"
      [ "abcd"; "hello world abcd" ];
    test_exp "ab ?(hello world) cd"
      [ "ab cd"; "ab hello world cd" ];
    test_exp "ab ?hello world cd"
      [ "ab world cd"; "ab hello world cd" ];
    test_exp "go (left | right)"
      [ "go left"; "go right" ];
    test_exp "go (?up | left | right)"
      [ "go"; "go up"; "go left"; "go right" ];
    ()

  let suite =
    [
      Alcotest.test_case "corpus" `Quick corpus;
    ]
end
