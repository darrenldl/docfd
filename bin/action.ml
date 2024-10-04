type t = [
  | `Drop_path of string
  | `Drop_listed
  | `Drop_unlisted
  | `Search of string
  | `Filter of string
]

let to_string (t : t) =
  match t with
  | `Drop_path s -> Fmt.str "drop path %s" s
  | `Drop_listed -> "drop listed"
  | `Drop_unlisted -> "drop unlisted"
  | `Search s -> Fmt.str "search %s" s
  | `Filter s -> Fmt.str "filter %s" s

let of_string (s : string) : t option =
  let skip_spaces l =
    let rec aux l =
      match l with
      | "" :: l -> aux l
      | _ -> l
    in
    aux l
  in
  let f l = skip_spaces l |> String.concat " " in
  let l = String.split_on_char ' ' s in
  match skip_spaces l with
  | "drop" :: l -> (
      match skip_spaces l with
      | "path" :: [] -> None
      | "path" :: l -> Some (`Drop_path (f l))
      | "listed" :: [] -> Some `Drop_listed
      | "unlisted" :: [] -> Some `Drop_unlisted
      | _ -> None
    )
  | "search" :: l -> Some (`Search (f l))
  | "filter" :: l -> Some (`Filter (f l))
  | _ -> None

let equal (x : t) (y : t) =
  match x, y with
  | `Drop_path x, `Drop_path y -> String.equal x y
  | `Drop_listed, `Drop_listed -> true
  | `Drop_unlisted, `Drop_unlisted -> true
  | `Search x, `Search y -> String.equal (String.trim x) (String.trim y)
  | `Filter x, `Filter y -> String.equal (CCString.ltrim x) (CCString.ltrim y)
  | _ -> false
