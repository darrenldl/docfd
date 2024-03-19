include Lib_misc_utils

let bound_selection ~choice_count (x : int) : int =
  max 0 (min (choice_count - 1) x)

let extension_of_file (s : string) =
  Filename.extension s
  |> String.lowercase_ascii

let format_of_file (s : string) : [ `PDF | `Pandoc_supported_format | `Text ] =
  let ext = extension_of_file s in
  if ext = ".pdf" then (
    `PDF
  ) else if List.mem ext Params.pandoc_supported_exts then (
    `Pandoc_supported_format
  ) else (
    `Text
  )

let frequencies_of_words_ci (s : string Seq.t) : int String_map.t =
  Seq.fold_left (fun m word ->
      let word = String.lowercase_ascii word in
      let count = Option.value ~default:0
          (String_map.find_opt word m)
      in
      String_map.add word (count + 1) m
    )
    String_map.empty
    s

let exit_with_error_msg (msg : string) =
  Printf.printf "error: %s\n" msg;
  exit 1

let stdin_is_atty () =
  Unix.isatty Unix.stdin

let stdout_is_atty () =
  Unix.isatty Unix.stdout

let stderr_is_atty () =
  Unix.isatty Unix.stderr
