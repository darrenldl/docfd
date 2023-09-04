open Option_syntax

type 'a t = {
  k : string;
  v : 'a;
  children : (int * 'a t) list;
}

let add (k : string) (v : 'a) (t : 'a t) : 'a t =
  let rec aux k t =
    if String.equal t.k k then (
      t
    ) else (
      let dist = Spelll.edit_distance t.k k in
      let t' = { k; v; children = [] } in
      match List.assoc_opt dist t.children with
      | None -> { t with children = (dist, t') :: t.children }
      | Some t -> (
          aux k t
        )
    )
  in
  aux k t

let search (k : string) (t : 'a t) : 'a option =
  let rec aux k t : 'a option =
    if String.equal t.k k then (
      Some t.v
    ) else (
      let dist = Spelll.edit_distance t.k k in
      let* child = List.assoc_opt dist t.children in
      aux k child
    )
  in
  aux k t
