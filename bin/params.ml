include Docfd_lib.Params'

let debug_output : out_channel option ref = ref None

let default_max_fuzzy_edit_dist = 2

let max_fuzzy_edit_dist = ref default_max_fuzzy_edit_dist

let preview_line_count = 5

let pandoc_supported_exts =
  [ ".epub"
  ; ".odt"
  ; ".docx"
  ; ".fb2"
  ; ".ipynb"
  ; ".html"
  ; ".htm"
  ]

let default_recognized_exts =
  ([ "txt"; "md"; "pdf" ]
   @
   pandoc_supported_exts
  )
  |> List.map String_utils.remove_leading_dots
  |> String.concat ","

let default_recognized_single_line_exts =
  [ "log"; "csv"; "tsv" ]
  |> List.map String_utils.remove_leading_dots
  |> String.concat ","

let default_search_mode : Search_mode.t ref = ref `Multiline

let index_file_ext = ".index"

let hash_chunk_size = 4096

let text_editor = ref ""

let line_wrap_underestimate_offset = 2

let default_non_interactive_search_result_count_per_document = 5

let default_search_result_print_text_width = 80

let search_result_print_text_width = ref default_search_result_print_text_width

let default_cache_size = 100

let cache_size = ref default_cache_size

let cache_dir : string option ref = ref None

let tz : Timedesc.Time_zone.t =
  Option.value ~default:Timedesc.Time_zone.utc
    (Timedesc.Time_zone.local ())

let last_scan_format_string =
  "{year}-{mon:0X}-{day:0X} {hour:0X}:{min:0X}:{sec:0X}"
  ^
  (match Timedesc.Time_zone.local () with
   | None -> "Z"
   | Some _ -> "")

let blink_on_duration : Mtime.span = Mtime.Span.(140 * ms)
