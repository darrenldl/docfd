type exp = [
  | `Word of string
  | `List of exp list
  | `Paren of exp
  | `Binary_op of binary_op * exp * exp
  | `Optional of exp
]

and binary_op =
  | Or

type t = {
  fuzzy_max_edit_dist : int;
  exp : exp;
  flattened : Search_phrase.t list;
}

let fuzzy_max_edit_dist (t : t) = t.fuzzy_max_edit_dist

let flattened (t : t) = t.flattened

let empty : t = {
  fuzzy_max_edit_dist = 0;
  exp = `List [];
  flattened = [];
}

let is_empty (t : t) =
  (t.flattened = [])
  ||
  (List.for_all Search_phrase.is_empty t.flattened)

let equal (t1 : t) (t2 : t) =
  let rec aux (e1 : exp) (e2 : exp) =
    match e1, e2 with
    | `Word s1, `Word s2 -> String.equal s1 s2
    | `List l1, `List l2 -> List.equal aux l1 l2
    | `Paren e1, `Paren e2 -> aux e1 e2
    | `Binary_op (Or, e1x, e1y), `Binary_op (Or, e2x, e2y) ->
      aux e1x e2x && aux e1y e2y
    | `Optional e1, `Optional e2 -> aux e1 e2
    | _, _ -> false
  in
  aux t1.exp t2.exp

let as_word x : exp = `Word x

let as_paren x : exp = `Paren x

let as_list l : exp = `List l

let as_word_list (l : string list) : exp = as_list (List.map as_word l)

module Parsers = struct
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
    |> Tokenize.tokenize ~drop_spaces:false
    |> List.of_seq

  let or_op =
    char '|' *> skip_spaces *> return (fun x y -> `Binary_op (Or, x, y))

  let p : exp Angstrom.t =
    skip_spaces *>
    fix (fun (exp : exp Angstrom.t) : exp Angstrom.t ->
        let base =
          choice [
            (phrase >>| as_word_list);
            (char '(' *> skip_spaces *> exp <* char ')' <* skip_spaces
             >>| as_paren);
          ]
        in
        let opt_base =
          choice [
            (char '?' *> skip_spaces *> phrase
             >>| fun l ->
             match l with
             | [] -> `Optional (`List [])
             | x :: xs -> (
                 `List ((`Optional (as_word x)) :: List.map as_word xs)
               )
            );
            (char '?' *> skip_spaces *> base >>| fun p -> `Optional p);
            base;
          ]
        in
        let opt_bases =
          many1 opt_base
          >>| fun l -> `List l
        in
        chainl1 opt_bases or_op
      )
    <* skip_spaces
end

let flatten ~fuzzy_max_edit_dist (exp : exp) : Search_phrase.t list =
  let get_group_id =
    let counter = ref 0 in
    fun () ->
      let x = !counter in
      counter := x + 1;
      x
  in
  let rec aux group_id (exp : exp) : Search_phrase.annotated_token list Seq.t =
    match exp with
    | `Word string -> Seq.return [ Search_phrase.{ string; group_id } ]
    | `List l -> (
        match l with
        | [] -> Seq.empty
        | _ -> (
            List.to_seq l
            |> Seq.map (aux group_id)
            |> OSeq.cartesian_product
            |> Seq.map List.concat
          )
      )
    | `Paren e -> (
        aux (get_group_id ()) e
      )
    | `Binary_op (Or, x, y) -> (
        Seq.append
          (aux group_id x)
          (aux group_id y)
      )
    | `Optional x -> (
        Seq.cons [] (aux (get_group_id ()) x)
      )
  in
  aux (get_group_id ()) exp
  |> Seq.map (fun l ->
      List.to_seq l
      |> Search_phrase.of_annotated_tokens ~fuzzy_max_edit_dist)
  |> List.of_seq
  |> List.sort_uniq Search_phrase.compare

let make ~fuzzy_max_edit_dist s =
  if String.length s = 0 || String.for_all (fun c -> c = ' ') s then (
    Some empty
  ) else (
    match Angstrom.(parse_string ~consume:Consume.All) Parsers.p s with
    | Ok exp -> (
        Some
          { fuzzy_max_edit_dist;
            exp;
            flattened = flatten ~fuzzy_max_edit_dist exp;
          }
      )
    | Error _ -> None
  )
