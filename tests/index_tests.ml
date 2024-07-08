open Docfd_lib
open Test_utils

module Qc = struct
  let to_of_compressed_check index =
    Index.equal
      index
      (Index.to_compressed index
       |> Index.of_compressed)

  let to_of_compressed_gen_from_pages task_pool =
    QCheck2.Test.make ~count:1000 ~name:"to_of_compressed_gen_from_pages"
      (index_gen_pages task_pool)
      to_of_compressed_check

  let to_of_compressed_gen_from_lines task_pool =
    QCheck2.Test.make ~count:1000 ~name:"to_of_compressed_gen_from_lines"
      (index_gen_lines task_pool)
      to_of_compressed_check

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
      (index_gen_pages task_pool)
      to_of_compressed_string_check

  let to_of_compressed_string_gen_from_lines task_pool =
    QCheck2.Test.make ~count:100 ~name:"to_of_compressed_string_gen_from_lines"
      (index_gen_lines task_pool)
      to_of_compressed_string_check

  let suite task_pool = [
    to_of_compressed_gen_from_pages task_pool;
    to_of_compressed_gen_from_lines task_pool;
    to_of_compressed_string_gen_from_pages task_pool;
    to_of_compressed_string_gen_from_lines task_pool;
  ]
end
