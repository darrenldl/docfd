include Docfd_lib.Params'

let debug_output : out_channel option ref = ref None

let scan_hidden = ref false

let default_max_file_tree_scan_depth = 100

let max_file_tree_scan_depth = ref default_max_file_tree_scan_depth

let preview_line_count = 5

let default_tokens_per_search_scope_level = 100

let tokens_per_search_scope_level = ref default_tokens_per_search_scope_level

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

let path_open_specs : (string, [`Foreground | `Background] * string) Hashtbl.t = Hashtbl.create 128

let index_file_ext = ".index"

let db_file_name = "index.db"

let hash_chunk_size = 4096

let text_editor = ref ""

let default_samples_per_document = 5

let samples_per_document = ref default_samples_per_document

type style_mode = [ `Never | `Always | `Auto ]

let default_search_result_print_text_width = 80

let search_result_print_text_width = ref default_search_result_print_text_width

let default_search_result_print_snippet_min_size = 10

let search_result_print_snippet_min_size = ref default_search_result_print_snippet_min_size

let default_search_result_print_snippet_max_additional_lines_each_direction = 2

let search_result_print_snippet_max_additional_lines_each_direction =
  ref default_search_result_print_snippet_max_additional_lines_each_direction

let default_cache_limit = 10_000

let cache_limit = ref default_cache_limit

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

let os_typ : [ `Darwin | `Linux ] =
  match String.lowercase_ascii (CCUnix.call_stdout "uname") with
  | "darwin" -> `Darwin
  | _ -> `Linux

let clipboard_copy_cmd_and_args =
  match os_typ with
  | `Darwin -> Some ("pbcopy", [||])
  | `Linux -> (
      match Sys.getenv_opt "XDG_SESSION_TYPE" with
      | None -> None
      | Some s -> (
          match String.lowercase_ascii s with
          | "x11" -> Some ("xclip", [| "-sel"; "clip" |])
          | "wayland" -> Some ("wl-copy", [|"-n"|])
          | _ -> None
        )
    )
