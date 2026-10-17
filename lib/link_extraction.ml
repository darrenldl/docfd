type bracket_match_outcome = [
  | `New_opening
  | `Matched_closing
  | `Not_bracket
  | `Unmatched_closing
]

type decision = [
  | `Record_word
  | `Skip_word
  | `End_link
  | `Drop_link
]

module Ctx = struct
  type t = {
    link_typ : Link.typ;
    starting_bracket : string option;
    brackets : string list;
    last_word_was_escape : bool;
  }

  let bracket_lookup =
    [ ("<", ">")
    ; ("[", "]")
    ; ("(", ")")
    ; ("{", "}")
    ; ("`", "`")
    ]

  let bracket_reverse_lookup =
    bracket_lookup
    |> List.map (fun (x, y) -> (y, x))

  let record_maybe_escape x (ctx : t) : (bool * t) =
    if x = "\\" then (
      (true, { ctx with last_word_was_escape = true })
    ) else (
      (false, { ctx with last_word_was_escape = false })
    )

  let record_maybe_bracket x (ctx : t) : (bracket_match_outcome * t) =
    match List.assoc_opt x bracket_lookup with
    | None -> (
        match List.assoc_opt x bracket_reverse_lookup with
        | None -> (`Not_bracket, ctx)
        | Some opening -> (
            match ctx.brackets with
            | b :: bs when b = opening -> (
                (`Matched_closing, { ctx with brackets = bs })
              )
            | _ -> (
                (`Unmatched_closing, ctx)
              )
          )
      )
    | Some _ -> (
        (`New_opening, { ctx with brackets = x :: ctx.brackets })
      )

  let make ?starting_bracket link_typ =
    { link_typ;
      starting_bracket;
      brackets = [];
      last_word_was_escape = false;
    }

  let closes_starting_bracket x ctx =
    match ctx.starting_bracket, ctx.brackets with
    | Some starting_bracket, [] -> (
        match List.assoc_opt x bracket_reverse_lookup with
        | None -> false
        | Some opening -> opening = starting_bracket
      )
    | _, _ -> false
end

let flush_buf ctx ~acc ~buf =
  match buf with
  | [] -> (acc, buf)
  | _ -> (
      let start_pos, end_inc_pos, strings =
        List.fold_left (fun (start, end_inc, strings) (pos, word) ->
            let start =
              match start with
              | None -> Some pos
              | Some start -> Some (min pos start)
            in
            let end_inc =
              match end_inc with
              | None -> Some pos
              | Some end_inc -> Some (max pos end_inc)
            in
            (start, end_inc, word :: strings)
          )
          (None, None, [])
          buf
      in
      let start_pos = Option.get start_pos in
      let end_inc_pos = Option.get end_inc_pos in
      let link = Link.{
          start_pos;
          end_inc_pos;
          typ = ctx.Ctx.link_typ;
          link = String.concat "" strings |> String.trim;
        }
      in
      (link :: acc, [])
    )

type scanning_state = [
  | `Scanning
  | `Skip_spaces of Ctx.t
  | `In_link of Ctx.t
]

let hierarchical_url_prefixes = [
  "https";
  "http";
  "file";
  "ftp";
  "obsidian";
]

let non_hierarchical_url_prefixes = [
  "mailto";
]

module Parsing = struct
  let match_word line ~pos l =
    if 0 <= pos && pos < Dynarray.length line then (
      let x =
        Dynarray.get line pos
        |> snd
        |> String.lowercase_ascii
      in
      List.mem x l
    ) else (
      false
    )

  let match_words line ~start_pos l =
    let rec aux i l =
      match l with
      | [] -> true
      | choices :: rest -> (
          if match_word line ~pos:(start_pos + i) choices then (
            aux (i + 1) rest
          ) else (
            false
          )
        )
    in
    aux 0 l

  let match_url line ~start_pos =
    match_words line ~start_pos
      [ hierarchical_url_prefixes
      ; [ ":" ]
      ; [ "/" ]
      ; [ "/" ]
      ]
    ||
    match_words line ~start_pos
      [ non_hierarchical_url_prefixes
      ; [ ":" ]
      ]
end

let links_of_line (line : (int * string) Dynarray.t) : Link.t list =
  let rec aux
      (state : scanning_state)
      ~(acc : Link.t list)
      ~(buf : (int * string) list)
      (cur : int)
    : Link.t list
    =
    if cur >= Dynarray.length line then (
      let acc =
        match state with
        | `Scanning | `Skip_spaces _ -> (
            acc
          )
        | `In_link ctx -> (
            let acc, _buf = flush_buf ctx ~acc ~buf in
            acc
          )
      in
      List.rev acc
    ) else (
      let pos, word = Dynarray.get line cur in
      let word_is_blank_or_space =
        String.length word = 0
        || Parser_components.is_space word.[0]
      in
      match state with
      | `Scanning -> (
          let next_state, next_pos =
            if Parsing.match_words line ~start_pos:(cur - 2)
                [ [ "]" ]
                ; [ "(" ]
                ; [ "<" ]
                ]
            then (
              let link_typ =
                if Parsing.match_url line ~start_pos:(cur + 1) then (
                  `URL
                ) else (
                  `Markdown
                )
              in
              (`Skip_spaces (Ctx.make ~starting_bracket:"<" link_typ), cur + 1)
            ) else if Parsing.match_words line ~start_pos:(cur - 1)
                [ [ "]" ]
                ; [ "(" ]
                ]
                   && not (Parsing.match_word line ~pos:(cur + 1) [ "<" ])
            then (
              let link_typ =
                if Parsing.match_url line ~start_pos:(cur + 1) then (
                  `URL
                ) else (
                  `Markdown
                )
              in
              (`Skip_spaces (Ctx.make ~starting_bracket:"(" link_typ), cur + 1)
            ) else if Parsing.match_words line ~start_pos:(cur - 1)
                [ [ "[" ]
                ; [ "[" ]
                ]
            then (
              (`Skip_spaces (Ctx.make `Wiki), cur + 1)
            ) else if Parsing.match_url line ~start_pos:(cur + 1) then (
              if Parsing.match_word line ~pos:cur [ "<"; "`" ] then (
                (`In_link (Ctx.make ~starting_bracket:word `URL), cur + 1)
              ) else (
                (`Scanning, cur + 1)
              )
            ) else if Parsing.match_url line ~start_pos:cur then (
              (`In_link (Ctx.make `URL), cur)
            ) else (
              (`Scanning, cur + 1)
            )
          in
          aux next_state ~acc ~buf next_pos
        )
      | `Skip_spaces ctx -> (
          if word_is_blank_or_space then (
            aux (`Skip_spaces ctx) ~acc ~buf (cur + 1)
          ) else (
            aux (`In_link ctx) ~acc ~buf cur
          )
        )
      | `In_link ctx -> (
          let decision, ctx =
            match ctx.Ctx.link_typ with
            | `Markdown | `Wiki -> (
                if ctx.Ctx.last_word_was_escape then (
                  (`Record_word, { ctx with last_word_was_escape = false })
                ) else (
                  if Ctx.closes_starting_bracket word ctx then (
                    (`End_link, ctx)
                  ) else (
                    let outcome, ctx = Ctx.record_maybe_bracket word ctx in
                    match outcome with
                    | `Unmatched_closing -> (`End_link, ctx)
                    | `New_opening | `Matched_closing -> (`Record_word, ctx)
                    | `Not_bracket -> (
                        let is_escape, ctx = Ctx.record_maybe_escape word ctx in
                        if is_escape then (
                          (`Skip_word, ctx)
                        ) else (
                          match ctx.Ctx.link_typ, ctx.Ctx.starting_bracket with
                          | `Markdown, Some "<" -> (`Record_word, ctx)
                          | `Markdown, _ -> (
                              if List.mem word [ "\""; "'" ] then (
                                (`End_link, ctx)
                              ) else (
                                (`Record_word, ctx)
                              )
                            )
                          | `Wiki, _ -> (
                              if List.mem word [ "|" ] then (
                                (`End_link, ctx)
                              ) else (
                                (`Record_word, ctx)
                              )
                            )
                          | _, _ -> (
                              (`Record_word, ctx)
                            )
                        )
                      )
                  )
                )
              )
            | `URL -> (
                if Ctx.closes_starting_bracket word ctx then (
                  (`End_link, ctx)
                ) else (
                  let outcome, ctx = Ctx.record_maybe_bracket word ctx in
                  match outcome with
                  | `Unmatched_closing -> (`End_link, ctx)
                  | `New_opening | `Matched_closing -> (`Record_word, ctx)
                  | `Not_bracket -> (
                      if word_is_blank_or_space then (
                        (`End_link, ctx)
                      ) else (
                        (`Record_word, ctx)
                      )
                    )
                )
              )
          in
          match decision with
          | `Drop_link -> (
              aux `Scanning ~acc ~buf:[] (cur + 1)
            )
          | `End_link -> (
              let acc, buf = flush_buf ctx ~acc ~buf in
              aux `Scanning ~acc ~buf (cur + 1)
            )
          | `Skip_word -> (
              aux (`In_link ctx) ~acc ~buf (cur + 1)
            )
          | `Record_word -> (
              aux (`In_link ctx) ~acc ~buf:((pos, word) :: buf) (cur + 1)
            )
        )
    )
  in
  if Dynarray.length line = 0 then (
    []
  ) else (
    aux `Scanning ~acc:[] ~buf:[] 0
  )
