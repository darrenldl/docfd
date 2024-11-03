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

let line_is_blank_or_comment line =
  CCString.starts_with ~prefix:"#" line
  ||
  String.length (String.trim line) = 0
