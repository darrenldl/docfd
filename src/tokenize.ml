module Parsers = struct
  open Angstrom
  open Parser_components
  let token_p =
    choice [
      take_while1 is_alphanum;
      take_while1 is_space;
      any_char >>| (fun c -> Printf.sprintf "%c" c);
    ]

  let tokens_p =
    many token_p
end

let f (s : string) : string list =
  match Angstrom.(parse_string ~consume:Consume.All) Parsers.tokens_p s with
  | Ok l -> l
  | Error _ -> []
