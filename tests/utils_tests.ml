open Docfd_lib

module Alco = struct
  let normalize_path_to_absolute_corpus () =
    let test expected input =
      Alcotest.(check string)
        (Printf.sprintf "%s becomes %s" input expected)
        expected
        (Misc_utils'.normalize_path_to_absolute input)
    in
    test "/" "/..";
    test "/" "/..";
    test "/" "/abcd/..";
    test "/" "/abcd/..";
    test "/abc" "/abc/";
    test "/abc" "/abc/def/..";
    test "/abc" "/abc//";
    test "/abc/def" "/abc//def";
    test "/abc/def" "/abc/./def";
    test "/abc/def" "/abc/.///def/.";
    test "/def" "/abc/.//../def/."

  let normalize_glob_to_absolute_corpus () =
    let test expected input =
      Alcotest.(check string)
        (Printf.sprintf "%s becomes %s" input expected)
        expected
        (Misc_utils'.normalize_glob_to_absolute input)
    in
    test "/" "/..";
    test "/" "/..";
    test "/" "/abcd/..";
    test "/" "/abcd/..";
    test "/abc" "/abc/";
    test "/abc" "/abc/def/..";
    test "/abc" "/abc/*/..";
    test "/abc/**/.." "/abc/**/..";
    test "/abc/**/def" "/abc/**/def";
    test "/**/def/*/.." "/abc/../**/def/*/..";
    test "/abc/**/def" "/abc/.////**/def";
    test "/abc" "/abc//";
    test "/abc/def" "/abc//def";
    test "/abc/def" "/abc/./def";
    test "/abc/def" "/abc/.///def/.";
    test "/def" "/abc/.//../def/."

  let suite =
    [
      Alcotest.test_case
        "normalize_path_to_absolute_corpus"
        `Quick
        normalize_path_to_absolute_corpus;
      Alcotest.test_case
        "normalize_glob_to_absolute_corpus"
        `Quick
        normalize_glob_to_absolute_corpus;
    ]
end
