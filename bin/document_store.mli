open Docfd_lib

type t

type key = string

type search_result_group = Document.t * Search_result.t array

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

val search_result_groups : t -> search_result_group array

val usable_documents_paths : t -> String_set.t

val unusable_documents_paths : t -> string Seq.t

val all_documents_paths : t -> string Seq.t

val marked_documents_paths : t -> String_set.t

val min_binding : t -> (key * search_result_group) option

val single_out : path:string -> t -> t option

val mark : path:string -> t -> t

val unmark : path:string -> t -> t

val toggle_mark : path:string -> t -> t

val unmark_all : t -> t

val drop : [ `Path of string | `Marked | `Unmarked | `Usable | `Unusable ] -> t -> t

val narrow_search_scope : level:int -> t -> t

val run_command : Task_pool.t -> Command.t -> t -> t option
