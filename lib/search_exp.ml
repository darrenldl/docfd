type match_typ_marker = [ `Exact | `Prefix | `Suffix ]
[@@deriving show]

type exp =
  | Sub of sub
  | And_show_both of exp * exp
  | And_hide_left of exp * exp
[@@deriving show]

and sub = [
  | `Word of string
  | `Match_typ_marker of match_typ_marker
  | `Explicit_spaces
  | `List of sub list
  | `Paren of sub
  | `Binary_op of binary_op * sub * sub
  | `Optional of sub
]
[@@deriving show]

and binary_op =
  | Or
[@@deriving show]

type flattened = {
  hidden : Search_phrase.t list list;
  visible : Search_phrase.t list list;
}
[@@deriving show]

type t = {
  exp : exp;
  flattened : flattened;
}
[@@deriving show]

let flattened (t : t) = t.flattened

let empty_flattened : flattened = {
  hidden = [];
  visible = [];
}

let flattened_is_empty (x : flattened) =
  List.is_empty x.hidden
  &&
  List.is_empty x.visible

let empty : t = {
  exp = Sub (`List []);
  flattened = empty_flattened;
}

let is_empty (t : t) =
  flattened_is_empty t.flattened
  ||
  (
    List.for_all (List.for_all Search_phrase.is_empty) t.flattened.hidden
    && 
    List.for_all (List.for_all Search_phrase.is_empty) t.flattened.visible
  )

let equal_sub (e1 : sub) (e2 : sub) =
  let rec aux (e1 : sub) (e2 : sub) =
    match e1, e2 with
    | `Word x1, `Word x2 -> String.equal x1 x2
    | `List l1, `List l2 -> List.equal aux l1 l2
    | `Paren e1, `Paren e2 -> aux e1 e2
    | `Binary_op (Or, e1x, e1y), `Binary_op (Or, e2x, e2y) ->
      aux e1x e2x && aux e1y e2y
    | `Optional e1, `Optional e2 -> aux e1 e2
    | _, _ -> false
  in
  aux e1 e2

let equal (t1 : t) (t2 : t) =
  let rec aux (e1 : exp) (e2 : exp) =
    match e1, e2 with
    | Sub s1, Sub s2 -> equal_sub s1 s2
    | And_show_both (x1, y1), And_show_both (x2, y2) ->
      aux x1 x2 && aux y1 y2
    | And_hide_left (x1, y1), And_hide_left (x2, y2) ->
      aux x1 x2 && aux y1 y2
    | _, _ -> false
  in
  aux t1.exp t2.exp

let as_paren x : sub = `Paren x

let as_list l : sub = `List l

let as_word s : sub = `Word s

let as_word_list (l : string list) : sub = `List (List.map as_word  l)

module Parsers = struct
  open Angstrom
  open Parser_components

  let phrase : string list Angstrom.t =
    many1 (
      take_while1 (fun c ->
          match c with
          | '?'
          | '|'
          | '\\'
          | '('
          | ')'
          | '\''
          | '^'
          | '$'
          | '~'
          | '&' -> false
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

  let sub : sub Angstrom.t =
    fix (fun (sub : sub Angstrom.t) : sub Angstrom.t ->
        let base =
          choice [
            (phrase >>| as_word_list);
            (char '\'' *> return (`Match_typ_marker `Exact));
            (char '^' *> return (`Match_typ_marker `Prefix));
            (char '$' *> return (`Match_typ_marker `Suffix));
            (char '~' *> return (`Explicit_spaces));
            (string "()" *> return (as_word_list []));
            (char '(' *> sub <* char ')' >>| as_paren);
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

  let and_show_both_op =
    char '&' *> skip_spaces *> return (fun x y -> And_show_both (x, y))

  let and_hide_left_op =
    string "&>" *> skip_spaces *> return (fun x y -> And_hide_left (x, y))

  let exp : exp Angstrom.t =
    let base = sub >>| fun x -> Sub x in
    chainl1 base (and_hide_left_op <|> and_show_both_op)
    <* skip_spaces
end

let flatten_nested_lists (exp : exp) : exp =
  let rec aux_sub (sub : sub) =
    match sub with
    | `Word _
    | `Match_typ_marker _
    | `Explicit_spaces -> sub
    | `List l -> (
        `List
          (CCList.flat_map (fun e ->
               match aux_sub e with
               | `List l -> l
               | x -> [ x ]
             ) l)
      )
    | `Paren e -> `Paren (aux_sub e)
    | `Binary_op (op, x, y) -> `Binary_op (op, aux_sub x, aux_sub y)
    | `Optional e -> `Optional (aux_sub e)
  in
  let rec aux (exp : exp) =
    match exp with
    | Sub x -> Sub (aux_sub x)
    | And_show_both (x, y) -> And_show_both (aux x, aux y)
    | And_hide_left (x, y) -> And_hide_left (aux x, aux y)
  in
  aux exp

let flatten_sub (sub : sub) : Search_phrase.t list =
  let get_group_id =
    let counter = ref 0 in
    fun () ->
      let x = !counter in
      counter := x + 1;
      x
  in
  let rec aux group_id (sub : sub) : Search_phrase.annotated_token list Seq.t =
    match sub with
    | `Match_typ_marker x -> (
        Seq.return [
          Search_phrase.{ data = `Match_typ_marker x; group_id }
        ]
      )
    | `Word s ->
      Seq.return [
        Search_phrase.{ data = `String s; group_id }
      ]
    | `Explicit_spaces ->
      Seq.return [
        Search_phrase.{ data = `Explicit_spaces; group_id }
      ]
    | `List l -> (
        l
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
  aux (get_group_id ()) sub
  |> Seq.map (fun l ->
      List.to_seq l
      |> Search_phrase.of_annotated_tokens)
  |> List.of_seq
  |> List.sort_uniq Search_phrase.compare

let flatten (exp : exp) : flattened =
  let rec aux (exp : exp) =
    match exp with
    | Sub sub -> (
        let l = flatten_sub sub in
        { hidden = []; visible = [ l ] }
      )
    | And_show_both (x, y) -> (
        let flattened_x = aux x in
        let flattened_y = aux y in
        {
          hidden = List.flatten [
              flattened_x.hidden;
              flattened_y.hidden;
            ];
          visible = List.flatten [
              flattened_x.visible;
              flattened_y.visible;
            ]
        }
      )
    | And_hide_left (x, y) -> (
        let flattened_x = aux x in
        let flattened_y = aux y in
        {
          hidden = List.flatten [
              flattened_x.hidden;
              flattened_x.visible;
              flattened_y.hidden;
            ];
          visible = flattened_y.visible;
        }
      )
  in
  aux exp

let make s =
  if String.length s = 0 || String.for_all Parser_components.is_space s then (
    Some empty
  ) else (
    match Angstrom.(parse_string ~consume:Consume.All) Parsers.exp s with
    | Ok exp -> (
        let exp = flatten_nested_lists exp in
        Some
          { exp;
            flattened = flatten exp;
          }
      )
    | Error _ -> None
  )
