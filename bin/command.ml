type t = [
  | `Mark of string
  | `Unmark of string
  | `Unmark_all
  | `Drop of string
  | `Drop_all_except of string
  | `Drop_marked
  | `Drop_unmarked
  | `Drop_listed
  | `Drop_unlisted
  | `Narrow_level of int
  | `Search of string
  | `Filter of string
]

let pp fmt (t : t) =
  match t with
  | `Mark s -> Fmt.pf fmt "mark: %s" s
  | `Unmark s -> Fmt.pf fmt "unmark: %s" s
  | `Unmark_all -> Fmt.pf fmt "unmark all"
  | `Drop s -> Fmt.pf fmt "drop: %s" s
  | `Drop_all_except s -> Fmt.pf fmt "drop all except: %s" s
  | `Drop_marked -> Fmt.pf fmt "drop marked"
  | `Drop_unmarked -> Fmt.pf fmt "drop unmarked"
  | `Drop_listed -> Fmt.pf fmt "drop listed"
  | `Drop_unlisted -> Fmt.pf fmt "drop unlisted"
  | `Narrow_level x -> Fmt.pf fmt "narrow level: %d" x
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

  let any_string_trimmed =
    any_string >>| String.trim

  let p : t' Angstrom.t =
    skip_spaces *>
    choice [
      string "mark" *> skip_spaces *>
      char ':' *> skip_spaces *>
      any_string_trimmed >>| (fun s -> (`Mark s));
      string "unmark" *> skip_spaces *> (
        choice [
          string "all" *> skip_spaces *> return `Unmark_all;
          char ':' *> skip_spaces *>
          any_string_trimmed >>| (fun s -> (`Unmark s));
        ]
      );
      string "drop" *> skip_spaces *> (
        choice [
          char ':' *> skip_spaces *>
          any_string_trimmed >>| (fun s -> (`Drop s));
          string "all" *> skip_spaces *>
          string "except" *> skip_spaces *> char ':' *> skip_spaces *>
          any_string_trimmed >>| (fun s -> (`Drop_all_except s));
          string "listed" *> skip_spaces *> return `Drop_listed;
          string "unlisted" *> skip_spaces *> return `Drop_unlisted;
          string "marked" *> skip_spaces *> return `Drop_marked;
          string "unmarked" *> skip_spaces *> return `Drop_unmarked;
        ]
      );
      string "narrow" *> skip_spaces *> (
        choice [
          string "level" *> skip_spaces *>
          char ':' *> skip_spaces *>
          satisfy (function '0'..'9' -> true | _ -> false) <* skip_spaces >>|
          (fun c -> `Narrow_level (Char.code c - Char.code '0'));
        ]
      );
      string "clear" *> skip_spaces *> (
        choice [
          string "search" *> skip_spaces *> return (`Search "");
          string "filter" *> skip_spaces *> return (`Filter "");
        ]
      );
      string "search" *> skip_spaces *>
      char ':' *> skip_spaces *>
      any_string_trimmed >>| (fun s -> (`Search s));
      string "filter" *> skip_spaces *>
      char ':' *> skip_spaces *>
      any_string_trimmed >>| (fun s -> (`Filter s));
    ]
end

let of_string (s : string) : t option =
  match Angstrom.(parse_string ~consume:Consume.All) Parsers.p s with
  | Ok t -> Some t
  | Error _ -> None

let equal (x : t) (y : t) =
  match x, y with
  | `Drop x, `Drop y -> String.equal x y
  | `Drop_all_except x, `Drop_all_except y -> String.equal x y
  | `Drop_listed, `Drop_listed -> true
  | `Drop_unlisted, `Drop_unlisted -> true
  | `Narrow_level x, `Narrow_level y -> Int.equal x y
  | `Search x, `Search y -> String.equal (String.trim x) (String.trim y)
  | `Filter x, `Filter y -> String.equal (String.trim x) (String.trim y)
  | _, _ -> false
