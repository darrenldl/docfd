include Lib_misc_utils

let bound_selection ~choice_count (x : int) : int =
  max 0 (min (choice_count - 1) x)

let extension_of_file (s : string) =
  Filename.extension s
  |> String.lowercase_ascii

type file_format = [ `PDF | `Pandoc_supported_format | `Text ] [@@deriving ord]

module File_format_set = CCSet.Make (struct
    type t = file_format

    let compare = compare_file_format
  end)

let format_of_file (s : string) : file_format =
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

let compile_glob_re s =
  try
    s
    |> Re.Glob.glob
      ~anchored:true
      ~pathname:true
      ~match_backslashes:false
      ~period:true
      ~expand_braces:false
      ~double_asterisk:true
    |> Re.compile
    |> Option.some
  with
  | _ -> None

let compute_total_recognized_exts ~exts ~additional_exts =
  let split_on_comma = String.split_on_char ',' in
  ((split_on_comma exts)
   @
   (split_on_comma additional_exts))
  |> List.map (fun s ->
      s
      |> String_utils.remove_leading_dots
      |> CCString.trim
    )
  |> List.filter (fun s -> s <> "")
  |> List.map (fun s -> Printf.sprintf ".%s" s)

let array_sub_seq : 'a. start:int -> end_exc:int -> 'a array -> 'a Seq.t =
  fun ~start ~end_exc arr ->
  let count = Array.length arr in
  let end_exc = min count end_exc in
  let rec aux start =
    if start < end_exc then (
      Seq.cons arr.(start) (aux (start + 1))
    ) else (
      Seq.empty
    )
  in
  aux start
