type match_typ_marker = [ `Exact | `Prefix | `Suffix ]
[@@deriving show]

type exp = [
  | `Annotated_token of Search_phrase.annotated_token
  | `Word of string
  | `Match_typ_marker of match_typ_marker
  | `List of exp list
  | `Paren of exp
  | `Binary_op of binary_op * exp * exp
  | `Optional of exp
]
[@@deriving show]

and binary_op =
  | Or
[@@deriving show]

let char_of_match_typ_marker (x : match_typ_marker) =
  match x with
  | `Exact -> '\''
  | `Prefix -> '^'
  | `Suffix -> '$'

let string_of_match_typ_marker (x : match_typ_marker) =
  match x with
  | `Exact -> "\'"
  | `Prefix -> "^"
  | `Suffix -> "$"

type t = {
  max_fuzzy_edit_dist : int;
  exp : exp;
  flattened : Search_phrase.t list;
}
[@@deriving show]

let max_fuzzy_edit_dist (t : t) = t.max_fuzzy_edit_dist

let flattened (t : t) = t.flattened

let empty : t = {
  max_fuzzy_edit_dist = 0;
  exp = `List [];
  flattened = [];
}

let is_empty (t : t) =
  t.flattened = []
  ||
  List.for_all Search_phrase.is_empty t.flattened

let equal (t1 : t) (t2 : t) =
  let rec aux (e1 : exp) (e2 : exp) =
    match e1, e2 with
    | `Annotated_token x1, `Annotated_token x2 ->
      String.equal x1.string x2.string
    | `Word x1, `Word x2 -> String.equal x1 x2
    | `List l1, `List l2 -> List.equal aux l1 l2
    | `Paren e1, `Paren e2 -> aux e1 e2
    | `Binary_op (Or, e1x, e1y), `Binary_op (Or, e2x, e2y) ->
      aux e1x e2x && aux e1y e2y
    | `Optional e1, `Optional e2 -> aux e1 e2
    | _, _ -> false
  in
  aux t1.exp t2.exp

let as_paren x : exp = `Paren x

let as_list l : exp = `List l

let as_word s : exp = `Word s

let as_word_list (l : string list) : exp = `List (List.map as_word  l)

module Parsers = struct
  open Angstrom
  open Parser_components

  let phrase : string list Angstrom.t =
    many1 (
      take_while1 (fun c ->
          match c with
          | '?' | '|' | '\\' | '(' | ')' | '\'' | '^' | '$' -> false
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
    fix (fun (exp : exp Angstrom.t) : exp Angstrom.t ->
        let base =
          choice [
            (phrase >>| as_word_list);
            (char '\'' *> return (`Match_typ_marker `Exact));
            (char '^' *> return (`Match_typ_marker `Prefix));
            (char '$' *> return (`Match_typ_marker `Suffix));
            (string "()" *> return (as_word_list []));
            (char '(' *> exp <* char ')' >>| as_paren);
          ]
        in
        let opt_base =
          choice [
            (char '?' *> skip_spaces *> phrase
             >>| fun l ->
             match l with
             | [] -> failwith "unexpected case"
             | x :: xs -> (
                 as_list [ `Optional (as_word x); as_word_list xs ]
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

let process_match_typ_markers group_id (l : exp list) : exp list =
  let rec aux acc l =
    match l with
    | [] -> List.rev acc
    | x0 :: xs0 -> (
        match x0 with
        | `Match_typ_marker `Exact
        | `Match_typ_marker `Prefix as x0 -> (
            let match_typ =
              match (x0 : [ `Match_typ_marker of [ `Exact | `Prefix ] ]) with
              | `Match_typ_marker x -> (x :> Search_phrase.match_typ)
            in
            match xs0 with
            | `Word x1 :: xs1 -> (
                if Parser_components.is_space (String.get x1 0) then (
                  aux (`Word x1 :: x0 :: acc) xs1
                ) else (
                  aux
                    (`Annotated_token Search_phrase.{ string = x1; group_id; match_typ } :: acc)
                    xs1
                )
              )
            | `Match_typ_marker x1 :: xs1 -> (
                aux
                  (`Annotated_token Search_phrase.{ string = string_of_match_typ_marker x1; group_id; match_typ } :: acc)
                  xs1
              )
            | _ -> aux (x0 :: acc) xs0
          )
        | `Match_typ_marker `Suffix -> (
            let modify_acc acc : exp list =
              match acc with
              | [] -> [ x0 ]
              | `Word y :: ys -> (
                  if Parser_components.is_space (String.get y 0) then (
                    x0 :: acc
                  ) else (
                    `Annotated_token Search_phrase.{ string = y; group_id; match_typ = `Suffix } :: ys
                  )
                )
              | `Match_typ_marker y :: ys ->
                `Annotated_token Search_phrase.{ string = string_of_match_typ_marker y; group_id; match_typ = `Suffix } :: ys
              | _ -> x0 :: acc
            in
            let end_of_phrase =
              match xs0 with
              | [] -> true
              | `Word x1 :: _ -> Parser_components.is_space (String.get x1 0)
              | _ -> false
            in
            if end_of_phrase then
              aux (modify_acc acc) xs0
            else
              aux (x0 :: acc) xs0
          )
        | _ -> (
            aux (x0 :: acc) xs0
          )
      )
  in
  aux [] l

let flatten_nested_lists (exp : exp) : exp =
  let rec aux (exp : exp) =
    match exp with
    | `Annotated_token _
    | `Word _
    | `Match_typ_marker _ -> exp
    | `List l -> (
        `List
          (CCList.flat_map (fun e ->
               match aux e with
               | `List l -> l
               | x -> [ x ]
             ) l)
      )
    | `Paren e -> `Paren (aux e)
    | `Binary_op (op, x, y) -> `Binary_op (op, aux x, aux y)
    | `Optional e -> `Optional (aux e)
  in
  aux exp

let flatten ~max_fuzzy_edit_dist (exp : exp) : Search_phrase.t list =
  let get_group_id =
    let counter = ref 0 in
    fun () ->
      let x = !counter in
      counter := x + 1;
      x
  in
  let atom string group_id =
    Seq.return [ Search_phrase.{ string; group_id; match_typ = `Fuzzy } ]
  in
  let rec aux group_id (exp : exp) : Search_phrase.annotated_token list Seq.t =
    match exp with
    | `Annotated_token x -> Seq.return [ x ]
    | `Match_typ_marker x -> (
        atom
          (string_of_match_typ_marker x)
          group_id
      )
    | `Word string ->
      atom string group_id
    | `List l -> (
        l
        |> process_match_typ_markers group_id
        |> List.to_seq
        |> Seq.map (aux group_id)
        |> OSeq.cartesian_product
        |> Seq.map List.concat
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
      |> Search_phrase.of_annotated_tokens ~max_fuzzy_edit_dist)
  |> List.of_seq
  |> List.sort_uniq Search_phrase.compare

let make ~max_fuzzy_edit_dist s =
  if String.length s = 0 || String.for_all Parser_components.is_space s then (
    Some empty
  ) else (
    match Angstrom.(parse_string ~consume:Consume.All) Parsers.p s with
    | Ok exp -> (
        let exp = flatten_nested_lists exp in
        Some
          { max_fuzzy_edit_dist;
            exp;
            flattened = flatten ~max_fuzzy_edit_dist exp;
          }
      )
    | Error _ -> None
  )
