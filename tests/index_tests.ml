open Docfd_lib
open Test_utils

module Qc = struct
  let to_of_compressed task_pool =
    QCheck2.Test.make ~count:100 ~name:"to_of_compressed"
      (index_gen task_pool)
      (fun index ->
         let index' = Index.to_compressed index
                      |> Index.of_compressed
         in
         Index.equal index index'
      )

  let to_of_compressed_string task_pool =
    QCheck2.Test.make ~count:100 ~name:"to_of_compressed_string"
      (index_gen task_pool)
      (fun index ->
         match
           Index.to_compressed_string index
           |> Index.of_compressed_string
         with
         | None -> false
         | Some index' -> (
             Index.equal index index'
           )
      )

  let suite task_pool = [
    to_of_compressed task_pool;
    to_of_compressed_string task_pool;
  ]
end
