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

module Sqlite3_manager = Sqlite3_manager

let init ~env ~db_path ~document_count_limit =
  let open Sqlite3_manager in
  Params.db_path := Some db_path;
  Eio.Domain_manager.run (Eio.Stdenv.domain_mgr env)
    Sqlite3_manager.fiber;
  let db_res =
    with_db (fun db ->
        Sqlite3.exec db Params.db_schema
      )
  in
  let res =
    if not (Rc.is_success db_res) then (
      Some (Fmt.str
              "failed to initialize index DB: %s" (Rc.to_string db_res))
    ) else (
      if Index.document_count () >= document_count_limit then (
        Index.prune_old_documents ~keep_n_latest:document_count_limit
      );
      None
    )
  in
  res
