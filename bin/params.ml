include Docfd_lib.Params'

let debug_output : out_channel option ref = ref None

let default_max_fuzzy_edit_distance = 2

let max_fuzzy_edit_distance = ref default_max_fuzzy_edit_distance

let preview_line_count = 5

let default_max_file_tree_depth = 10

let max_file_tree_depth = ref default_max_file_tree_depth

let default_recognized_exts = "txt,md,pdf"

let recognized_exts : string list ref = ref []

let index_file_ext = ".index"

let hash_chunk_size = 4096

let text_editor = ref ""

let line_wrap_underestimate_offset = 2

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
