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

let is_possibly_utf8 c =
  let c = Char.code c in
  c land 0b1000_0000 <> 0b0000_0000
