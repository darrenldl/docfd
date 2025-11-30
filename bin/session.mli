open Docfd_lib

type search_result_group = Document.t * Search_result.t array

module State : sig
  type t

  val equal : t -> t -> bool

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

  val search_result_groups : t -> search_result_group array

  val usable_document_paths : t -> String_set.t

  val unusable_documents : t -> Document.t Seq.t

  val unusable_document_paths : t -> string Seq.t

  val all_document_paths : t -> string Seq.t

  val marked_document_paths : t -> String_set.t

  val single_out : path:string -> t -> t option

  val mark : [ `Path of string | `Usable | `Unusable ] -> t -> t

  val unmark : [ `Path of string | `Usable | `Unusable | `All ] -> t -> t

  val drop : [ `Path of string | `All_except of string | `Marked | `Unmarked | `Usable | `Unusable ] -> t -> t

  val narrow_search_scope_to_level : level:int -> t -> t

  val screen_split : t -> Command.screen_split
end

val run_command : Task_pool.t -> Command.t -> State.t -> (Command.t * State.t) option

module Snapshot : sig
  type t

  val committed : t -> bool

  val last_command : t -> Command.t option

  val state : t -> State.t

  val id : t -> int

  val equal_id : t -> t -> bool

  val make : ?committed:bool -> last_command:Command.t option -> State.t -> t

  val make_empty : ?committed:bool -> unit -> t

  val update_state : State.t -> t -> t
end
