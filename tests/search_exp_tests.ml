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

  let at ?(m : Search_phrase.match_typ = `Fuzzy) string =
    Search_phrase.{ string; group_id = 0; match_typ = m }

  let et ?(m : Search_phrase.match_typ = `Fuzzy) string is_linked_to_prev =
    let automaton = Spelll.of_string ~limit:max_fuzzy_edit_dist "" in
    Search_phrase.Enriched_token.make ~string ~is_linked_to_prev automaton m

  let test_exp
      ?(neg = false)
      (s : string)
      (l : (Search_phrase.annotated_token list * Search_phrase.Enriched_token.t list) list)
    =
    let max_fuzzy_edit_dist = 0 in
    let neg' = neg in
    let phrases =
      l
      |> List.map fst
      |> List.map (fun l ->
          List.to_seq l
          |> Search_phrase.of_annotated_tokens ~max_fuzzy_edit_dist)
    in
    let enriched_token_list_list =
      List.map snd l
    in
    Alcotest.(check
                (if neg' then (
                    neg (list search_phrase_testable)
                  ) else (
                   list search_phrase_testable
                 )))
      (Fmt.str "case0 of %S" s)
      (List.sort Search_phrase.compare phrases)
      (Search_exp.make ~max_fuzzy_edit_dist s
       |> Option.get
       |> Search_exp.flattened
       |> List.sort Search_phrase.compare
      );
    Alcotest.(check (list (list enriched_token_testable)))
      (Fmt.str "case1 of %S" s)
      enriched_token_list_list
      (phrases
       |> List.map Search_phrase.enriched_tokens
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
      [ ([ at "hello" ],
         [ et "hello" false ])
      ];
    test_exp "()hello"
      [ ([ at "hello" ],
         [ et "hello" false ])
      ];
    test_exp "hello()"
      [ ([ at "hello" ],
         [ et "hello" false ])
      ];
    test_exp "( ) hello"
      [ ([ at "hello" ],
         [ et "hello" false ])
      ];
    test_exp "hello ( )"
      [ ([ at "hello" ],
         [ et "hello" false ])
      ];
    test_exp "?hello"
      [ ([], [])
      ; ([ at "hello" ],
         [ et "hello" false ])
      ];
    test_exp "(?hello)"
      [ ([], [])
      ; ([ at "hello" ],
         [ et "hello" false ])
      ];
    test_exp "?(hello)"
      [ ([], [])
      ; ([ at "hello" ],
         [ et "hello" false ])
      ];
    test_exp "?hello()"
      [ ([], [])
      ; ([ at "hello" ],
         [ et "hello" false ])
      ];
    test_exp "?hello ()"
      [ ([], [])
      ; ([ at "hello" ],
         [ et "hello" false ])
      ];
    test_exp "? hello"
      [ ([], [])
      ; ([ at "hello" ],
         [ et "hello" false ])
      ];
    test_exp "?hello world"
      [ ([ at "world" ],
         [ et "world" false ])
      ; ([ at "hello"; at " "; at "world" ],
         [ et "hello" false; et "world" false ])
      ];
    test_exp "? hello world"
      [ ([ at "world" ],
         [ et "world" false ])
      ; ([ at "hello"; at " "; at "world" ],
         [ et "hello" false; et "world" false ])
      ];
    test_exp "?(hello) world"
      [ ([ at "world" ],
         [ et "world" false ] )
      ; ([ at "hello"; at " "; at "world" ],
         [ et "hello" false; et "world" false ] )
      ];
    test_exp "? (hello) world"
      [ ([ at "world" ],
         [ et "world" false ] )
      ; ([ at "hello"; at " "; at "world" ],
         [ et "hello" false; et "world" false ])
      ];
    test_exp "?(hello world) abcd"
      [ ([ at "abcd" ],
         [ et "abcd" false ] )
      ; ([ at "hello"; at " "; at "world"; at " "; at "abcd" ],
         [ et "hello" false; et "world" false; et "abcd" false ] )
      ];
    test_exp "ab ?(hello world) cd"
      [ ([ at "ab"; at " "; at "cd" ],
         [ et "ab" false; et "cd" false ])
      ; ([ at "ab"; at " "; at "hello"; at " "; at "world"; at " "; at "cd" ],
         [ et "ab" false; et "hello" false; et "world" false; et "cd" false ])
      ];
    test_exp "ab ?hello world cd"
      [ ([ at "ab"; at " "; at "world"; at " "; at "cd" ],
         [ et "ab" false; et "world" false; et "cd" false ])
      ; ([ at "ab"; at " "; at "hello"; at " "; at "world"; at " "; at "cd" ],
         [ et "ab" false; et "hello" false; et "world" false; et "cd" false ])
      ];
    test_exp "go (left | right)"
      [ ([ at "go"; at " "; at "left" ],
         [ et "go" false; et "left" false ])
      ; ([ at "go"; at " "; at "right" ],
         [ et "go" false; et "right" false ])
      ];
    test_exp "go (?up | left | right)"
      [ ([ at "go" ],
         [ et "go" false ])
      ; ([ at "go"; at " "; at "up" ],
         [ et "go" false; et "up" false ])
      ; ([ at "go"; at " "; at "left" ],
         [ et "go" false; et "left" false ])
      ; ([ at "go"; at " "; at "right" ],
         [ et "go" false; et "right" false ])];
    test_exp "(left | right) (up | down)"
      [ ([ at "left"; at " "; at "up" ],
         [ et "left" false; et "up" false ])
      ; ([ at "left"; at " "; at "down" ],
         [ et "left" false; et "down" false ])
      ; ([ at "right"; at " "; at "up" ],
         [ et "right" false; et "up" false ])
      ; ([ at "right"; at " "; at "down" ],
         [ et "right" false; et "down" false ])
      ];
    test_exp "((a|b)(c|d)) (e | f)"
      [ ([ at "a"; at " "; at "c"; at " "; at "e" ],
         [ et "a" false; et "c" false; et "e" false ])
      ; ([ at "a"; at " "; at "c"; at " "; at "f" ],
         [ et "a" false; et "c" false; et "f" false ])
      ; ([ at "a"; at " "; at "d"; at " "; at "e" ],
         [ et "a" false; et "d" false; et "e" false ])
      ; ([ at "a"; at " "; at "d"; at " "; at "f" ],
         [ et "a" false; et "d" false; et "f" false ])
      ; ([ at "b"; at " "; at "c"; at " "; at "e" ],
         [ et "b" false; et "c" false; et "e" false ])
      ; ([ at "b"; at " "; at "c"; at " "; at "f" ],
         [ et "b" false; et "c" false; et "f" false ])
      ; ([ at "b"; at " "; at "d"; at " "; at "e" ],
         [ et "b" false; et "d" false; et "e" false ])
      ; ([ at "b"; at " "; at "d"; at " "; at "f" ],
         [ et "b" false; et "d" false; et "f" false ])
      ];
    test_exp "(?left | right) (up | down)"
      [ ([ at "up" ],
         [ et "up" false ])
      ; ([ at "down" ],
         [ et "down" false ])
      ; ([ at "left"; at " "; at "up" ],
         [ et "left" false; et "up" false ])
      ; ([ at "left"; at " "; at "down" ],
         [ et "left" false; et "down" false ])
      ; ([ at "right"; at " "; at "up" ],
         [ et "right" false; et "up" false ])
      ; ([ at "right"; at " "; at "down" ],
         [ et "right" false; et "down" false ])
      ];
    test_exp "go (left | right) or ( up | down )"
      [ ([ at "go"; at " "; at "left"; at " "; at "or"; at " "; at "up" ],
         [ et "go" false; et "left" false; et "or" false; et "up" false ])
      ; ([ at "go"; at " "; at "left"; at " "; at "or"; at " "; at "down" ],
         [ et "go" false; et "left" false; et "or" false; et "down" false ])
      ; ([ at "go"; at " "; at "right"; at " "; at "or"; at " "; at "up" ],
         [ et "go" false; et "right" false; et "or" false; et "up" false ])
      ; ([ at "go"; at " "; at "right"; at " "; at "or"; at " "; at "down" ],
         [ et "go" false; et "right" false; et "or" false; et "down" false ])
      ];
    test_exp "and/or"
      [ ([ at "and"; at "/"; at "or" ],
         [ et "and" false; et "/" true; et "or" true ])
      ];
    test_exp ~neg:true "and/or"
      [ ([ at "and"; at " "; at "/"; at " "; at "or" ],
         [ et "and" false; et "/" false; et "or" false ])
      ];
    test_exp ~neg:true "and/or"
      [ ([ at "and"; at " "; at "/"; at "or" ],
         [ et "and" false; et "/" false; et "or" true ])
      ];
    test_exp ~neg:true "and/or"
      [ ([ at "and"; at "/"; at " "; at "or" ],
         [ et "and" false; et "/" true; et "or" false ])
      ];
    test_exp "and / or"
      [ ([ at "and"; at " "; at "/"; at " "; at "or" ],
         [ et "and" false; et "/" false; et "or" false ])
      ];
    test_exp ~neg:true "and / or"
      [ ([ at "and"; at "/"; at "or" ],
         [ et "and" false; et "/" true; et "or" true ])
      ];
    test_exp ~neg:true "and / or"
      [ ([ at "and"; at " "; at "/"; at "or" ],
         [ et "and" false; et "/" false; et "or" true ])
      ];
    test_exp ~neg:true "and / or"
      [ ([ at "and"; at "/"; at " "; at "or" ],
         [ et "and" false; et "/" true; et "or" false ])
      ];
    test_exp "(and)/ or"
      [ ([ at "and"; at " "; at "/"; at " "; at "or" ],
         [ et "and" false; et "/" false; et "or" false ])
      ];
    test_exp ~neg:true "(and)/ or"
      [ ([ at "and"; at "/"; at " "; at "or" ],
         [ et "and" false; et "/" true; et "or" false ])
      ];
    test_exp "and(/) or"
      [ ([ at "and"; at " "; at "/"; at " "; at "or" ],
         [ et "and" false; et "/" false; et "or" false ])
      ];
    test_exp ~neg:true "and(/) or"
      [ ([ at "and"; at "/"; at " "; at "or" ],
         [ et "and" false; et "/" true; et "or" false ])
      ];
    test_exp "and/(or)"
      [ ([ at "and"; at "/"; at " "; at "or" ],
         [ et "and" false; et "/" true; et "or" false ])
      ];
    test_exp ~neg:true "and/(or)"
      [ ([ at "and"; at "/"; at "or" ],
         [ et "and" false; et "/" true; et "or" true ])
      ];
    test_exp "go (left | right) and/or ( up | down )"
      [ ([ at "go"; at " "; at "left"; at " "; at "and"; at "/"; at "or"; at " "; at "up" ],
         [ et "go" false; et "left" false; et "and" false; et "/" true; et "or" true; et "up" false ])
      ; ([ at "go"; at " "; at "left"; at " "; at "and"; at "/"; at "or"; at " "; at "down" ],
         [ et "go" false; et "left" false; et "and" false; et "/" true; et "or" true; et "down" false ])
      ; ([ at "go"; at " "; at "right"; at " "; at "and"; at "/"; at "or"; at " "; at "up" ],
         [ et "go" false; et "right" false; et "and" false; et "/" true; et "or" true; et "up" false ])
      ; ([ at "go"; at " "; at "right"; at " "; at "and"; at "/"; at "or"; at " "; at "down" ],
         [ et "go" false; et "right" false; et "and" false; et "/" true; et "or" true; et "down" false ])
      ];
    test_exp "go (left | right) and / or ( up | down )"
      [ ([ at "go"; at " "; at "left"; at " "; at "and"; at " "; at "/"; at " "; at "or"; at " "; at "up" ],
         [ et "go" false; et "left" false; et "and" false; et "/" false; et "or" false; et "up" false ])
      ; ([ at "go"; at " "; at "left"; at " "; at "and"; at " "; at "/"; at " "; at "or"; at " "; at "down" ],
         [ et "go" false; et "left" false; et "and" false; et "/" false; et "or" false; et "down" false ])
      ; ([ at "go"; at " "; at "right"; at " "; at "and"; at " "; at "/"; at " "; at "or"; at " "; at "up" ],
         [ et "go" false; et "right" false; et "and" false; et "/" false; et "or" false; et "up" false ])
      ; ([ at "go"; at " "; at "right"; at " "; at "and"; at " "; at "/"; at " "; at "or"; at " "; at "down" ],
         [ et "go" false; et "right" false; et "and" false; et "/" false; et "or" false; et "down" false ])
      ];
    test_exp "go ?(left | right) ( up | down )"
      [ ([ at "go"; at " "; at "up" ],
         [ et "go" false; et "up" false ])
      ; ([ at "go"; at " "; at "down" ],
         [ et "go" false; et "down" false ])
      ; ([ at "go"; at " "; at "left"; at " "; at "up" ],
         [ et "go" false; et "left" false; et "up" false ])
      ; ([ at "go"; at " "; at "left"; at " "; at "down" ],
         [ et "go" false; et "left" false; et "down" false ])
      ; ([ at "go"; at " "; at "right"; at " "; at "up" ],
         [ et "go" false; et "right" false; et "up" false ])
      ; ([ at "go"; at " "; at "right"; at " "; at "down" ],
         [ et "go" false; et "right" false; et "down" false ])
      ];
    test_exp "go ?((left | right) or) ( up | down )"
      [ ([ at "go"; at " "; at "up" ],
         [ et "go" false; et "up" false ])
      ; ([ at "go"; at " "; at "down" ],
         [ et "go" false; et "down" false ])
      ; ([ at "go"; at " "; at "left"; at " "; at "or"; at " "; at "up" ],
         [ et "go" false; et "left" false; et "or" false; et "up" false ])
      ; ([ at "go"; at " "; at "left"; at " "; at "or"; at " "; at "down" ],
         [ et "go" false; et "left" false; et "or" false; et "down" false ])
      ; ([ at "go"; at " "; at "right"; at " "; at "or"; at " "; at "up" ],
         [ et "go" false; et "right" false; et "or" false; et "up" false ])
      ; ([ at "go"; at " "; at "right"; at " "; at "or"; at " "; at "down" ],
         [ et "go" false; et "right" false; et "or" false; et "down" false ])
      ];
    test_exp "go ?(?(left | right) or) ( up | down )"
      [ ([ at "go"; at " "; at "up" ],
         [ et "go" false; et "up" false ])
      ; ([ at "go"; at " "; at "down" ],
         [ et "go" false; et "down" false ])
      ; ([ at "go"; at " "; at "or"; at " "; at "up" ],
         [ et "go" false; et "or" false; et "up" false ])
      ; ([ at "go"; at " "; at "or"; at " "; at "down" ],
         [ et "go" false; et "or" false; et "down" false ])
      ; ([ at "go"; at " "; at "left"; at " "; at "or"; at " "; at "up" ],
         [ et "go" false; et "left" false; et "or" false; et "up" false ])
      ; ([ at "go"; at " "; at "left"; at " "; at "or"; at " "; at "down" ],
         [ et "go" false; et "left" false; et "or" false; et "down" false ])
      ; ([ at "go"; at " "; at "right"; at " "; at "or"; at " "; at "up" ],
         [ et "go" false; et "right" false; et "or" false; et "up" false ])
      ; ([ at "go"; at " "; at "right"; at " "; at "or"; at " "; at "down" ],
         [ et "go" false; et "right" false; et "or" false; et "down" false ])
      ];
    test_exp "go ?(?(left | right) or) or ( ?up | down )"
      [ ([ at "go"; at " "; at "or" ],
         [ et "go" false; et "or" false ])
      ; ([ at "go"; at " "; at "or"; at " "; at "up" ],
         [ et "go" false; et "or" false; et "up" false ])
      ; ([ at "go"; at " "; at "or"; at " "; at "down" ],
         [ et "go" false; et "or" false; et "down" false ])
      ; ([ at "go"; at " "; at "or"; at " "; at "or" ],
         [ et "go" false; et "or" false; et "or" false ])
      ; ([ at "go"; at " "; at "or"; at " "; at "or"; at " "; at "up" ],
         [ et "go" false; et "or" false; et "or" false; et "up" false ])
      ; ([ at "go"; at " "; at "or"; at " "; at "or"; at " "; at "down" ],
         [ et "go" false; et "or" false; et "or" false; et "down" false ])
      ; ([ at "go"; at " "; at "left"; at " "; at "or"; at " "; at "or" ],
         [ et "go" false; et "left" false; et "or" false; et "or" false ])
      ; ([ at "go"; at " "; at "left"; at " "; at "or"; at " "; at "or"; at " "; at "up" ],
         [ et "go" false; et "left" false; et "or" false; et "or" false; et "up" false ])
      ; ([ at "go"; at " "; at "left"; at " "; at "or"; at " "; at "or"; at " "; at "down" ],
         [ et "go" false; et "left" false; et "or" false; et "or" false; et "down" false ])
      ; ([ at "go"; at " "; at "right"; at " "; at "or"; at " "; at "or" ],
         [ et "go" false; et "right" false; et "or" false; et "or" false ])
      ; ([ at "go"; at " "; at "right"; at " "; at "or"; at " "; at "or"; at " "; at "up" ],
         [ et "go" false; et "right" false; et "or" false; et "or" false; et "up" false ])
      ; ([ at "go"; at " "; at "right"; at " "; at "or"; at " "; at "or"; at " "; at "down" ],
         [ et "go" false; et "right" false; et "or" false; et "or" false; et "down" false ])
      ];
    test_exp "- - -"
      [ ([ at "-"; at " "; at "-"; at " "; at "-" ],
         [ et "-" false; et "-" false; et "-" false ])
      ];
    test_exp "-- -"
      [ ([ at "-"; at "-"; at " "; at "-" ],
         [ et "-" false; et "-" true; et "-" false ])
      ];
    test_exp "'abcd"
      [ ([ at ~m:`Exact "abcd" ],
         [ et ~m:`Exact "abcd" false ])
      ];
    test_exp "' abcd"
      [ ([ at "'"; at " "; at "abcd" ],
         [ et "'" false; et "abcd" false ])
      ];
    test_exp "^abcd"
      [ ([ at ~m:`Prefix "abcd" ],
         [ et ~m:`Prefix "abcd" false ])
      ];
    test_exp "^ abcd"
      [ ([ at "^"; at " "; at "abcd" ],
         [ et "^" false; et "abcd" false ])
      ];
    test_exp "abcd$"
      [ ([ at ~m:`Suffix "abcd" ],
         [ et ~m:`Suffix "abcd" false ])
      ];
    test_exp "abcd $"
      [ ([ at "abcd"; at " "; at "$" ],
         [ et "abcd" false; et "$" false ])
      ];
    test_exp "''abcd"
      [ ([ at ~m:`Exact "'"; at "abcd" ],
         [ et ~m:`Exact "'" false; et "abcd" true ])
      ];
    test_exp "abcd$$"
      [ ([ at "abcd"; at ~m:`Suffix "$" ],
         [ et "abcd" false; et ~m:`Suffix "$" true ])
      ];
    test_exp "'^abcd efgh$$ ij$kl$"
      [ ([ at ~m:`Exact "^"
         ; at "abcd"
         ; at " "
         ; at "efgh"
         ; at ~m:`Suffix "$"
         ; at " "
         ; at "ij"
         ; at "$"
         ; at ~m:`Suffix "kl"
         ],
         [ et ~m:`Exact "^" false
         ; et "abcd" true
         ; et "efgh" false
         ; et ~m:`Suffix "$" true
         ; et "ij" false
         ; et "$" true
         ; et ~m:`Suffix "kl" true
         ])
      ];
    ()

  let suite =
    [
      Alcotest.test_case "corpus" `Quick corpus;
    ]
end
