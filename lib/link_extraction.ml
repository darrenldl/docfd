let flush_buf link_typ ~acc ~buf =
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
          typ = link_typ;
          link = String.concat "" strings;
        }
      in
      (link :: acc, [])
    )

let links_of_line (line : (int * string) Dynarray.t) : Link.t list =
  let word_at pos = Dynarray.get line pos in
  let word_string_at pos = snd @@ word_at pos in
  let word_ci_string_at pos = String.lowercase_ascii @@ word_string_at pos in
  let rec aux
      (state : [ `Scanning | `In_link of Link.typ ])
      ~(acc : Link.t list)
      ~(buf : (int * string) list)
      (cur : int)
    : Link.t list
    =
    if cur >= Dynarray.length line then (
      match state with
      | `Scanning -> (
          acc
        )
      | `In_link link_typ -> (
          let acc, _buf = flush_buf link_typ ~acc ~buf in
          acc
        )
    ) else (
      let words_left = Dynarray.length line - cur - 1 in
      let pos, word = word_at cur in
      let word_ci = String.lowercase_ascii word in
      match state with
      | `Scanning -> (
          let link_typ =
            if List.mem word_ci [ "https"; "http"; "file" ]
            && words_left >= 3
            && word_ci_string_at (cur + 1) = ":"
            && word_ci_string_at (cur + 2) = "/"
            && word_ci_string_at (cur + 3) = "/"
            then (
              Some `URL
            ) else if cur >= 2
                   && word_ci_string_at (cur - 2) = "]"
                   && word_ci_string_at (cur - 1) = "("
            then (
              Some `Markdown
            ) else if cur >= 2
                   && word_ci_string_at (cur - 2) = "["
                   && word_ci_string_at (cur - 1) = "["
            then (
              Some `Wiki
            ) else (
              None
            )
          in
          match link_typ with
          | Some link_typ -> (
              aux (`In_link link_typ) ~acc ~buf:((pos, word) :: buf) (cur + 1)
            )
          | None -> (
              aux `Scanning ~acc ~buf (cur + 1)
            )
        )
      | `In_link link_typ -> (
          let link_ended =
            String.length word = 0
            || Parser_components.is_space word.[0]
            || List.mem word
              [ "]"
              ; ")"
              ; "|"
              ; "\""
              ; "<"
              ; ">"
              ; "{"
              ; "}"
              ; "^"
              ; "\\"
              ]
          in
          if link_ended then (
            let acc, buf = flush_buf link_typ ~acc ~buf in
            aux `Scanning ~acc ~buf (cur + 1)
          ) else (
            aux state ~acc ~buf:((pos, word) :: buf) (cur + 1)
          )
        )
    )
  in
  if Dynarray.length line = 0 then (
    []
  ) else (
    aux `Scanning ~acc:[] ~buf:[] 0
  )
