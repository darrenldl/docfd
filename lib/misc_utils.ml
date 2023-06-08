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

let sanitize_string s =
  String.map (fun c ->
      let code = Char.code c in
      if 32 <= code && code <= 126 then
        c
      else
        ' '
    )
    s

let bound_selection ~choice_count (x : int) : int =
  max 0 (min (choice_count - 1) x)

let list_and_length_of_seq (s : 'a Seq.t) : int * 'a list =
  let len, acc =
    Seq.fold_left (fun (len, acc) x ->
        (len + 1, x :: acc)
      )
      (0, [])
      s
  in
  (len, List.rev acc)

let path_is_pdf (s : string) =
  Filename.extension s = ".pdf"
