type t = [
  | `Word of string
  | `List of t list
  | `Binary_op of binary_op * t * t
  | `Optional of t
]

and binary_op =
  | Or

let as_word x : t = `Word x

let as_list l : t = `List l

let as_word_list (l : string list) : t = as_list (List.map as_word l)

module Parsers = struct
  type exp = t

  open Angstrom
  open Parser_components

  let phrase : string list Angstrom.t =
    many1 (
      take_while1 (fun c ->
          match c with
          | '?' | '|' | '\\' | '(' | ')' -> false
          | _ -> true
        )
      <|>
      (char '\\' *> any_char >>| fun c -> Printf.sprintf "%c" c)
    )
    >>| fun l ->
    String.concat "" l
    |> Tokenize.f ~drop_spaces:true
    |> List.of_seq

  let or_op =
    char '|' *> spaces *> return (fun x y -> `Binary_op (Or, x, y))

  let p : exp Angstrom.t =
    spaces *>
    fix (fun (exp : exp Angstrom.t) : exp Angstrom.t ->
        let base =
          choice [
            (char '?' *> spaces *> phrase
             >>| fun l ->
             match l with
             | [] -> `Optional (`List [])
             | x :: xs -> (
                 `List ((`Optional (as_word x)) :: List.map as_word xs)
               )
            );
            (char '?' *> spaces *> exp >>| fun p -> `Optional p);
            (phrase >>| as_word_list);
            (char '(' *> spaces *> exp <* char ')' <* spaces);
          ]
        in
        let bases =
          many1 base
          >>| fun l -> `List l
        in
        chainl1 bases or_op
      )
    <* spaces
end

let flatten ~fuzzy_max_edit_distance (t : t) : Search_phrase.t list =
  let rec aux (t : t) : string Seq.t =
    match t with
    | `Word s -> Seq.return s
    | `List l -> (
        match l with
        | [] -> Seq.empty
        | _ -> (
            List.to_seq l
            |> Seq.map aux
            |> OSeq.cartesian_product
            |> Seq.map (fun words ->
                String.concat " " words
              )
          )
      )
    | `Binary_op (Or, x, y) -> (
        Seq.append
          (aux x)
          (aux y)
      )
    | `Optional x -> (
        Seq.cons "" (aux x)
      )
  in
  aux t
  |> Seq.map (fun phrase -> Search_phrase.make ~fuzzy_max_edit_distance ~phrase)
  |> List.of_seq
  |> List.sort_uniq Search_phrase.compare

let parse s =
  match Angstrom.(parse_string ~consume:Consume.All) Parsers.p s with
  | Ok e -> e
  | Error _ -> `List []
