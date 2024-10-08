open Docfd_lib

type t

type key = string

type document_info = Document.t * Search_result.t array

val size : t -> int

val empty : t

val update_file_path_filter_glob :
  Task_pool.t ->
  Stop_signal.t ->
  string ->
  Glob.t ->
  t ->
  t

val update_search_exp :
  Task_pool.t ->
  Stop_signal.t ->
  string ->
  Search_exp.t ->
  t ->
  t

val file_path_filter_glob : t -> Glob.t

val file_path_filter_glob_string : t -> string

val search_exp : t -> Search_exp.t

val search_exp_string : t -> string

val add_document : Task_pool.t -> Document.t -> t -> t

val of_seq : Task_pool.t -> Document.t Seq.t -> t

val usable_documents : t -> document_info array

val usable_documents_paths : t -> String_set.t

val unusable_documents_paths : t -> string Seq.t

val all_documents_paths : t -> string Seq.t

val min_binding : t -> (key * document_info) option

val single_out : path:string -> t -> t option

val drop : [ `Path of string | `Usable | `Unusable ] -> t -> t

val play_action : Task_pool.t -> Action.t -> t -> t option
