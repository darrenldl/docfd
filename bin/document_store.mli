open Docfd_lib

type t

type key = string

type search_result_group = Document.t * Search_result.t array

val size : t -> int

val empty : t

val update_filter_exp :
  Task_pool.t ->
  Stop_signal.t ->
  string ->
  Filter_exp.t ->
  t ->
  t option

val update_search_exp :
  Task_pool.t ->
  Stop_signal.t ->
  string ->
  Search_exp.t ->
  t ->
  t option

val filter_exp : t -> Filter_exp.t

val filter_exp_string : t -> string

val search_exp : t -> Search_exp.t

val search_exp_string : t -> string

val add_document : Task_pool.t -> Document.t -> t -> t

val of_seq : Task_pool.t -> Document.t Seq.t -> t

module Sort_by : sig
  type typ = [
    | `Path_date
    | `Path
    | `Score
  ]

  type order = [
    | `Asc
    | `Desc
  ]

  type t = typ * order

  val default : t
end

val search_result_groups : ?sort_by:Sort_by.t -> t -> search_result_group array

val usable_document_paths : t -> String_set.t

val unusable_document_paths : t -> string Seq.t

val all_document_paths : t -> string Seq.t

val marked_document_paths : t -> String_set.t

val min_binding : t -> (key * search_result_group) option

val single_out : path:string -> t -> t option

val mark : [ `Path of string | `Usable | `Unusable ] -> t -> t

val unmark : [ `Path of string | `Usable | `Unusable | `All ] -> t -> t

val drop : [ `Path of string | `All_except of string | `Marked | `Unmarked | `Usable | `Unusable ] -> t -> t

val narrow_search_scope_to_level : level:int -> t -> t

val run_command : Task_pool.t -> Command.t -> t -> t option
