include Docfd_lib.Params'

let debug = ref false

let default_max_fuzzy_edit_distance = 2

let max_fuzzy_edit_distance = ref default_max_fuzzy_edit_distance

let preview_line_count = 5

let default_max_file_tree_depth = 10

let max_file_tree_depth = ref default_max_file_tree_depth

let default_recognized_exts = "txt,md,pdf"

let recognized_exts : string list ref = ref []

let index_dir_name = ".docfd"

let index_dir = ref ""

let index_file_ext = ".index"

let hash_chunk_size = 4096

let text_editor = ref ""

let line_wrap_underestimate_offset = 2

let max_index_file_count = 100
