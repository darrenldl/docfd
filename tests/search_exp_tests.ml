open Docfd_lib
open Test_utils

module Alco = struct
  let test_invalid_exp (s : string) =
    Alcotest.(check bool)
      "true"
      true
      (Option.is_none
         (Search_exp.make s))

  let test_empty_phrase (s : string) =
    let phrase = Search_phrase.make s in
    Alcotest.(check bool)
      "case0"
      true
      (Search_phrase.is_empty phrase);
    Alcotest.(check bool)
      "case1"
      true
      (List.is_empty (Search_phrase.enriched_tokens phrase))

  let test_empty_exp (s : string) =
    let exp = Search_exp.make s |> Option.get in
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

  let at s : Search_phrase.annotated_token =
    Search_phrase.{ data = `String s; group_id = 0 }

  let atm m : Search_phrase.annotated_token =
    Search_phrase.{ data = `Match_typ_marker m; group_id = 0 }

  let ats : Search_phrase.annotated_token =
    Search_phrase.{ data = `Explicit_spaces; group_id = 0 }

  let et
      ?(m : Search_phrase.match_typ = `Fuzzy)
      string
      is_linked_to_prev
      is_linked_to_next
    : Search_phrase.Enriched_token.t =
    let automaton = Spelll.of_string ~limit:0 "" in
    Search_phrase.Enriched_token.make
      ~string
      ~is_linked_to_prev
      ~is_linked_to_next
      automaton
      m

  let test_exp
      ?(neg = false)
      (s : string)
      (l : (Search_phrase.annotated_token list * Search_phrase.Enriched_token.t list) list)
    =
    let neg' = neg in
    let phrases =
      l
      |> List.map fst
      |> List.map (fun l ->
          List.to_seq l
          |> Search_phrase.of_annotated_tokens)
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
      (Search_exp.make s
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
    test_exp "\\?"
      [ ([ at "?" ],
         [ et "?" false false ])
      ];
    test_exp "(hello)"
      [ ([ at "hello" ],
         [ et "hello" false false ])
      ];
    test_exp "()hello"
      [ ([ at "hello" ],
         [ et "hello" false false ])
      ];
    test_exp "hello()"
      [ ([ at "hello" ],
         [ et "hello" false false ])
      ];
    test_exp "( ) hello"
      [ ([ at "hello" ],
         [ et "hello" false false ])
      ];
    test_exp "hello ( )"
      [ ([ at "hello" ],
         [ et "hello" false false ])
      ];
    test_exp "?hello"
      [ ([], [])
      ; ([ at "hello" ],
         [ et "hello" false false ])
      ];
    test_exp "(?hello)"
      [ ([], [])
      ; ([ at "hello" ],
         [ et "hello" false false ])
      ];
    test_exp "?(hello)"
      [ ([], [])
      ; ([ at "hello" ],
         [ et "hello" false false ])
      ];
    test_exp "?hello()"
      [ ([], [])
      ; ([ at "hello" ],
         [ et "hello" false false ])
      ];
    test_exp "?hello ()"
      [ ([], [])
      ; ([ at "hello" ],
         [ et "hello" false false ])
      ];
    test_exp "? hello"
      [ ([], [])
      ; ([ at "hello" ],
         [ et "hello" false false ])
      ];
    test_exp "?hello world"
      [ ([ at "world" ],
         [ et "world" false false ])
      ; ([ at "hello"; at " "; at "world" ],
         [ et "hello" false false; et "world" false false ])
      ];
    test_exp "? hello world"
      [ ([ at "world" ],
         [ et "world" false false ])
      ; ([ at "hello"; at " "; at "world" ],
         [ et "hello" false false; et "world" false false ])
      ];
    test_exp "?(hello) world"
      [ ([ at "world" ],
         [ et "world" false false ] )
      ; ([ at "hello"; at " "; at "world" ],
         [ et "hello" false false; et "world" false false ] )
      ];
    test_exp "? (hello) world"
      [ ([ at "world" ],
         [ et "world" false false ] )
      ; ([ at "hello"; at " "; at "world" ],
         [ et "hello" false false; et "world" false false ])
      ];
    test_exp "?(hello world) abcd"
      [ ([ at "abcd" ],
         [ et "abcd" false false ] )
      ; ([ at "hello"; at " "; at "world"; at " "; at "abcd" ],
         [ et "hello" false false; et "world" false false; et "abcd" false false ] )
      ];
    test_exp "ab ?(hello world) cd"
      [ ([ at "ab"; at " "; at "cd" ],
         [ et "ab" false false; et "cd" false false ])
      ; ([ at "ab"; at " "; at "hello"; at " "; at "world"; at " "; at "cd" ],
         [ et "ab" false false; et "hello" false false; et "world" false false; et "cd" false false ])
      ];
    test_exp "ab ?hello world cd"
      [ ([ at "ab"; at " "; at "world"; at " "; at "cd" ],
         [ et "ab" false false; et "world" false false; et "cd" false false ])
      ; ([ at "ab"; at " "; at "hello"; at " "; at "world"; at " "; at "cd" ],
         [ et "ab" false false; et "hello" false false; et "world" false false; et "cd" false false ])
      ];
    test_exp "go (left | right)"
      [ ([ at "go"; at " "; at "left" ],
         [ et "go" false false; et "left" false false ])
      ; ([ at "go"; at " "; at "right" ],
         [ et "go" false false; et "right" false false ])
      ];
    test_exp "go (?up | left | right)"
      [ ([ at "go" ],
         [ et "go" false false ])
      ; ([ at "go"; at " "; at "up" ],
         [ et "go" false false; et "up" false false ])
      ; ([ at "go"; at " "; at "left" ],
         [ et "go" false false; et "left" false false ])
      ; ([ at "go"; at " "; at "right" ],
         [ et "go" false false; et "right" false false ])];
    test_exp "(left | right) (up | down)"
      [ ([ at "left"; at " "; at "up" ],
         [ et "left" false false; et "up" false false ])
      ; ([ at "left"; at " "; at "down" ],
         [ et "left" false false; et "down" false false ])
      ; ([ at "right"; at " "; at "up" ],
         [ et "right" false false; et "up" false false ])
      ; ([ at "right"; at " "; at "down" ],
         [ et "right" false false; et "down" false false ])
      ];
    test_exp "((a|b)(c|d)) (e | f)"
      [ ([ at "a"; at " "; at "c"; at " "; at "e" ],
         [ et "a" false false; et "c" false false; et "e" false false ])
      ; ([ at "a"; at " "; at "c"; at " "; at "f" ],
         [ et "a" false false; et "c" false false; et "f" false false ])
      ; ([ at "a"; at " "; at "d"; at " "; at "e" ],
         [ et "a" false false; et "d" false false; et "e" false false ])
      ; ([ at "a"; at " "; at "d"; at " "; at "f" ],
         [ et "a" false false; et "d" false false; et "f" false false ])
      ; ([ at "b"; at " "; at "c"; at " "; at "e" ],
         [ et "b" false false; et "c" false false; et "e" false false ])
      ; ([ at "b"; at " "; at "c"; at " "; at "f" ],
         [ et "b" false false; et "c" false false; et "f" false false ])
      ; ([ at "b"; at " "; at "d"; at " "; at "e" ],
         [ et "b" false false; et "d" false false; et "e" false false ])
      ; ([ at "b"; at " "; at "d"; at " "; at "f" ],
         [ et "b" false false; et "d" false false; et "f" false false ])
      ];
    test_exp "(?left | right) (up | down)"
      [ ([ at "up" ],
         [ et "up" false false ])
      ; ([ at "down" ],
         [ et "down" false false ])
      ; ([ at "left"; at " "; at "up" ],
         [ et "left" false false; et "up" false false ])
      ; ([ at "left"; at " "; at "down" ],
         [ et "left" false false; et "down" false false ])
      ; ([ at "right"; at " "; at "up" ],
         [ et "right" false false; et "up" false false ])
      ; ([ at "right"; at " "; at "down" ],
         [ et "right" false false; et "down" false false ])
      ];
    test_exp "go (left | right) or ( up | down )"
      [ ([ at "go"; at " "; at "left"; at " "; at "or"; at " "; at "up" ],
         [ et "go" false false; et "left" false false; et "or" false false; et "up" false false ])
      ; ([ at "go"; at " "; at "left"; at " "; at "or"; at " "; at "down" ],
         [ et "go" false false; et "left" false false; et "or" false false; et "down" false false ])
      ; ([ at "go"; at " "; at "right"; at " "; at "or"; at " "; at "up" ],
         [ et "go" false false; et "right" false false; et "or" false false; et "up" false false ])
      ; ([ at "go"; at " "; at "right"; at " "; at "or"; at " "; at "down" ],
         [ et "go" false false; et "right" false false; et "or" false false; et "down" false false ])
      ];
    test_exp "and/or"
      [ ([ at "and"; at "/"; at "or" ],
         [ et "and" false true; et "/" true true; et "or" true false ])
      ];
    test_exp ~neg:true "and/or"
      [ ([ at "and"; at " "; at "/"; at " "; at "or" ],
         [ et "and" false false; et "/" false false; et "or" false false ])
      ];
    test_exp ~neg:true "and/or"
      [ ([ at "and"; at " "; at "/"; at "or" ],
         [ et "and" false false; et "/" false true; et "or" true false ])
      ];
    test_exp ~neg:true "and/or"
      [ ([ at "and"; at "/"; at " "; at "or" ],
         [ et "and" false true; et "/" true false; et "or" false false ])
      ];
    test_exp "and / or"
      [ ([ at "and"; at " "; at "/"; at " "; at "or" ],
         [ et "and" false false; et "/" false false; et "or" false false ])
      ];
    test_exp ~neg:true "and / or"
      [ ([ at "and"; at "/"; at "or" ],
         [ et "and" false true; et "/" true true; et "or" true false ])
      ];
    test_exp ~neg:true "and / or"
      [ ([ at "and"; at " "; at "/"; at "or" ],
         [ et "and" false false; et "/" false true; et "or" true false ])
      ];
    test_exp ~neg:true "and / or"
      [ ([ at "and"; at "/"; at " "; at "or" ],
         [ et "and" false true; et "/" true false; et "or" false false ])
      ];
    test_exp "(and)/ or"
      [ ([ at "and"; at " "; at "/"; at " "; at "or" ],
         [ et "and" false false; et "/" false false; et "or" false false ])
      ];
    test_exp ~neg:true "(and)/ or"
      [ ([ at "and"; at "/"; at " "; at "or" ],
         [ et "and" false true; et "/" true false; et "or" false false ])
      ];
    test_exp "and(/) or"
      [ ([ at "and"; at " "; at "/"; at " "; at "or" ],
         [ et "and" false false; et "/" false false; et "or" false false ])
      ];
    test_exp ~neg:true "and(/) or"
      [ ([ at "and"; at "/"; at " "; at "or" ],
         [ et "and" false true; et "/" true false; et "or" false false ])
      ];
    test_exp "and/(or)"
      [ ([ at "and"; at "/"; at " "; at "or" ],
         [ et "and" false true; et "/" true false; et "or" false false ])
      ];
    test_exp ~neg:true "and/(or)"
      [ ([ at "and"; at "/"; at "or" ],
         [ et "and" false true; et "/" true true; et "or" true false ])
      ];
    test_exp "go (left | right) and/or ( up | down )"
      [ ([ at "go"; at " "; at "left"; at " "; at "and"; at "/"; at "or"; at " "; at "up" ],
         [ et "go" false false; et "left" false false; et "and" false true; et "/" true true; et "or" true false; et "up" false false ])
      ; ([ at "go"; at " "; at "left"; at " "; at "and"; at "/"; at "or"; at " "; at "down" ],
         [ et "go" false false; et "left" false false; et "and" false true; et "/" true true; et "or" true false; et "down" false false ])
      ; ([ at "go"; at " "; at "right"; at " "; at "and"; at "/"; at "or"; at " "; at "up" ],
         [ et "go" false false; et "right" false false; et "and" false true; et "/" true true; et "or" true false; et "up" false false ])
      ; ([ at "go"; at " "; at "right"; at " "; at "and"; at "/"; at "or"; at " "; at "down" ],
         [ et "go" false false; et "right" false false; et "and" false true; et "/" true true; et "or" true false; et "down" false false ])
      ];
    test_exp "go (left | right) and / or ( up | down )"
      [ ([ at "go"; at " "; at "left"; at " "; at "and"; at " "; at "/"; at " "; at "or"; at " "; at "up" ],
         [ et "go" false false; et "left" false false; et "and" false false; et "/" false false; et "or" false false; et "up" false false ])
      ; ([ at "go"; at " "; at "left"; at " "; at "and"; at " "; at "/"; at " "; at "or"; at " "; at "down" ],
         [ et "go" false false; et "left" false false; et "and" false false; et "/" false false; et "or" false false; et "down" false false ])
      ; ([ at "go"; at " "; at "right"; at " "; at "and"; at " "; at "/"; at " "; at "or"; at " "; at "up" ],
         [ et "go" false false; et "right" false false; et "and" false false; et "/" false false; et "or" false false; et "up" false false ])
      ; ([ at "go"; at " "; at "right"; at " "; at "and"; at " "; at "/"; at " "; at "or"; at " "; at "down" ],
         [ et "go" false false; et "right" false false; et "and" false false; et "/" false false; et "or" false false; et "down" false false ])
      ];
    test_exp "go ?(left | right) ( up | down )"
      [ ([ at "go"; at " "; at "up" ],
         [ et "go" false false; et "up" false false ])
      ; ([ at "go"; at " "; at "down" ],
         [ et "go" false false; et "down" false false ])
      ; ([ at "go"; at " "; at "left"; at " "; at "up" ],
         [ et "go" false false; et "left" false false; et "up" false false ])
      ; ([ at "go"; at " "; at "left"; at " "; at "down" ],
         [ et "go" false false; et "left" false false; et "down" false false ])
      ; ([ at "go"; at " "; at "right"; at " "; at "up" ],
         [ et "go" false false; et "right" false false; et "up" false false ])
      ; ([ at "go"; at " "; at "right"; at " "; at "down" ],
         [ et "go" false false; et "right" false false; et "down" false false ])
      ];
    test_exp "go ?((left | right) or) ( up | down )"
      [ ([ at "go"; at " "; at "up" ],
         [ et "go" false false; et "up" false false ])
      ; ([ at "go"; at " "; at "down" ],
         [ et "go" false false; et "down" false false ])
      ; ([ at "go"; at " "; at "left"; at " "; at "or"; at " "; at "up" ],
         [ et "go" false false; et "left" false false; et "or" false false; et "up" false false ])
      ; ([ at "go"; at " "; at "left"; at " "; at "or"; at " "; at "down" ],
         [ et "go" false false; et "left" false false; et "or" false false; et "down" false false ])
      ; ([ at "go"; at " "; at "right"; at " "; at "or"; at " "; at "up" ],
         [ et "go" false false; et "right" false false; et "or" false false; et "up" false false ])
      ; ([ at "go"; at " "; at "right"; at " "; at "or"; at " "; at "down" ],
         [ et "go" false false; et "right" false false; et "or" false false; et "down" false false ])
      ];
    test_exp "go ?(?(left | right) or) ( up | down )"
      [ ([ at "go"; at " "; at "up" ],
         [ et "go" false false; et "up" false false ])
      ; ([ at "go"; at " "; at "down" ],
         [ et "go" false false; et "down" false false ])
      ; ([ at "go"; at " "; at "or"; at " "; at "up" ],
         [ et "go" false false; et "or" false false; et "up" false false ])
      ; ([ at "go"; at " "; at "or"; at " "; at "down" ],
         [ et "go" false false; et "or" false false; et "down" false false ])
      ; ([ at "go"; at " "; at "left"; at " "; at "or"; at " "; at "up" ],
         [ et "go" false false; et "left" false false; et "or" false false; et "up" false false ])
      ; ([ at "go"; at " "; at "left"; at " "; at "or"; at " "; at "down" ],
         [ et "go" false false; et "left" false false; et "or" false false; et "down" false false ])
      ; ([ at "go"; at " "; at "right"; at " "; at "or"; at " "; at "up" ],
         [ et "go" false false; et "right" false false; et "or" false false; et "up" false false ])
      ; ([ at "go"; at " "; at "right"; at " "; at "or"; at " "; at "down" ],
         [ et "go" false false; et "right" false false; et "or" false false; et "down" false false ])
      ];
    test_exp "go ?(?(left | right) or) or ( ?up | down )"
      [ ([ at "go"; at " "; at "or" ],
         [ et "go" false false; et "or" false false ])
      ; ([ at "go"; at " "; at "or"; at " "; at "up" ],
         [ et "go" false false; et "or" false false; et "up" false false ])
      ; ([ at "go"; at " "; at "or"; at " "; at "down" ],
         [ et "go" false false; et "or" false false; et "down" false false ])
      ; ([ at "go"; at " "; at "or"; at " "; at "or" ],
         [ et "go" false false; et "or" false false; et "or" false false ])
      ; ([ at "go"; at " "; at "or"; at " "; at "or"; at " "; at "up" ],
         [ et "go" false false; et "or" false false; et "or" false false; et "up" false false ])
      ; ([ at "go"; at " "; at "or"; at " "; at "or"; at " "; at "down" ],
         [ et "go" false false; et "or" false false; et "or" false false; et "down" false false ])
      ; ([ at "go"; at " "; at "left"; at " "; at "or"; at " "; at "or" ],
         [ et "go" false false; et "left" false false; et "or" false false; et "or" false false ])
      ; ([ at "go"; at " "; at "left"; at " "; at "or"; at " "; at "or"; at " "; at "up" ],
         [ et "go" false false; et "left" false false; et "or" false false; et "or" false false; et "up" false false ])
      ; ([ at "go"; at " "; at "left"; at " "; at "or"; at " "; at "or"; at " "; at "down" ],
         [ et "go" false false; et "left" false false; et "or" false false; et "or" false false; et "down" false false ])
      ; ([ at "go"; at " "; at "right"; at " "; at "or"; at " "; at "or" ],
         [ et "go" false false; et "right" false false; et "or" false false; et "or" false false ])
      ; ([ at "go"; at " "; at "right"; at " "; at "or"; at " "; at "or"; at " "; at "up" ],
         [ et "go" false false; et "right" false false; et "or" false false; et "or" false false; et "up" false false ])
      ; ([ at "go"; at " "; at "right"; at " "; at "or"; at " "; at "or"; at " "; at "down" ],
         [ et "go" false false; et "right" false false; et "or" false false; et "or" false false; et "down" false false ])
      ];
    test_exp "- - -"
      [ ([ at "-"; at " "; at "-"; at " "; at "-" ],
         [ et "-" false false; et "-" false false; et "-" false false ])
      ];
    test_exp "-- -"
      [ ([ at "-"; at "-"; at " "; at "-" ],
         [ et "-" false true; et "-" true false; et "-" false false ])
      ];
    test_exp "\\'abcd"
      [ ([ at "'"; at "abcd" ],
         [ et "'" false true; et "abcd" true false ])
      ];
    test_exp "'abcd"
      [ ([ atm `Exact; at "abcd" ],
         [ et ~m:`Exact "abcd" false false ])
      ];
    test_exp "' abcd"
      [ ([ atm `Exact; at " "; at "abcd" ],
         [ et "'" false false; et "abcd" false false ])
      ];
    test_exp "' abcd"
      [ ([ at "'"; at " "; at "abcd" ],
         [ et "'" false false; et "abcd" false false ])
      ];
    test_exp "\\^abcd"
      [ ([ at "^"; at "abcd" ],
         [ et "^" false true; et "abcd" true false ])
      ];
    test_exp "^abcd"
      [ ([ atm `Prefix; at "abcd" ],
         [ et ~m:`Prefix "abcd" false false ])
      ];
    test_exp "^ abcd"
      [ ([ at "^"; at " "; at "abcd" ],
         [ et "^" false false; et "abcd" false false ])
      ];
    test_exp "^ abcd"
      [ ([ atm `Prefix; at " "; at "abcd" ],
         [ et "^" false false; et "abcd" false false ])
      ];
    test_exp "abcd$"
      [ ([ at "abcd"; atm `Suffix ],
         [ et ~m:`Suffix "abcd" false false ])
      ];
    test_exp "abcd $"
      [ ([ at "abcd"; at " "; at "$" ],
         [ et "abcd" false false; et "$" false false ])
      ];
    test_exp "abcd $"
      [ ([ at "abcd"; at " "; atm `Suffix ],
         [ et "abcd" false false; et "$" false false ])
      ];
    test_exp "''abcd"
      [ ([ atm `Exact; atm `Exact; at "abcd" ],
         [ et ~m:`Exact "'" false true; et ~m:`Exact "abcd" true false ])
      ];
    test_exp "^^abcd"
      [ ([ atm `Prefix; at "^"; at "abcd" ],
         [ et ~m:`Exact "^" false true; et ~m:`Prefix "abcd" true false ])
      ];
    test_exp "abcd$$"
      [ ([ at "abcd"; at "$"; atm `Suffix ],
         [ et ~m:`Suffix "abcd" false true; et ~m:`Exact "$" true false ])
      ];
    test_exp "abcd$$"
      [ ([ at "abcd"; atm `Suffix; atm `Suffix ],
         [ et ~m:`Suffix "abcd" false true; et ~m:`Exact "$" true false ])
      ];
    test_exp "'^abcd efgh$$ ij$kl$"
      [ ([ atm `Exact
         ; atm `Prefix
         ; at "abcd"
         ; at " "
         ; at "efgh"
         ; atm `Suffix
         ; atm `Suffix
         ; at " "
         ; at "ij"
         ; atm `Suffix
         ; at "kl"
         ; atm `Suffix
         ],
         [ et ~m:`Exact "^" false true
         ; et ~m:`Exact "abcd" true false
         ; et ~m:`Suffix "efgh" false true
         ; et ~m:`Exact "$" true false
         ; et ~m:`Suffix "ij" false true
         ; et ~m:`Exact "$" true true
         ; et ~m:`Exact "kl" true false
         ])
      ];
    ()

  let suite =
    [
      Alcotest.test_case "corpus" `Quick corpus;
    ]
end
