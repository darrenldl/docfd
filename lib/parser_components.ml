open Angstrom

let is_space c =
  match c with
  | ' '
  | '\t'
  | '\n'
  | '\r' -> true
  | _ -> false

let spaces = skip_while is_space

let spaces1 = take_while1 is_space *> return ()

let any_string : string t = take_while1 (fun _ -> true)

let is_letter c =
  match c with
  | 'A'..'Z'
  | 'a'..'z' -> true
  | _ -> false

let is_digit c =
  match c with
  | '0'..'9' -> true
  | _ -> false

let is_alphanum c =
  is_letter c || is_digit c

let is_possibly_utf_8 c =
  let c = Char.code c in
  c land 0b1000_0000 <> 0b0000_0000

let utf_8_char =
  peek_char >>= fun c ->
  match c with
  | None -> fail "Eof"
  | Some c -> (
      let c = Char.code c in
      if c land 0b1000_0000 = 0b0000_0000 then (
        take 1
      ) else if c land 0b1110_0000 = 0b1100_0000 then (
        take 2
      ) else if c land 0b1111_0000 = 0b1110_0000 then (
        take 3
      ) else if c land 0b1111_1000 = 0b1111_0000 then (
        take 4
      ) else (
        fail "Invalid UTF-8"
      )
    )

(* Copied from Angstrom README *)
let chainl1 e op =
  let rec go acc =
    (lift2 (fun f x -> f acc x) op e >>= go) <|> return acc in
  e >>= fun init -> go init
