type match_typ_marker = [ `Exact | `Prefix | `Suffix ]
[@@deriving show]

type exp = [
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

(*let process_match_typ_markers group_id (l : exp list) : exp list =
  let rec aux acc l =
    match l with
    | [] -> List.rev acc
    | x :: xs -> (
        match x with
        | `Match_typ_marker `Exact
        | `Match_typ_marker `Prefix as x -> (
            let original_marker, marker, marker_last =
              match (x : [ `Match_typ_marker of [ `Exact | `Prefix ] ]) with
              | `Match_typ_marker `Exact -> `Exact, `Exact, `Exact
              | `Match_typ_marker `Prefix -> `Prefix, `Exact, `Prefix
            in
            rewrite_tokens_forward
              true
              original_marker
              marker
              marker_last
              []
              acc
              xs
          )
        | `Match_typ_marker `Suffix -> (
          let original_marker, marker, marker_last =
            `Suffix, `Exact, `Suffix
          in
            rewrite_tokens_backward
            true
            original_marker
            marker
            marker_last
            []
            acc
            xs
          )
        | _ -> (
            aux (x :: acc) xs
          )
      )
  and rewrite_tokens_forward
      first
      (original_marker : match_typ_marker)
      (marker : match_typ_marker)
      (marker_last : match_typ_marker)
      (acc_buffer : exp list)
      (acc : exp list)
      l
    =
    let match_typ = (marker :> Search_phrase.match_typ) in
    let match_typ_last = (marker_last :> Search_phrase.match_typ) in
    let stop acc_buffer acc l =
      let acc_buffer =
        match acc_buffer with
        | [] -> []
        | x :: xs -> (
            match x with
            | `Annotated_token x -> (
                `Annotated_token Search_phrase.{ x with match_typ = match_typ_last } :: xs
              )
            | _ -> acc_buffer
          )
      in
      let acc =
        if first then (
          acc_buffer @ `Match_typ_marker original_marker :: acc
        ) else (
          acc_buffer @ acc
        )
      in
      aux acc l
    in
    match l with
    | [] -> stop acc_buffer acc l
    | x :: xs -> (
        match x with
        | `Word s -> (
            if Parser_components.is_space (String.get s 0) then (
              stop acc_buffer acc l
            ) else (
              rewrite_tokens_forward
                false
                original_marker
                marker
                marker_last
                (`Annotated_token
                   Search_phrase.{
                     string = s;
                     group_id;
                     match_typ;
                   } :: acc_buffer)
                acc
                xs
            )
          )
        | `Match_typ_marker x -> (
            rewrite_tokens_forward
              false
              original_marker
              marker
              marker_last
              (`Annotated_token
                 Search_phrase.{
                   string = string_of_match_typ_marker x;
                   group_id;
                   match_typ;
                 } :: acc_buffer)
              acc
              xs
          )
        | _ -> (
            stop acc_buffer acc l
          )
      )
  and rewrite_tokens_backward
      first
      (original_marker : match_typ_marker)
      (marker : match_typ_marker)
      (marker_last : match_typ_marker)
      (acc_buffer : exp list)
      (acc : exp list)
      l
      =
    let match_typ = (marker :> Search_phrase.match_typ) in
    let match_typ_last = (marker_last :> Search_phrase.match_typ) in
    let stop acc_buffer acc l =
      let acc_buffer =
        match acc_buffer with
        | [] -> []
        | x :: xs -> (
            match x with
            | `Annotated_token x -> (
                `Annotated_token Search_phrase.{ x with match_typ = match_typ_last } :: xs
              )
            | _ -> acc_buffer
          )
      in
      let acc =
        if first then (
          List.rev acc_buffer @ `Match_typ_marker original_marker :: acc
        ) else (
          List.rev acc_buffer @ acc
        )
      in
      aux acc l
    in
    match acc with
    | [] -> stop acc_buffer acc l
    | x :: xs -> (
      match x with
      | `Word s -> (
            if Parser_components.is_space (String.get s 0) then (
              stop acc_buffer acc l
            ) else (
              rewrite_tokens_backward
              false
              original_marker
              marker
              marker_last
                (`Annotated_token
                   Search_phrase.{
                     string = s;
                     group_id;
                     match_typ;
                   } :: acc_buffer)
                xs
                l
            )
      )
      | `Match_typ_marker x -> (
              rewrite_tokens_backward
              false
              original_marker
              marker
              marker_last
                (`Annotated_token
                   Search_phrase.{
                   string = string_of_match_typ_marker x;
                     group_id;
                     match_typ;
                   } :: acc_buffer)
                xs
                l
      )
      | _ -> (
        stop acc_buffer acc l
      )
    )
  in
  aux [] l *)

let flatten_nested_lists (exp : exp) : exp =
  let rec aux (exp : exp) =
    match exp with
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

let flatten (exp : exp) : Search_phrase.t list =
  let get_group_id =
    let counter = ref 0 in
    fun () ->
      let x = !counter in
      counter := x + 1;
      x
  in
  let rec aux group_id (exp : exp) : Search_phrase.annotated_token list Seq.t =
    match exp with
    | `Match_typ_marker x -> (
        Seq.return [
          Search_phrase.{ data = `Match_typ_marker x; group_id }
        ]
      )
    | `Word s ->
      Seq.return [
        Search_phrase.{ data = `String s; group_id }
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
  aux (get_group_id ()) exp
  |> Seq.map (fun l ->
      List.to_seq l
      |> Search_phrase.of_annotated_tokens)
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
            flattened = flatten exp;
          }
      )
    | Error _ -> None
  )
