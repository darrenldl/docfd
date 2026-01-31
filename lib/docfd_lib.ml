module Index = Index

module Doc_id_db = Doc_id_db

module Link = Link

module Search_result = Search_result

module Search_phrase = Search_phrase

module Search_exp = Search_exp

module Search_result_heap = Search_result_heap

module Word_db = Word_db

module Tokenization = Tokenization

module Params' = Params

module Task_pool = Task_pool

module Stop_signal = Stop_signal

module Parser_components = Parser_components

module Misc_utils' = Misc_utils

module Sqlite3_utils = Sqlite3_utils

let init ~db_path ~document_count_limit =
  let open Sqlite3_utils in
  let db = db_open db_path in
  let db_res =
    Sqlite3.exec db Params.db_schema
  in
  let res =
    if not (Rc.is_success db_res) then (
      Some (Fmt.str
              "failed to initialize index DB: %s" (Rc.to_string db_res))
    ) else (
      Params.db_path := Some db_path;
      if Index.document_count () >= document_count_limit then (
        Index.prune_old_documents ~keep_n_latest:document_count_limit
      );
      None
    )
  in
  while not (db_close db) do Unix.sleepf 0.1 done;
  res
