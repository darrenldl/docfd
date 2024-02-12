type exp = [
  | `Word of string
  | `List of exp list
  | `Binary_op of binary_op * exp * exp
]

and binary_op =
  | Or

type t = {
  fuzzy_max_edit_distance : int;
  exp : exp;
  flattened : Search_phrase.t list;
}

let fuzzy_max_edit_distance (t : t) = t.fuzzy_max_edit_distance

let flattened (t : t) = t.flattened

let empty : t = {
  fuzzy_max_edit_distance = 0;
  exp = `List [];
  flattened = [];
}

let is_empty (t : t) =
  t.flattened = []

let equal (t1 : t) (t2 : t) =
  let rec aux (e1 : exp) (e2 : exp) =
    match e1, e2 with
    | `Word s1, `Word s2 -> String.equal s1 s2
    | `List l1, `List l2 -> List.equal aux l1 l2
    | `Binary_op (Or, e1x, e1y), `Binary_op (Or, e2x, e2y) ->
      aux e1x e2x && aux e1y e2y
    | _, _ -> false
  in
  aux t1.exp t2.exp

let as_word x : exp = `Word x

let as_list l : exp = `List l

let as_word_list (l : string list) : exp = as_list (List.map as_word l)

module Parsers = struct
  open Angstrom
  open Parser_components

  let phrase : string list Angstrom.t =
    many1 (
      take_while1 (fun c ->
          match c with
          | '|' | '\\' | '(' | ')' -> false
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

let flatten ~fuzzy_max_edit_distance (exp : exp) : Search_phrase.t list =
  let rec aux (exp : exp) : string Seq.t =
    match exp with
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
  in
  aux exp
  |> Seq.map (fun phrase -> Search_phrase.make ~fuzzy_max_edit_distance phrase)
  |> List.of_seq
  |> List.sort_uniq Search_phrase.compare

let make ~fuzzy_max_edit_distance s =
  let exp =
    match Angstrom.(parse_string ~consume:Consume.All) Parsers.p s with
    | Ok exp -> exp
    | Error _ -> `List []
  in
  { fuzzy_max_edit_distance;
    exp;
    flattened = flatten ~fuzzy_max_edit_distance exp;
  }
