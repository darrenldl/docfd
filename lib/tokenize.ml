module Parsers = struct
  open Angstrom
  open Parser_components

  type token =
    | Space of string
    | Text of string

  let token_p =
    choice [
      take_while1 is_possibly_utf8 >>| (fun s -> Text s);
      take_while1 is_alphanum >>| (fun s -> Text s);
      take_while1 is_space >>| (fun s -> Space s);
      any_char >>| (fun c -> Text (Printf.sprintf "%c" c));
    ]

  let tokens_p =
    many token_p
end

let f_with_pos ~drop_spaces (s : string) : (int * string) Seq.t =
  let s = Misc_utils.sanitize_string s in
  match Angstrom.(parse_string ~consume:Consume.All) Parsers.tokens_p s with
  | Ok l ->
    l
    |> List.to_seq
    |> Seq.mapi (fun i x -> (i, x))
    |> Seq.filter_map (fun ((i, token) : int * Parsers.token) ->
        match token with
        | Text s -> Some (i, s)
        | Space s ->
          if drop_spaces then
            None
          else
            Some (i, s)
      )
  | Error _ -> Seq.empty

let f ~drop_spaces s =
  f_with_pos ~drop_spaces s
  |> Seq.map snd
