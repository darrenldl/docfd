open Docfd_lib
open Test_utils

module Alco = struct
  let max_fuzzy_edit_dist = 0

  let test_invalid_exp (s : string) =
    Alcotest.(check bool)
      "true"
      true
      (Option.is_none
         (Search_exp.make ~max_fuzzy_edit_dist s))

  let test_empty_phrase (s : string) =
    let phrase = Search_phrase.make ~max_fuzzy_edit_dist s in
    Alcotest.(check bool)
      "case0"
      true
      (Search_phrase.is_empty phrase);
    Alcotest.(check bool)
      "case1"
      true
      (List.is_empty (Search_phrase.enriched_tokens phrase))

  let test_empty_exp (s : string) =
    let exp = Search_exp.make ~max_fuzzy_edit_dist s |> Option.get in
    Alcotest.(check bool)
      "case0"
      true
      (Search_exp.is_empty exp);
    let flattened = Search_exp.flattened exp in
    Alcotest.(check bool)
      "case1"
      true
      (List.is_empty flattened
       ||
       List.for_all Search_phrase.is_empty flattened)

  let et ?(m : Search_phrase.match_typ = `Fuzzy) string is_linked_to_prev =
    let automaton = Spelll.of_string ~limit:max_fuzzy_edit_dist "" in
    Search_phrase.Enriched_token.make ~string ~is_linked_to_prev automaton m

  let test_exp
      ?(neg = false)
      (s : string)
      (l : (string * Search_phrase.Enriched_token.t list) list)
    =
    let max_fuzzy_edit_dist = 0 in
    let neg' = neg in
    let phrases =
      l
      |> List.map fst
      |> List.map (Search_phrase.make ~max_fuzzy_edit_dist)
    in
    let enriched_token_list_list =
      List.map snd l
    in
    Alcotest.(check (list (list enriched_token_testable)))
      (Fmt.str "case0 of %S" s)
      enriched_token_list_list
      (phrases
       |> List.map Search_phrase.enriched_tokens
      );
    Alcotest.(check
                (if neg' then (
                    neg (list search_phrase_testable)
                  ) else (
                   list search_phrase_testable
                 )))
      (Fmt.str "case1 of %S" s)
      (List.sort Search_phrase.compare phrases)
      (Search_exp.make ~max_fuzzy_edit_dist s
       |> Option.get
       |> Search_exp.flattened
       |> List.sort Search_phrase.compare
      )

  let corpus () =
    test_empty_exp "";
    test_empty_phrase "";
    test_empty_exp "    ";
    test_empty_phrase "    ";
    test_empty_exp "\r\n";
    test_empty_phrase "\r\n";
    test_empty_exp "\t";
    test_empty_phrase "\t";
    test_empty_exp "\r\n\t";
    test_empty_phrase "\r\n\t";
    test_empty_exp " \r \n \t ";
    test_empty_phrase " \r \n \t ";
    test_empty_exp "()";
    test_empty_exp " () ";
    test_empty_exp "( )";
    test_empty_exp " ( ) ";
    test_empty_exp " ( ) () ";
    test_empty_exp " ( ( ) ) () ";
    test_empty_exp " ( () ) (( )) ";
    test_empty_exp " ( () ) (( () )) ";
    test_invalid_exp " ( ) ( ";
    test_invalid_exp " ) ( ";
    test_invalid_exp " ( ( ) ";
    test_invalid_exp " ( ( ) ";
    test_invalid_exp "?";
    test_invalid_exp "?  ";
    test_exp "(hello)"
      [ ("hello",
         [ (et "hello" false) ])
      ];
    test_exp "()hello"
      [ ("hello",
         [ (et "hello" false) ])
      ];
    test_exp "hello()"
      [ ("hello",
         [ (et "hello" false) ])
      ];
    test_exp "( ) hello"
      [ ("hello",
         [ (et "hello" false) ])
      ];
    test_exp "hello ( )"
      [ ("hello",
         [ (et "hello" false) ])
      ];
    test_exp "?hello"
      [ ("", [])
      ; ("hello",
         [ (et "hello" false) ])
      ];
    test_exp "(?hello)"
      [ ("", [])
      ; ("hello",
         [ (et "hello" false) ])
      ];
    test_exp "?(hello)"
      [ ("", [])
      ; ("hello",
         [ (et "hello" false) ])
      ];
    test_exp "?hello()"
      [ ("", [])
      ; ("hello",
         [ (et "hello" false) ])
      ];
    test_exp "?hello ()"
      [ ("", [])
      ; ("hello",
         [ (et "hello" false) ])
      ];
    test_exp "? hello"
      [ ("", [])
      ; ("hello",
         [ (et "hello" false) ])
      ];
    test_exp "?hello world"
      [ ("world",
         [ (et "world" false) ])
      ; ("hello world",
         [ (et "hello" false); (et "world" false) ])
      ];
    test_exp "? hello world"
      [ ("world",
         [ (et "world" false) ])
      ; ("hello world",
         [ (et "hello" false); (et "world" false) ])
      ];
    test_exp "?(hello) world"
      [ ("world",
         [ (et "world" false) ] )
      ; ("hello world",
         [ (et "hello" false); (et "world" false) ] )
      ];
    test_exp "? (hello) world"
      [ ("world",
         [ (et "world" false) ] )
      ; ("hello world",
         [ (et "hello" false); (et "world" false) ])
      ];
    test_exp "?(hello world) abcd"
      [ ("abcd",
         [ (et "abcd" false) ] )
      ; ("hello world abcd",
         [ (et "hello" false); (et "world" false); (et "abcd" false) ] )
      ];
    test_exp "ab ?(hello world) cd"
      [ ("ab cd",
         [ (et "ab" false); (et "cd" false) ])
      ; ("ab hello world cd",
         [ (et "ab" false); (et "hello" false); (et "world" false); (et "cd" false) ])
      ];
    test_exp "ab ?hello world cd"
      [ ("ab world cd",
         [ (et "ab" false); (et "world" false); (et "cd" false) ])
      ; ("ab hello world cd",
         [ (et "ab" false); (et "hello" false); (et "world" false); (et "cd" false) ])
      ];
    test_exp "go (left | right)"
      [ ("go left",
         [ (et "go" false); (et "left" false) ])
      ; ("go right",
         [ (et "go" false); (et "right" false) ])
      ];
    test_exp "go (?up | left | right)"
      [ ("go",
         [ (et "go" false) ])
      ; ("go up",
         [ (et "go" false); (et "up" false) ])
      ; ("go left",
         [ (et "go" false); (et "left" false) ])
      ; ("go right",
         [ (et "go" false); (et "right" false) ])];
    test_exp "(left | right) (up | down)"
      [ ("left up",
         [ (et "left" false); (et "up" false) ])
      ; ("left down",
         [ (et "left" false); (et "down" false) ])
      ; ("right up",
         [ (et "right" false); (et "up" false) ])
      ; ("right down",
         [ (et "right" false); (et "down" false) ])
      ];
    test_exp "((a|b)(c|d)) (e | f)"
      [ ("a c e",
         [ (et "a" false); (et "c" false); (et "e" false) ])
      ; ("a c f",
         [ (et "a" false); (et "c" false); (et "f" false) ])
      ; ("a d e",
         [ (et "a" false); (et "d" false); (et "e" false) ])
      ; ("a d f",
         [ (et "a" false); (et "d" false); (et "f" false) ])
      ; ("b c e",
         [ (et "b" false); (et "c" false); (et "e" false) ])
      ; ("b c f",
         [ (et "b" false); (et "c" false); (et "f" false) ])
      ; ("b d e",
         [ (et "b" false); (et "d" false); (et "e" false) ])
      ; ("b d f",
         [ (et "b" false); (et "d" false); (et "f" false) ])
      ];
    test_exp "(?left | right) (up | down)"
      [ ("up",
         [ (et "up" false) ])
      ; ("down",
         [ (et "down" false) ])
      ; ("left up",
         [ (et "left" false); (et "up" false) ])
      ; ("left down",
         [ (et "left" false); (et "down" false) ])
      ; ("right up",
         [ (et "right" false); (et "up" false) ])
      ; ("right down",
         [ (et "right" false); (et "down" false) ])
      ];
    test_exp "go (left | right) or ( up | down )"
      [ ("go left or up",
         [ (et "go" false); (et "left" false); (et "or" false); (et "up" false) ])
      ; ("go left or down",
         [ (et "go" false); (et "left" false); (et "or" false); (et "down" false) ])
      ; ("go right or up",
         [ (et "go" false); (et "right" false); (et "or" false); (et "up" false) ])
      ; ("go right or down",
         [ (et "go" false); (et "right" false); (et "or" false); (et "down" false) ])
      ];
    test_exp "and/or"
      [ ("and/or",
         [ (et "and" false); (et "/" true); (et "or" true) ])
      ];
    test_exp ~neg:true "and/or"
      [ ("and / or",
         [ (et "and" false); (et "/" false); (et "or" false) ])
      ];
    test_exp ~neg:true "and/or"
      [ ("and /or",
         [ (et "and" false); (et "/" false); (et "or" true) ])
      ];
    test_exp ~neg:true "and/or"
      [ ("and/ or",
         [ (et "and" false); (et "/" true); (et "or" false) ])
      ];
    test_exp "and / or"
      [ ("and / or",
         [ (et "and" false); (et "/" false); (et "or" false) ])
      ];
    test_exp ~neg:true "and / or"
      [ ("and/or",
         [ (et "and" false); (et "/" true); (et "or" true) ])
      ];
    test_exp ~neg:true "and / or"
      [ ("and /or",
         [ (et "and" false); (et "/" false); (et "or" true) ])
      ];
    test_exp ~neg:true "and / or"
      [ ("and/ or",
         [ (et "and" false); (et "/" true); (et "or" false) ])
      ];
    test_exp "(and)/ or"
      [ ("and / or",
         [ (et "and" false); (et "/" false); (et "or" false) ])
      ];
    test_exp ~neg:true "(and)/ or"
      [ ("and/ or",
         [ (et "and" false); (et "/" true); (et "or" false) ])
      ];
    test_exp "and(/) or"
      [ ("and / or",
         [ (et "and" false); (et "/" false); (et "or" false) ])
      ];
    test_exp ~neg:true "and(/) or"
      [ ("and/ or",
         [ (et "and" false); (et "/" true); (et "or" false) ])
      ];
    test_exp "and/(or)"
      [ ("and/ or",
         [ (et "and" false); (et "/" true); (et "or" false) ])
      ];
    test_exp ~neg:true "and/(or)"
      [ ("and/or",
         [ (et "and" false); (et "/" true); (et "or" true) ])
      ];
    test_exp "go (left | right) and/or ( up | down )"
      [ ("go left and/or up",
         [ (et "go" false); (et "left" false); (et "and" false); (et "/" true); (et "or" true); (et "up" false) ])
      ; ("go left and/or down",
         [ (et "go" false); (et "left" false); (et "and" false); (et "/" true); (et "or" true); (et "down" false) ])
      ; ("go right and/or up",
         [ (et "go" false); (et "right" false); (et "and" false); (et "/" true); (et "or" true); (et "up" false) ])
      ; ("go right and/or down",
         [ (et "go" false); (et "right" false); (et "and" false); (et "/" true); (et "or" true); (et "down" false) ])
      ];
    test_exp "go (left | right) and / or ( up | down )"
      [ ("go left and / or up",
         [ (et "go" false); (et "left" false); (et "and" false); (et "/" false); (et "or" false); (et "up" false) ])
      ; ("go left and / or down",
         [ (et "go" false); (et "left" false); (et "and" false); (et "/" false); (et "or" false); (et "down" false) ])
      ; ("go right and / or up",
         [ (et "go" false); (et "right" false); (et "and" false); (et "/" false); (et "or" false); (et "up" false) ])
      ; ("go right and / or down",
         [ (et "go" false); (et "right" false); (et "and" false); (et "/" false); (et "or" false); (et "down" false) ])
      ];
    test_exp "go ?(left | right) ( up | down )"
      [ ( "go up",
          [ (et "go" false); (et "up" false) ])
      ; ( "go down",
          [ (et "go" false); (et "down" false) ])
      ; ( "go left up",
          [ (et "go" false); (et "left" false); (et "up" false) ])
      ; ( "go left down",
          [ (et "go" false); (et "left" false); (et "down" false) ])
      ; ( "go right up",
          [ (et "go" false); (et "right" false); (et "up" false) ])
      ; ( "go right down",
          [ (et "go" false); (et "right" false); (et "down" false) ])
      ];
    test_exp "go ?((left | right) or) ( up | down )"
      [ ( "go up",
          [ (et "go" false); (et "up" false) ])
      ; ( "go down",
          [ (et "go" false); (et "down" false) ])
      ; ( "go left or up",
          [ (et "go" false); (et "left" false); (et "or" false); (et "up" false) ])
      ; ( "go left or down",
          [ (et "go" false); (et "left" false); (et "or" false); (et "down" false) ])
      ; ( "go right or up",
          [ (et "go" false); (et "right" false); (et "or" false); (et "up" false) ])
      ; ( "go right or down",
          [ (et "go" false); (et "right" false); (et "or" false); (et "down" false) ])
      ];
    test_exp "go ?(?(left | right) or) ( up | down )"
      [ ( "go up",
          [ (et "go" false); (et "up" false) ])
      ; ( "go down",
          [ (et "go" false); (et "down" false) ])
      ; ( "go or up",
          [ (et "go" false); (et "or" false); (et "up" false) ])
      ; ( "go or down",
          [ (et "go" false); (et "or" false); (et "down" false) ])
      ; ( "go left or up",
          [ (et "go" false); (et "left" false); (et "or" false); (et "up" false) ])
      ; ( "go left or down",
          [ (et "go" false); (et "left" false); (et "or" false); (et "down" false) ])
      ; ( "go right or up",
          [ (et "go" false); (et "right" false); (et "or" false); (et "up" false) ])
      ; ( "go right or down",
          [ (et "go" false); (et "right" false); (et "or" false); (et "down" false) ])
      ];
    test_exp "go ?(?(left | right) or) or ( ?up | down )"
      [ ( "go or",
          [ (et "go" false); (et "or" false) ])
      ; ( "go or up",
          [ (et "go" false); (et "or" false); (et "up" false) ])
      ; ( "go or down",
          [ (et "go" false); (et "or" false); (et "down" false) ])
      ; ( "go or or",
          [ (et "go" false); (et "or" false); (et "or" false) ])
      ; ( "go or or up",
          [ (et "go" false); (et "or" false); (et "or" false); (et "up" false) ])
      ; ( "go or or down",
          [ (et "go" false); (et "or" false); (et "or" false); (et "down" false) ])
      ; ( "go left or or",
          [ (et "go" false); (et "left" false); (et "or" false); (et "or" false) ])
      ; ( "go left or or up",
          [ (et "go" false); (et "left" false); (et "or" false); (et "or" false); (et "up" false) ])
      ; ( "go left or or down",
          [ (et "go" false); (et "left" false); (et "or" false); (et "or" false); (et "down" false) ])
      ; ( "go right or or",
          [ (et "go" false); (et "right" false); (et "or" false); (et "or" false) ])
      ; ( "go right or or up",
          [ (et "go" false); (et "right" false); (et "or" false); (et "or" false); (et "up" false) ])
      ; ( "go right or or down",
          [ (et "go" false); (et "right" false); (et "or" false); (et "or" false); (et "down" false) ])
      ];
    test_exp "- - -"
      [ ("- - -",
         [ (et "-" false); (et "-" false); (et "-" false) ])
      ];
    test_exp "-- -"
      [ ("-- -",
         [ (et "-" false); (et "-" true); (et "-" false) ])
      ];
    test_exp "'abcd"
      [ ("abcd",
         [ (et ~m:`Exact "abcd" false ) ])
      ];
    ()

  let suite =
    [
      Alcotest.test_case "corpus" `Quick corpus;
    ]
end
