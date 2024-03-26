open Docfd_lib
open Test_utils

module Alco = struct
  let fuzzy_max_edit_dist = 0

  let test_invalid_exp (s : string) =
    Alcotest.(check bool)
      "true"
      true
      (Option.is_none
         (Search_exp.make ~fuzzy_max_edit_dist s))

  let test_empty_phrase (s : string) =
    let phrase = Search_phrase.make ~fuzzy_max_edit_dist s in
    Alcotest.(check bool)
      "case0"
      true
      (Search_phrase.is_empty phrase);
    Alcotest.(check bool)
      "case1"
      true
      (List.is_empty (Search_phrase.to_enriched_tokens phrase))

  let test_empty_exp (s : string) =
    let exp = Search_exp.make ~fuzzy_max_edit_dist s |> Option.get in
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

  let test_exp
      ?(neg = false)
      (s : string)
      (l : (string * (string * bool) list) list)
    =
    let fuzzy_max_edit_dist = 0 in
    let neg' = neg in
    let phrases =
      l
      |> List.map fst
      |> List.map (Search_phrase.make ~fuzzy_max_edit_dist)
    in
    let automaton = Spelll.of_string ~limit:fuzzy_max_edit_dist "" in
    let enriched_token_list_list =
      List.map snd l
      |> List.map (List.map (fun (string, is_linked_to_prev) ->
          Search_phrase.{ string; is_linked_to_prev; automaton }))
    in
    Alcotest.(check (list (list enriched_token_testable)))
      (Fmt.str "case0 of %S" s)
      enriched_token_list_list
      (phrases
       |> List.map Search_phrase.to_enriched_tokens
      );
    Alcotest.(check
                (if neg' then (
                    neg (list search_phrase_testable)
                  ) else (
                   list search_phrase_testable
                 )))
      (Fmt.str "case1 of %S" s)
      (List.sort Search_phrase.compare phrases)
      (Search_exp.make ~fuzzy_max_edit_dist s
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
         [ ("hello", false) ])
      ];
    test_exp "()hello"
      [ ("hello",
         [ ("hello", false) ])
      ];
    test_exp "hello()"
      [ ("hello",
         [ ("hello", false) ])
      ];
    test_exp "( ) hello"
      [ ("hello",
         [ ("hello", false) ])
      ];
    test_exp "hello ( )"
      [ ("hello",
         [ ("hello", false) ])
      ];
    test_exp "?hello"
      [ ("", [])
      ; ("hello",
         [ ("hello", false) ])
      ];
    test_exp "(?hello)"
      [ ("", [])
      ; ("hello",
         [ ("hello", false) ])
      ];
    test_exp "?(hello)"
      [ ("", [])
      ; ("hello",
         [ ("hello", false) ])
      ];
    test_exp "?hello()"
      [ ("", [])
      ; ("hello",
         [ ("hello", false) ])
      ];
    test_exp "?hello ()"
      [ ("", [])
      ; ("hello",
         [ ("hello", false) ])
      ];
    test_exp "? hello"
      [ ("", [])
      ; ("hello",
         [ ("hello", false) ])
      ];
    test_exp "?hello world"
      [ ("world",
         [ ("world", false) ])
      ; ("hello world",
         [ ("hello", false); ("world", false) ])
      ];
    test_exp "? hello world"
      [ ("world",
         [ ("world", false) ])
      ; ("hello world",
         [ ("hello", false); ("world", false) ])
      ];
    test_exp "?(hello) world"
      [ ("world",
         [ ("world", false) ] )
      ; ("hello world",
         [ ("hello", false); ("world", false) ] )
      ];
    test_exp "? (hello) world"
      [ ("world",
         [ ("world", false) ] )
      ; ("hello world",
         [ ("hello", false); ("world", false) ])
      ];
    test_exp "?(hello world) abcd"
      [ ("abcd",
         [ ("abcd", false) ] )
      ; ("hello world abcd",
         [ ("hello", false); ("world", false); ("abcd", false) ] )
      ];
    test_exp "ab ?(hello world) cd"
      [ ("ab cd",
         [ ("ab", false); ("cd", false) ])
      ; ("ab hello world cd",
         [ ("ab", false); ("hello", false); ("world", false); ("cd", false) ])
      ];
    test_exp "ab ?hello world cd"
      [ ("ab world cd",
         [ ("ab", false); ("world", false); ("cd", false) ])
      ; ("ab hello world cd",
         [ ("ab", false); ("hello", false); ("world", false); ("cd", false) ])
      ];
    test_exp "go (left | right)"
      [ ("go left",
         [ ("go", false); ("left", false) ])
      ; ("go right",
         [ ("go", false); ("right", false) ])
      ];
    test_exp "go (?up | left | right)"
      [ ("go",
         [ ("go", false) ])
      ; ("go up",
         [ ("go", false); ("up", false) ])
      ; ("go left",
         [ ("go", false); ("left", false) ])
      ; ("go right",
         [ ("go", false); ("right", false) ])];
    test_exp "(left | right) (up | down)"
      [ ("left up",
         [ ("left", false); ("up", false) ])
      ; ("left down",
         [ ("left", false); ("down", false) ])
      ; ("right up",
         [ ("right", false); ("up", false) ])
      ; ("right down",
         [ ("right", false); ("down", false) ])
      ];
    test_exp "((a|b)(c|d)) (e | f)"
      [ ("a c e",
         [ ("a", false); ("c", false); ("e", false) ])
      ; ("a c f",
         [ ("a", false); ("c", false); ("f", false) ])
      ; ("a d e",
         [ ("a", false); ("d", false); ("e", false) ])
      ; ("a d f",
         [ ("a", false); ("d", false); ("f", false) ])
      ; ("b c e",
         [ ("b", false); ("c", false); ("e", false) ])
      ; ("b c f",
         [ ("b", false); ("c", false); ("f", false) ])
      ; ("b d e",
         [ ("b", false); ("d", false); ("e", false) ])
      ; ("b d f",
         [ ("b", false); ("d", false); ("f", false) ])
      ];
    test_exp "(?left | right) (up | down)"
      [ ("up",
         [ ("up", false) ])
      ; ("down",
         [ ("down", false) ])
      ; ("left up",
         [ ("left", false); ("up", false) ])
      ; ("left down",
         [ ("left", false); ("down", false) ])
      ; ("right up",
         [ ("right", false); ("up", false) ])
      ; ("right down",
         [ ("right", false); ("down", false) ])
      ];
    test_exp "go (left | right) or ( up | down )"
      [ ("go left or up",
         [ ("go", false); ("left", false); ("or", false); ("up", false) ])
      ; ("go left or down",
         [ ("go", false); ("left", false); ("or", false); ("down", false) ])
      ; ("go right or up",
         [ ("go", false); ("right", false); ("or", false); ("up", false) ])
      ; ("go right or down",
         [ ("go", false); ("right", false); ("or", false); ("down", false) ])
      ];
    test_exp "and/or"
      [ ("and/or",
         [ ("and", false); ("/", true); ("or", true) ])
      ];
    test_exp ~neg:true "and/or"
      [ ("and / or",
         [ ("and", false); ("/", false); ("or", false) ])
      ];
    test_exp ~neg:true "and/or"
      [ ("and /or",
         [ ("and", false); ("/", false); ("or", true) ])
      ];
    test_exp ~neg:true "and/or"
      [ ("and/ or",
         [ ("and", false); ("/", true); ("or", false) ])
      ];
    test_exp "and / or"
      [ ("and / or",
         [ ("and", false); ("/", false); ("or", false) ])
      ];
    test_exp ~neg:true "and / or"
      [ ("and/or",
         [ ("and", false); ("/", true); ("or", true) ])
      ];
    test_exp ~neg:true "and / or"
      [ ("and /or",
         [ ("and", false); ("/", false); ("or", true) ])
      ];
    test_exp ~neg:true "and / or"
      [ ("and/ or",
         [ ("and", false); ("/", true); ("or", false) ])
      ];
    test_exp "(and)/ or"
      [ ("and / or",
         [ ("and", false); ("/", false); ("or", false) ])
      ];
    test_exp ~neg:true "(and)/ or"
      [ ("and/ or",
         [ ("and", false); ("/", true); ("or", false) ])
      ];
    test_exp "and(/) or"
      [ ("and / or",
         [ ("and", false); ("/", false); ("or", false) ])
      ];
    test_exp ~neg:true "and(/) or"
      [ ("and/ or",
         [ ("and", false); ("/", true); ("or", false) ])
      ];
    test_exp "and/(or)"
      [ ("and/ or",
         [ ("and", false); ("/", true); ("or", false) ])
      ];
    test_exp ~neg:true "and/(or)"
      [ ("and/or",
         [ ("and", false); ("/", true); ("or", true) ])
      ];
    test_exp "go (left | right) and/or ( up | down )"
      [ ("go left and/or up",
         [ ("go", false); ("left", false); ("and", false); ("/", true); ("or", true); ("up", false) ])
      ; ("go left and/or down",
         [ ("go", false); ("left", false); ("and", false); ("/", true); ("or", true); ("down", false) ])
      ; ("go right and/or up",
         [ ("go", false); ("right", false); ("and", false); ("/", true); ("or", true); ("up", false) ])
      ; ("go right and/or down",
         [ ("go", false); ("right", false); ("and", false); ("/", true); ("or", true); ("down", false) ])
      ];
    test_exp "go (left | right) and / or ( up | down )"
      [ ("go left and / or up",
         [ ("go", false); ("left", false); ("and", false); ("/", false); ("or", false); ("up", false) ])
      ; ("go left and / or down",
         [ ("go", false); ("left", false); ("and", false); ("/", false); ("or", false); ("down", false) ])
      ; ("go right and / or up",
         [ ("go", false); ("right", false); ("and", false); ("/", false); ("or", false); ("up", false) ])
      ; ("go right and / or down",
         [ ("go", false); ("right", false); ("and", false); ("/", false); ("or", false); ("down", false) ])
      ];
    test_exp "go ?(left | right) ( up | down )"
      [ ( "go up",
          [ ("go", false); ("up", false) ])
      ; ( "go down",
          [ ("go", false); ("down", false) ])
      ; ( "go left up",
          [ ("go", false); ("left", false); ("up", false) ])
      ; ( "go left down",
          [ ("go", false); ("left", false); ("down", false) ])
      ; ( "go right up",
          [ ("go", false); ("right", false); ("up", false) ])
      ; ( "go right down",
          [ ("go", false); ("right", false); ("down", false) ])
      ];
    test_exp "go ?((left | right) or) ( up | down )"
      [ ( "go up",
          [ ("go", false); ("up", false) ])
      ; ( "go down",
          [ ("go", false); ("down", false) ])
      ; ( "go left or up",
          [ ("go", false); ("left", false); ("or", false); ("up", false) ])
      ; ( "go left or down",
          [ ("go", false); ("left", false); ("or", false); ("down", false) ])
      ; ( "go right or up",
          [ ("go", false); ("right", false); ("or", false); ("up", false) ])
      ; ( "go right or down",
          [ ("go", false); ("right", false); ("or", false); ("down", false) ])
      ];
    test_exp "go ?(?(left | right) or) ( up | down )"
      [ ( "go up",
          [ ("go", false); ("up", false) ])
      ; ( "go down",
          [ ("go", false); ("down", false) ])
      ; ( "go or up",
          [ ("go", false); ("or", false); ("up", false) ])
      ; ( "go or down",
          [ ("go", false); ("or", false); ("down", false) ])
      ; ( "go left or up",
          [ ("go", false); ("left", false); ("or", false); ("up", false) ])
      ; ( "go left or down",
          [ ("go", false); ("left", false); ("or", false); ("down", false) ])
      ; ( "go right or up",
          [ ("go", false); ("right", false); ("or", false); ("up", false) ])
      ; ( "go right or down",
          [ ("go", false); ("right", false); ("or", false); ("down", false) ])
      ];
    test_exp "go ?(?(left | right) or) or ( ?up | down )"
      [ ( "go or",
          [ ("go", false); ("or", false) ])
      ; ( "go or up",
          [ ("go", false); ("or", false); ("up", false) ])
      ; ( "go or down",
          [ ("go", false); ("or", false); ("down", false) ])
      ; ( "go or or",
          [ ("go", false); ("or", false); ("or", false) ])
      ; ( "go or or up",
          [ ("go", false); ("or", false); ("or", false); ("up", false) ])
      ; ( "go or or down",
          [ ("go", false); ("or", false); ("or", false); ("down", false) ])
      ; ( "go left or or",
          [ ("go", false); ("left", false); ("or", false); ("or", false) ])
      ; ( "go left or or up",
          [ ("go", false); ("left", false); ("or", false); ("or", false); ("up", false) ])
      ; ( "go left or or down",
          [ ("go", false); ("left", false); ("or", false); ("or", false); ("down", false) ])
      ; ( "go right or or",
          [ ("go", false); ("right", false); ("or", false); ("or", false) ])
      ; ( "go right or or up",
          [ ("go", false); ("right", false); ("or", false); ("or", false); ("up", false) ])
      ; ( "go right or or down",
          [ ("go", false); ("right", false); ("or", false); ("or", false); ("down", false) ])
      ];
    test_exp "- - -"
      [ ("- - -",
         [ ("-", false); ("-", false); ("-", false) ])
      ];
    test_exp "-- -"
      [ ("-- -",
         [ ("-", false); ("-", true); ("-", false) ])
      ];
    ()

  let suite =
    [
      Alcotest.test_case "corpus" `Quick corpus;
    ]
end
