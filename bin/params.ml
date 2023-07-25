include Docfd_lib.Params'

let debug = ref false

let default_max_fuzzy_edit_distance = 3

let max_fuzzy_edit_distance = ref default_max_fuzzy_edit_distance

let preview_line_count = 5

let default_max_file_tree_depth = 10

let max_file_tree_depth = ref default_max_file_tree_depth

let default_recognized_exts = "txt,md,pdf"

let recognized_exts : string list ref = ref []

let stdin_doc_path_placeholder = "<stdin>"

let index_dir_name = ".docfd"

let index_dir = ref ""

let hash_chunk_size = 4096
