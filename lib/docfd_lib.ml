module Index = Index

module Search_result = Search_result

module Search_phrase = Search_phrase

module Search_exp = Search_exp

module Word_db = Word_db

module Tokenize = Tokenize

module Params' = Params

module Task_pool = Task_pool

module Stop_signal = Stop_signal

module Parser_components = Parser_components

module Misc_utils' = Misc_utils

let init ~db =
  let db_res =
  Sqlite3.exec db {|
CREATE TABLE IF NOT EXISTS line_info (
  doc_hash varchar(500) PRIMARY KEY,
  global_line_num integer,
  start_pos integer,
  end_inc_pos integer,
  page_num integer,
  line_num_in_page integer
);

CREATE INDEX IF NOT EXISTS index_1 ON line_info (global_line_num);

CREATE TABLE IF NOT EXISTS position (
  doc_hash varchar(500),
  flat_position integer,
  word_id integer,
  word_ci_id integer,
  global_line_num integer,
  PRIMARY KEY (doc_hash, flat_position),
  FOREIGN KEY (doc_hash) REFERENCES doc_info (doc_hash),
  FOREIGN KEY (doc_hash) REFERENCES line_info (doc_hash),
  FOREIGN KEY (doc_hash) REFERENCES page_info (doc_hash),
  FOREIGN KEY (word_ci_id) REFERENCES word (id),
  FOREIGN KEY (word_id) REFERENCES word (id)
);

CREATE INDEX IF NOT EXISTS index_2 ON position (word_ci_id);
CREATE INDEX IF NOT EXISTS index_3 ON position (flat_position);

CREATE TABLE IF NOT EXISTS page_info (
  doc_hash varchar(500) PRIMARY KEY,
  page_num integer,
  line_count integer
);

CREATE INDEX IF NOT EXISTS index_1 ON page_info (page_num);

CREATE TABLE IF NOT EXISTS doc_info (
  doc_hash varchar(500) PRIMARY KEY,
  page_count integer,
  global_line_count integer
);

CREATE TABLE IF NOT EXISTS word (
  id integer PRIMARY KEY,
  doc_hash varchar(500),
  word varchar(500)
);

CREATE INDEX IF NOT EXISTS index_1 ON word (word);
CREATE INDEX IF NOT EXISTS index_2 ON word (doc_hash);
  |}
  in
  if not (Sqlite3.Rc.is_success db_res) then (
    Some (Fmt.str
    "failed to initialize index DB: %s" (Sqlite3.Rc.to_string db_res))
  ) else (
    Params.db := Some db;
    None
  )
