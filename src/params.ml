let debug = ref false

let default_max_fuzzy_edit_distance = 3

let max_fuzzy_edit_distance = ref default_max_fuzzy_edit_distance

let preview_line_count = 5

let default_max_file_tree_depth = 5

let max_file_tree_depth = ref default_max_file_tree_depth

let recognized_exts = [ ".txt"; ".md"; ".pdf" ]

let default_max_word_search_range = 40

let max_word_search_range = ref default_max_word_search_range

let search_result_limit = 10_000

let stdin_doc_path_placeholder = "<stdin>"

let default_index_chunk_word_count = 5000

let index_chunk_word_count = ref default_index_chunk_word_count
