open Option_syntax

type 'a t =
  | Empty
  | Tree of {
      k : string;
      v : 'a;
      children : (int * 'a t) list;
    }

let empty : 'a t = Empty

let add (k : string) (v : 'a) (t : 'a t) : 'a t =
  let rec aux k t =
    match t with
    | Empty -> Tree { k; v; children = [] }
    | Tree t -> (
        if String.equal t.k k then (
          Tree t
        ) else (
          let dist = Spelll.edit_distance t.k k in
          let t' = Tree { k; v; children = [] } in
          match List.assoc_opt dist t.children with
          | None -> Tree { t with children = (dist, t') :: t.children }
          | Some t -> (
              aux k t
            )
        )
      )
  in
  aux k t

let find (k : string) (t : 'a t) : 'a option =
  let rec aux k t : 'a option =
    match t with
    | Empty -> None
    | Tree t -> (
        if String.equal t.k k then (
          Some t.v
        ) else (
          let dist = Spelll.edit_distance t.k k in
          let* child = List.assoc_opt dist t.children in
          aux k child
        )
      )
  in
  aux k t

let to_seq (t : 'a t) : (string * 'a) Seq.t =
  let rec aux t : (string * 'a) Seq.t =
    match t with
    | Empty -> Seq.empty
    | Tree { k; v; children } -> (
        List.to_seq children
        |> Seq.flat_map (fun (_dist, t) -> 
            aux t
          )
        |> Seq.cons (k, v)
      )
  in
  aux t

let union (t0 : 'a t) (t1 : 'a t) : 'a t =
  Seq.fold_left (fun t (k, v) ->
      add k v t
    )
    t0
    (to_seq t1)
