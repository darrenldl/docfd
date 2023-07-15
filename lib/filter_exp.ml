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

  let binary_op =
    choice [
      char '&' *> return And;
      char '|' *> return Or;
    ]

  let p =
    spaces *>
    fix (fun (exp : exp Angstrom.t) ->
        choice [
          (phrase >>| fun p -> Phrase p);
          (char '(' *> spaces *> exp <* spaces <* char ')' <* spaces);
          (exp <* spaces >>= fun e1 ->
           binary_op <* spaces >>= fun op ->
           exp <* spaces >>| fun e2 ->
           Binary_op (op, e1, e2));
        ]
      )
    <* spaces
end

let parse s =
  match Angstrom.(parse_string ~consume:Consume.All) Parsers.p s with
  | Ok e -> e
  | Error _ -> Phrase Search_phrase.empty
