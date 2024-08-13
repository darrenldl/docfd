type t = {
  case_sensitive : bool;
  string : string;
  re : Re.re;
}

let case_sensitive t = t.case_sensitive

let string t = t.string

let is_empty t = String.length t.string = 0

module Parsers = struct
  open Angstrom

  type part = [
    | `Case_insensitivity_marker
    | `String of string
  ]

  let parts : part list Angstrom.t =
    many (
      (take_while1 (fun c ->
           match c with
           | '\\' -> false
           | _ -> true
         )
       >>| fun s -> `String s)
      <|>
      (char '\\' *> any_char >>= fun c ->
       if c = 'c' then return `Case_insensitivity_marker
       else return (`String (Printf.sprintf "%c" c)))
    )
end

let make (s : string) : t option =
  match Angstrom.(parse_string ~consume:Consume.All) Parsers.parts s with
  | Error _ -> None
  | Ok parts -> (
      let case_insensitive = ref false in
      let s =
        parts
        |> List.filter_map (fun x ->
            match x with
            | `String s -> Some s
            | `Case_insensitivity_marker -> (
                case_insensitive := true;
                None
              )
          )
        |> String.concat ""
      in
      try
        let re =
          s
          |> Re.Glob.glob
            ~anchored:true
            ~pathname:true
            ~match_backslashes:false
            ~period:true
            ~expand_braces:false
            ~double_asterisk:true
          |> Re.compile
        in
        Some
          {
            case_sensitive = not !case_insensitive;
            string = s;
            re;
          }
      with
      | _ -> None
    )

let match_ t (s : string) =
  is_empty t
  || Re.execp t.re s
