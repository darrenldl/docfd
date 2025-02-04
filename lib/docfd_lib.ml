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

module Sqlite3_utils = Sqlite3_utils

let init ~db_path =
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
      None
    )
  in
  while not (db_close db) do Unix.sleepf 0.1 done;
  res
