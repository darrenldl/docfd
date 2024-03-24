let search_result_max_total_per_document = 50

let search_result_min_per_start = 5

let default_max_word_search_dist = 50

let max_word_search_dist = ref default_max_word_search_dist

let default_max_linked_token_search_dist = 5

let max_linked_token_search_dist = ref default_max_linked_token_search_dist

let default_index_chunk_word_count = 5000

let index_chunk_word_count = ref default_index_chunk_word_count

let search_word_automaton_cache_size = 200

let float_compare_margin = 0.000_001

let opening_closing_symbols = [ ('(', ')')
                              ; ('[', ']')
                              ; ('{', '}')
                              ]

let opening_closing_symbols_flipped = List.map (fun (x, y) -> (y, x)) opening_closing_symbols

let code_symbols = {|~`!@#$%^&*()_-=+<>?,./;':"[]{}|}
