include CCHeap.Make (struct
    type t = Search_result.t

    let leq x y =
      (Search_result.score x) <= (Search_result.score y)
  end)
