open Docfd_lib

type t =
  | Empty
  | Path_date of compare_op * Timedesc.Date.t
  | Path_fuzzy of Search_exp.t
  | Path_glob of Glob.t
  | Ext of string
  | Content of Search_exp.t
  | Binary_op of binary_op * t * t
  | Unary_op of unary_op * t

and binary_op =
  | And
  | Or

and unary_op =
  | Not

and compare_op =
  | Eq
  | Le
  | Ge
  | Lt
  | Gt

let empty = Empty

let is_empty (e : t) =
  match e with
  | Empty -> true
  | _ -> false

let equal (e1 : t) (e2 : t) =
  let rec aux e1 e2 =
    match e1, e2 with
    | Empty, Empty -> true
    | Path_date (op1, x1), Path_date (op2, x2) ->
      op1 = op2 && Timedesc.Date.equal x1 x2
    | Path_fuzzy x, Path_fuzzy y -> Search_exp.equal x y
    | Path_glob x, Path_glob y -> Glob.equal x y
    | Ext x, Ext y -> String.equal x y
    | Content x, Content y -> Search_exp.equal x y
    | Binary_op (op1, x1, y1), Binary_op (op2, x2, y2) ->
      op1 = op2 && aux x1 x2 && aux y1 y2
    | Unary_op (op1, x1), Unary_op (op2, x2) ->
      op1 = op2 && aux x1 x2
    | _, _ -> false
  in
  aux e1 e2

module Parsers = struct
  type exp = t

  open Angstrom
  open Parser_components

  let alphanum_symbol_string =
    take_while1 (fun c ->
        is_letter c
        ||
        is_digit c
        ||
        (match c with
         | '&'
         | '|' -> true
         | _ -> false
        )
      )

  let maybe_quoted_string ?(force_quote = false) () =
    (
      (choice
         [
           char '"';
           char '\'';
         ]
       >>= fun c -> return (Some c)
      )
      <|>
      (if force_quote then
         fail ""
       else
         return None)
    )
    >>= fun quote_char ->
    many1 (
      take_while1 (fun c ->
          match c with
          | '\\' -> false
          | c -> (
              match quote_char with
              | None -> (
                  is_not_space c
                  &&
                  (match c with
                   | '('
                   | ')' -> false
                   | _ -> true
                  )
                )
              | Some quote_char -> c <> quote_char
            )
        )
      <|>
      (char '\\' *> any_char >>| fun c -> Printf.sprintf "%c" c)
    )
    >>= fun l ->
    let s = String.concat "" l in
    (end_of_input *> return s)
    <|>
    (match quote_char with
     | None -> return s
     | Some quote_char -> char quote_char *> return s)

  let search_exp ?force_quote () =
    maybe_quoted_string ?force_quote ()
    >>= fun s ->
    match Search_exp.parse s with
    | None -> fail ""
    | Some x -> return x

  let glob =
    maybe_quoted_string ()
    >>= fun s ->
    let s = Misc_utils.normalize_filter_glob_if_not_empty s in
    match Glob.parse s with
    | None -> fail ""
    | Some x -> return x

  let ext =
    maybe_quoted_string ()
    >>| fun s ->
    s
    |> String.lowercase_ascii
    |> String_utils.remove_leading_dots
    |> Fmt.str ".%s"

  let compare_op =
    choice
      [
        char '=' *> skip_spaces *> return Eq;
        string "<=" *> skip_spaces *> return Le;
        string ">=" *> skip_spaces *> return Ge;
        char '<' *> skip_spaces *> return Lt;
        char '>' *> skip_spaces *> return Gt;
      ]

  let date =
    any_string
    >>= fun s ->
    match Timedesc.Date.Ymd.of_iso8601 s with
    | Ok x -> return x
    | Error _ -> fail ""

  let path_date =
    let p =
      compare_op >>= fun op ->
      date >>| fun date ->
      Path_date (op, date)
    in
    maybe_quoted_string ()
    >>= fun s ->
    match Angstrom.(parse_string ~consume:Consume.All) p s with
    | Ok x -> return x
    | Error s -> fail s

  let binary_op op_strings op =
    alphanum_symbol_string >>= fun s ->
    skip_spaces *>
    (
      if List.mem (String.lowercase_ascii s) op_strings then (
        return (fun x y -> Binary_op (op, x, y))
      ) else (
        fail ""
      )
    )

  let and_op = binary_op [ "and" ] And

  let or_op = binary_op [ "or" ] Or

  let unary_op op_strings op =
    alphanum_symbol_string >>= fun s ->
    skip_spaces *>
    (
      if List.mem (String.lowercase_ascii s) op_strings then (
        return (fun x -> Unary_op (op, x))
      ) else (
        fail ""
      )
    )

  let not_op = unary_op [ "not" ] Not

  let p =
    skip_spaces *>
    (
      (end_of_input *> return empty)
      <|>
      fix (fun (exp : exp Angstrom.t) ->
          let base =
            choice [
              (search_exp ~force_quote:true () >>|
               fun x -> Content x);
              (string "content:" *>
               search_exp () >>| fun x -> Content x);
              (string "path-date:" *> path_date);
              (string "path-fuzzy:" *>
               search_exp () >>| fun x -> Path_fuzzy x);
              (string "path-glob:" *>
               glob >>| fun x -> Path_glob x);
              (string "ext:" *>
               ext >>| fun x -> Ext x);
              (char '(' *> skip_spaces *> exp <* char ')');
              (not_op >>= fun f ->
               skip_spaces *> exp >>| f);
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
