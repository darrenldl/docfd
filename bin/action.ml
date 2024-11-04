type t = [
  | `Drop_path of string
  | `Drop_listed
  | `Drop_unlisted
  | `Search of string
  | `Filter of string
]

let pp_escaped fmt (s : string) =
  let has_single_quote = String.contains s '\'' in
  let has_double_quote = String.contains s '"' in
  if has_single_quote && has_double_quote then (
    Fmt.pf fmt "\"";
    String.iter (fun c ->
      if c = '"' then (
         Fmt.pf fmt "\\"
      );
      Fmt.pf fmt "%c" c
    ) s;
    Fmt.pf fmt "\"";
  ) else if has_double_quote then (
    Fmt.pf fmt "'%s'" s;
  ) else (
    Fmt.pf fmt "\"%s\"" s;
  )

let pp fmt (t : t) =
  match t with
  | `Drop_path s -> Fmt.pf fmt "drop path %a" pp_escaped s
  | `Drop_listed -> Fmt.pf fmt "drop listed"
  | `Drop_unlisted -> Fmt.pf fmt "drop unlisted"
  | `Search s -> (
      if String.length s = 0 then (
        Fmt.pf fmt "clear search"
      ) else (
        Fmt.pf fmt "search %a" pp_escaped s
      )
    )
  | `Filter s -> (
      if String.length s = 0 then (
        Fmt.pf fmt "clear filter"
      ) else (
        Fmt.pf fmt "filter %a" pp_escaped s
      )
    )

let to_string (t : t) =
  Fmt.str "%a" pp t

module Parsers = struct
  type t' = t

  open Angstrom
  open Parser_components

  let quoted_string =
    let aux quote_char =
    (char quote_char *>
    (
    many1 (
      take_while1 (fun c ->
        c <> '\\' && c <> quote_char
      )
      <|>
      (char '\\' *> any_char >>| fun c -> Printf.sprintf "%c" c)
    )
    )
    <* char quote_char <* skip_spaces)
    >>| fun l -> String.concat "" l
    in
    choice [
      aux '\'';
     aux '"';
    ]

  let p : t' Angstrom.t =
    choice [
      string "drop" *> skip_spaces *> (
        choice [
          string "path" *> skip_spaces *> quoted_string >>| (fun s -> (`Drop_path s));
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
      string "search" *> skip_spaces *> (
        quoted_string >>| (fun s -> (`Search s))
      );
      string "filter" *> skip_spaces *> (
        quoted_string >>| (fun s -> (`Filter s))
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
