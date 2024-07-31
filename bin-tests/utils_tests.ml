module Alco = struct
  let test_normalize_path_to_absolute_case0 =
    Alcotest.(check string)
    "case0"
    "/"
    (File_utils.normalize_path_to_absolute "/..")

  let suite =
    [
      Alcotest.test_case
      "test_normalize_path_to_absolute_case0"
      `Quick
      test_normalize_path_to_absolute_case0;
    ]
end
