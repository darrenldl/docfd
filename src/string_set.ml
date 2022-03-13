include CCSet.Make (struct
    type t = string

    let compare = String.compare
  end)
