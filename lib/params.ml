let default_search_result_total_per_document = 50

let search_result_min_per_start = 5

let max_token_size = 500

let default_max_token_search_dist = 50

let max_token_search_dist = ref default_max_token_search_dist

let default_max_linked_token_search_dist = 5

let max_linked_token_search_dist = ref default_max_linked_token_search_dist

let default_index_chunk_size = 5000

let index_chunk_size = ref default_index_chunk_size

let search_word_automaton_cache_size = 200

let float_compare_margin = 0.000_001

let opening_closing_symbols = [ ('(', ')')
                              ; ('[', ']')
                              ; ('{', '}')
                              ]

let opening_closing_symbols_flipped = List.map (fun (x, y) -> (y, x)) opening_closing_symbols

let default_max_fuzzy_edit_dist = 2

let max_fuzzy_edit_dist = ref default_max_fuzzy_edit_dist

let db_schema =
  {|
CREATE TABLE IF NOT EXISTS line_info (
  doc_id INTEGER,
  global_line_num INTEGER,
  start_pos INTEGER,
  end_inc_pos INTEGER,
  page_num INTEGER,
  line_num_in_page INTEGER,
  PRIMARY KEY (doc_id, global_line_num)
) WITHOUT ROWID;

CREATE INDEX IF NOT EXISTS line_info_index_1 ON line_info (start_pos);

CREATE INDEX IF NOT EXISTS line_info_index_2 ON line_info (end_inc_pos);

CREATE TABLE IF NOT EXISTS position (
  doc_id INTEGER,
  pos INTEGER,
  word_id INTEGER,
  PRIMARY KEY (doc_id, pos)
) WITHOUT ROWID;

CREATE INDEX IF NOT EXISTS position_index_1 ON position (doc_id, word_id, pos);

CREATE TABLE IF NOT EXISTS page_info (
  doc_id INTEGER,
  page_num INTEGER,
  line_count INTEGER,
  start_pos INTEGER,
  end_inc_pos INTEGER,
  PRIMARY KEY (doc_id, page_num)
) WITHOUT ROWID;

CREATE TABLE IF NOT EXISTS doc_info (
  hash TEXT PRIMARY KEY,
  id INTEGER,
  page_count INTEGER,
  global_line_count INTEGER,
  max_pos INTEGER,
  last_used INTEGER,
  status TEXT
) WITHOUT ROWID;

CREATE INDEX IF NOT EXISTS doc_info_index_1 ON doc_info (id);

CREATE INDEX IF NOT EXISTS doc_info_index_2 ON doc_info (last_used);

CREATE TABLE IF NOT EXISTS word (
  id INTEGER,
  word TEXT,
  PRIMARY KEY (doc_id, id)
) WITHOUT ROWID;

CREATE INDEX IF NOT EXISTS word_index_1 ON word (word);

CREATE INDEX IF NOT EXISTS word_index_2 ON word (word COLLATE NOCASE);
  |}

let db_path : string option ref = ref None
