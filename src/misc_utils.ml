let ci_string_set_of_list (l : string list) =
  l
  |> List.map String.lowercase_ascii
  |> String_set.of_list

let first_n_chars_of_string_contains ~n s c =
  let s_len = String.length s in
  let s =
    if s_len <= n then
      s
    else
      String.sub s 0 n
  in
  String.contains s c

let sanitize_string_for_printing s =
  String.map (fun c ->
      let code = Char.code c in
      if 32 <= code && code <= 126 then
        c
      else
        ' '
    )
    s
