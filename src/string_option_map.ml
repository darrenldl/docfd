include CCMap.Make (struct
  type t = string option

  let compare x y =
    match x, y with
    | None, None -> 0
    | None, Some _ -> -1
    | Some _, None -> 1
    | Some x, Some y -> String.compare x y
end)
