open Docfd_lib

type t =
  | Empty
  | Path_date of Timedesc.Date.t
  | Path_fuzzy of Search_phrase.t
  | Path_glob of Glob.t
  | Ext of string
  | Binary_op of binary_op * t * t

and binary_op =
  | And
  | Or

let empty = Empty

let is_empty (e : t) =
  match e with
  | Empty -> true
  | _ -> false

let equal (e1 : t) (e2 : t) =
  let rec aux e1 e2 =
    match e1, e2 with
    | Empty, Empty -> true
    | Path_date x, Path_date y -> Timedesc.Date.equal x y
    | Path_fuzzy x, Path_fuzzy y -> Search_phrase.equal x y
    | Path_glob x, Path_glob y -> Glob.equal x y
    | Ext x, Ext y -> String.equal x y
    | Binary_op (op1, x1, y1), Binary_op (op2, x2, y2) ->
      op1 = op2 && aux x1 x2 && aux y1 y2
    | _, _ -> false
  in
  aux e1 e2

module Parsers = struct
  type exp = t

  open Angstrom
  open Parser_components

  let non_space_string = take_while1 is_not_space

  let maybe_quoted_string =
    (
      (choice
         [
           char '"';
           char '\'';
         ]
       >>= fun c -> return (Some c)
      )
      <|>
      return None
    )
    >>= fun quote_char ->
    many1 (
      take_while1 (fun c ->
          match c with
          | '\\' -> false
          | c -> (
              match quote_char with
              | None -> is_not_space c
              | Some quote_char -> c <> quote_char
            )
        )
      <|>
      (char '\\' *> any_char >>| fun c -> Printf.sprintf "%c" c)
    )
    >>= fun l ->
    let s = String.concat "" l in
    match quote_char with
    | None -> return s
    | Some quote_char -> char quote_char *> return s

  let search_exp =
    maybe_quoted_string
    >>| fun s ->
    Search_phrase.parse s

  let glob =
    maybe_quoted_string
    >>= fun s ->
    let s = Misc_utils.normalize_filter_glob_if_not_empty s in
    match Glob.parse s with
    | None -> fail ""
    | Some x -> return x

  let ext =
    maybe_quoted_string
    >>| fun s ->
    s
    |> String.lowercase_ascii
    |> String_utils.remove_leading_dots
    |> Fmt.str ".%s"

  let binary_op op_strings op =
    non_space_string >>= fun s ->
    skip_spaces *>
    (
      if List.mem (String.lowercase_ascii s) op_strings then (
        return (fun x y -> Binary_op (op, x, y))
      ) else (
        fail ""
      )
    )

  let and_op = binary_op [ "and"; "&&" ] And

  let or_op = binary_op [ "or"; "||" ] Or

  let p =
    skip_spaces *>
    (
      (end_of_input *> return empty)
      <|>
      fix (fun (exp : exp Angstrom.t) ->
          let base =
            choice [
              (string "path-fuzzy:" *>
               search_exp >>| fun x -> Path_fuzzy x);
              (string "path-glob:" *>
               glob >>| fun x -> Path_glob x);
              (string "ext:" *>
               ext >>| fun x -> Ext x);
              (char '(' *> skip_spaces *> exp <* char ')');
            ]
            <* skip_spaces
          in
          let conj = chainl1 base and_op in
          chainl1 conj or_op
        )
    )
    <* skip_spaces
end

let parse s =
  match Angstrom.(parse_string ~consume:Consume.All) Parsers.p s with
  | Ok e -> Some e
  | Error _ -> None
