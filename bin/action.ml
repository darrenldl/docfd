type t = [
  | `Drop_path of string
  | `Drop_listed
  | `Drop_unlisted
  | `Search of string
  | `Filter of string
]

let pp fmt (t : t) =
  match t with
  | `Drop_path s -> Fmt.pf fmt "drop path: %s" s
  | `Drop_listed -> Fmt.pf fmt "drop listed"
  | `Drop_unlisted -> Fmt.pf fmt "drop unlisted"
  | `Search s -> (
      if String.length s = 0 then (
        Fmt.pf fmt "clear search"
      ) else (
        Fmt.pf fmt "search: %s" s
      )
    )
  | `Filter s -> (
      if String.length s = 0 then (
        Fmt.pf fmt "clear filter"
      ) else (
        Fmt.pf fmt "filter: %s" s
      )
    )

let to_string (t : t) =
  Fmt.str "%a" pp t

module Parsers = struct
  type t' = t

  open Angstrom
  open Parser_components

  let p : t' Angstrom.t =
    choice [
      string "drop" *> skip_spaces *> (
        choice [
          string "path" *> skip_spaces *>
          char ':' *> any_string >>|
          (fun s -> (`Drop_path (String.trim s)));
          string "listed" *> skip_spaces *> return `Drop_listed;
          string "unlisted" *> skip_spaces *> return `Drop_unlisted;
        ]
      );
      string "clear" *> skip_spaces *> (
        choice [
          string "search" *> skip_spaces *> return (`Search "");
          string "filter" *> skip_spaces *> return (`Filter "");
        ]
      );
      string "search" *> skip_spaces *>
      char ':' *> skip_spaces *> (
        any_string >>| (fun s -> (`Search s))
      );
      string "filter" *> skip_spaces *>
      char ':' *> skip_spaces *> (
        any_string >>| (fun s -> (`Filter s))
      );
    ]
end

let of_string (s : string) : t option =
  match Angstrom.(parse_string ~consume:Consume.All) Parsers.p s with
  | Ok t -> Some t
  | Error _ -> None

let equal (x : t) (y : t) =
  match x, y with
  | `Drop_path x, `Drop_path y -> String.equal x y
  | `Drop_listed, `Drop_listed -> true
  | `Drop_unlisted, `Drop_unlisted -> true
  | `Search x, `Search y -> String.equal (String.trim x) (String.trim y)
  | `Filter x, `Filter y -> String.equal (CCString.ltrim x) (CCString.ltrim y)
  | _ -> false
