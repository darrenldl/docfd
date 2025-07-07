let remove_leading_dots (s : string) =
  let str_len = String.length s in
  if str_len = 0 then (
    ""
  ) else (
    let rec aux pos =
      if pos < str_len then (
        if String.get s pos = '.' then
          aux (pos + 1)
        else (
          String.sub s pos (str_len - pos)
        )
      ) else (
        ""
      )
    in
    aux 0
  )

let line_is_comment line =
  CCString.starts_with ~prefix:"#" line

let line_is_blank_or_comment line =
  line_is_comment line
  ||
  String.length (String.trim line) = 0

let longest_common_prefix (l : string list) : string =
  let prefix = ref "" in
  List.iteri (fun i s ->
      if i = 0 then (
        prefix := s
      ) else (
        let match_len = ref 0 in
        let prefix_len = String.length !prefix in
        String.iteri (fun i c ->
            if !match_len = i
            && i < prefix_len
            && !prefix.[i] = c then (
              incr match_len
            )
          ) s;
        prefix :=
          String.sub !prefix 0 (min !match_len prefix_len)
      )
    ) l;
  !prefix
