module Parsers = struct
  open Angstrom
  open Parser_components

  type token =
    | Space of string
    | Text of string

  let token_p =
    choice [
      take_while1 is_alphanum >>| (fun s -> Text s);
      take_while1 is_space >>| (fun s -> Space s);
      utf_8_char >>| (fun s -> Text s);
    ]

  let tokens_p =
    many token_p
end

let chunk_tokens (s : (int * string) Seq.t) : (int * string) Seq.t =
  let rec aux offset s =
    match s () with
    | Seq.Nil -> Seq.empty
    | Seq.Cons ((pos, word), rest) -> (
        let word_len = String.length word in
        if word_len <= Params.max_token_size then (
          fun () -> Seq.Cons ((pos + offset, word), aux offset rest)
        ) else (
          let up_to_limit =
            String.sub word 0 Params.max_token_size
          in
          let rest_of_token =
            String.sub word Params.max_token_size (word_len - Params.max_token_size)
          in
          fun () ->
            Seq.Cons
              ((pos + offset, up_to_limit),
               (aux (offset + 1) (Seq.cons (pos, rest_of_token) rest)))
        )
      )
  in
  aux 0 s

let tokenize_with_pos ~drop_spaces (s : string) : (int * string) Seq.t =
  let s = Misc_utils.sanitize_string s in
  match Angstrom.(parse_string ~consume:Consume.All) Parsers.tokens_p s with
  | Ok l -> (
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
      |> chunk_tokens
    )
  | Error _ -> Seq.empty

let tokenize ~drop_spaces s =
  tokenize_with_pos ~drop_spaces s
  |> Seq.map snd
