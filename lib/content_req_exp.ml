type t =
  | Phrase of Search_phrase.t
  | Binary_op of binary_op * t * t

and binary_op =
  | And
  | Or

let empty = Phrase Search_phrase.empty

let is_empty (e : t) =
  match e with
  | Phrase p -> Search_phrase.is_empty p
  | _ -> false

let equal (e1 : t) (e2 : t) =
  let rec aux e1 e2 =
    match e1, e2 with
    | Phrase p1, Phrase p2 -> Search_phrase.equal p1 p2
    | Binary_op (op1, x1, y1), Binary_op (op2, x2, y2) ->
      op1 = op2 && aux x1 x2 && aux y1 y2
    | _, _ -> false
  in
  aux e1 e2

module Parsers = struct
  type exp = t

  open Angstrom
  open Parser_components

  let phrase =
    many1 (
      take_while1 (fun c ->
          match c with
          | '&' | '|' | '\\' | '(' | ')' -> false
          | _ -> true
        )
      <|>
      (char '\\' *> any_char >>| fun c -> Printf.sprintf "%c" c)
    )
    >>| fun l ->
    let phrase = String.concat "" l in
    Search_phrase.make ~fuzzy_max_edit_distance:0 ~phrase

  let and_op =
    char '&' *> spaces *> return (fun x y -> Binary_op (And, x, y))

  let or_op =
    char '|' *> spaces *> return (fun x y -> Binary_op (Or, x, y))

  let p =
    spaces *>
    fix (fun (exp : exp Angstrom.t) ->
        let base =
          choice [
            (end_of_input *> return empty);
            (phrase >>| fun p -> Phrase p);
            (char '(' *> spaces *> exp <* char ')' <* spaces);
          ]
        in
        let conj = chainl1 base and_op in
        chainl1 conj or_op
      )
    <* spaces
end

let parse s =
  match Angstrom.(parse_string ~consume:Consume.All) Parsers.p s with
  | Ok e -> e
  | Error _ -> Phrase Search_phrase.empty
