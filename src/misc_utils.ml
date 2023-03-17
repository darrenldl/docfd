let ci_string_set_of_list (l : string list) =
  l
  |> List.map String.lowercase_ascii
  |> String_set.of_list

let path_is_note path =
  let words =
    Filename.basename path
    |> String.lowercase_ascii
    |> String.split_on_char '.'
  in
  List.exists (fun s ->
      s = "note" || s = "notes") words

