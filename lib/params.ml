let default_search_result_total_per_document = 50

let search_result_min_per_start = 5

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
  doc_id integer,
  global_line_num integer,
  start_pos integer,
  end_inc_pos integer,
  page_num integer,
  line_num_in_page integer
  -- FOREIGN KEY (doc_id) REFERENCES doc_info (id)
);

CREATE INDEX IF NOT EXISTS line_info_index_1 ON line_info (doc_id);

CREATE TABLE IF NOT EXISTS position (
  doc_id integer,
  pos integer,
  word_id integer,
  global_line_num integer,
  pos_in_line integer
  -- FOREIGN KEY (doc_id) REFERENCES doc_info (id),
  -- FOREIGN KEY (word_id) REFERENCES word (id)
);

CREATE INDEX IF NOT EXISTS position_index_1 ON position (doc_id);
CREATE INDEX IF NOT EXISTS position_index_2 ON position (pos);

CREATE TABLE IF NOT EXISTS page_info (
  doc_id integer,
  page_num integer,
  line_count integer,
  start_pos integer,
  end_inc_pos integer
  -- FOREIGN KEY (doc_id) REFERENCES doc_info (id)
);

CREATE INDEX IF NOT EXISTS page_info_index_1 ON page_info (doc_id);

CREATE TABLE IF NOT EXISTS doc_info (
  id integer PRIMARY KEY AUTOINCREMENT,
  doc_hash varchar(500),
  page_count integer,
  global_line_count integer,
  max_pos integer
);

CREATE INDEX IF NOT EXISTS doc_info_index_1 ON doc_info (doc_hash);

CREATE TABLE IF NOT EXISTS word (
  id integer PRIMARY KEY AUTOINCREMENT,
  doc_id integer,
  word varchar(500)
  -- FOREIGN KEY (doc_id) REFERENCES doc_info (id)
);

CREATE INDEX IF NOT EXISTS word_index_1 ON word (word);
CREATE INDEX IF NOT EXISTS word_index_2 ON word (doc_id);
  |}

let db_path : string option ref = ref None
