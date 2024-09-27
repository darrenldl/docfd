open Docfd_lib
open Test_utils

module Alco = struct
  let test_index name index =
    let index' =
      let buf = Buffer.create 4096 in
      Index.encode buf index;
      Index.decode (Buffer.contents buf) (ref 0)
    in
    let index'' = index
                  |> Index.to_compressed_string
                  |> Index.of_compressed_string
                  |> Option.get
    in
    Alcotest.(check bool)
      name
      true
      (Index.equal index index'
       &&
       Index.equal index index'')

  let test_empty_case0 task_pool () =
    List.to_seq []
    |> Index.of_lines task_pool
    |> test_index "case0"

  let test_empty_case1 task_pool () =
    List.to_seq []
    |> Index.of_pages task_pool
    |> test_index "case1"

  let test_empty_case2 task_pool () =
    List.to_seq [ [] ]
    |> Index.of_pages task_pool
    |> test_index "case2"

  let suite task_pool =
    [
      Alcotest.test_case "test_empty_case0" `Quick (test_empty_case0 task_pool);
      Alcotest.test_case "test_empty_case1" `Quick (test_empty_case1 task_pool);
      Alcotest.test_case "test_empty_case2" `Quick (test_empty_case2 task_pool);
    ]
end

module Qc = struct
  let encode_decode_check index =
    let index' =
      let buf = Buffer.create 4096 in
      Index.encode buf index;
      Index.decode (Buffer.contents buf) (ref 0)
    in
    Index.equal
      index
      index'

  let encode_decode_gen_from_pages task_pool =
    QCheck2.Test.make ~count:1000 ~name:"encode_decode_gen_from_pages"
      (index_gen_from_pages task_pool)
      encode_decode_check

  let encode_decode_gen_from_lines task_pool =
    QCheck2.Test.make ~count:1000 ~name:"encode_decode_gen_from_lines"
      (index_gen_from_lines task_pool)
      encode_decode_check

  let to_of_compressed_string_check index =
    match
      Index.to_compressed_string index
      |> Index.of_compressed_string
    with
    | None -> false
    | Some index' -> (
        Index.equal index index'
      )

  let to_of_compressed_string_gen_from_pages task_pool =
    QCheck2.Test.make ~count:100 ~name:"to_of_compressed_string_gen_from_pages"
      (index_gen_from_pages task_pool)
      to_of_compressed_string_check

  let to_of_compressed_string_gen_from_lines task_pool =
    QCheck2.Test.make ~count:100 ~name:"to_of_compressed_string_gen_from_lines"
      (index_gen_from_lines task_pool)
      to_of_compressed_string_check

  let suite task_pool =
    [
      encode_decode_gen_from_pages task_pool;
      encode_decode_gen_from_lines task_pool;
      to_of_compressed_string_gen_from_pages task_pool;
      to_of_compressed_string_gen_from_lines task_pool;
    ]
end
