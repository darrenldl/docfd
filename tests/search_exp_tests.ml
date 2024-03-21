open Docfd_lib
open Test_utils

module Alco = struct
  let test_empty_exp (s : string) =
    let fuzzy_max_edit_dist = 0 in
    Alcotest.(check bool)
      "true"
      true
      (Search_exp.is_empty
         (Search_exp.make ~fuzzy_max_edit_dist s |> Option.get))

  let test_exp (s : string) (l : string list) =
    let fuzzy_max_edit_dist = 0 in
    Alcotest.(check (list search_phrase_testable))
      (Fmt.str "case %S" s)
      (List.map (Search_phrase.make ~fuzzy_max_edit_dist) l
       |> List.sort Search_phrase.compare)
      (Search_exp.make ~fuzzy_max_edit_dist s
       |> Option.get
       |> Search_exp.flattened
       |> List.sort Search_phrase.compare
      )

  let corpus () =
    test_empty_exp "";
    test_empty_exp "    ";
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
    test_exp "(left | right) (up | down)"
      [ "left up"
      ; "left down"
      ; "right up"
      ; "right down"
      ];
    test_exp "((a | b) (c | d)) (e | f)"
      [ "a c e"
      ; "a c f"
      ; "a d e"
      ; "a d f"
      ; "b c e"
      ; "b c f"
      ; "b d e"
      ; "b d f"
      ];
    test_exp "(?left | right) (up | down)"
      [ "up"
      ; "down"
      ; "left up"
      ; "left down"
      ; "right up"
      ; "right down"
      ];
    test_exp "go (left | right) or ( up | down )"
      [ "go left or up"
      ; "go left or down"
      ; "go right or up"
      ; "go right or down"
      ];
    test_exp "go (left | right) and/or ( up | down )"
      [ "go left and / or up"
      ; "go left and / or down"
      ; "go right and / or up"
      ; "go right and / or down"
      ];
    test_exp "go ?(left | right) ( up | down )"
      [ "go up"
      ; "go down"
      ; "go left up"
      ; "go left down"
      ; "go right up"
      ; "go right down"
      ];
    test_exp "go ?((left | right) or) ( up | down )"
      [ "go up"
      ; "go down"
      ; "go left or up"
      ; "go left or down"
      ; "go right or up"
      ; "go right or down"
      ];
    test_exp "go ?(?(left | right) or) ( up | down )"
      [ "go up"
      ; "go down"
      ; "go or up"
      ; "go or down"
      ; "go left or up"
      ; "go left or down"
      ; "go right or up"
      ; "go right or down"
      ];
    test_exp "go ?(?(left | right) or) or ( ?up | down )"
      [ "go or"
      ; "go or up"
      ; "go or down"
      ; "go or or"
      ; "go or or up"
      ; "go or or down"
      ; "go left or or"
      ; "go left or or up"
      ; "go left or or down"
      ; "go right or or"
      ; "go right or or up"
      ; "go right or or down"
      ];
    ()

  let suite =
    [
      Alcotest.test_case "corpus" `Quick corpus;
    ]
end
