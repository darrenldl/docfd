module Line_loc : sig
  type t

  val page_num : t -> int

  val line_num_in_page : t -> int

  val global_line_num : t -> int

  val compare : t -> t -> int
end

module Loc : sig
  type t

  val line_loc : t -> Line_loc.t

  val pos_in_line : t -> int
end

val word_ci_of_pos : doc_id:int64 -> int -> string

val word_of_pos : doc_id:int64 -> int -> string

val words_of_global_line_num : doc_id:int64 -> int -> string Dynarray.t

val line_of_global_line_num : doc_id:int64 -> int -> string

val line_loc_of_global_line_num : doc_id:int64 -> int -> Line_loc.t

val loc_of_pos : doc_id:int64 -> int -> Loc.t

val max_pos : doc_id:int64 -> int

val words_of_page_num : doc_id:int64 -> int -> string Dynarray.t

val line_count_of_page_num : doc_id:int64 -> int -> int

val search :
  Task_pool.t ->
  Stop_signal.t ->
  ?terminate_on_result_found : bool ->
  doc_id:int64 ->
  within_same_line:bool ->
  search_scope:Diet.Int.t option ->
  Search_exp.t ->
  Search_result.t array option

module Search_job : sig
  exception Result_found

  type t

  val run : t -> Search_result_heap.t
end

module Search_job_group : sig
  type t

  val unpack : t -> Search_job.t Seq.t

  val run : t -> Search_result_heap.t
end

val make_search_job_groups :
  Task_pool.t ->
  Stop_signal.t ->
  ?terminate_on_result_found : bool ->
  cancellation_notifier:bool Atomic.t ->
  doc_ids:Int_set.t ->
  within_same_line_lookup:bool Int_map.t ->
  search_scope_lookup:Diet.Int.t option Int_map.t ->
  Search_exp.t ->
  Search_job_group.t Seq.t

val global_line_count : doc_id:int64 -> int

val page_count : doc_id:int64 -> int

val is_indexed_sql : string

val is_indexed : doc_hash:string -> bool

val refresh_last_used_batch : int64 list -> unit

val document_count : unit -> int

val prune_old_documents : keep_n_latest:int -> unit

module Raw : sig
  type t

  val word_ids : t -> Int_set.t

  val of_lines : Task_pool.t -> string Seq.t -> t

  val of_pages : Task_pool.t -> string list Seq.t -> t
end

val word_ids : doc_id:int64 -> Int_set.t

(* val union_doc_ids_of_word_id_into : word_id:int -> into:CCBV.t -> unit*)

val write_raw_to_db :
  Sqlite3.db ->
  already_in_transaction:bool ->
  doc_id:int64 ->
  Raw.t ->
  unit

module State : sig
  val read_from_db : unit -> unit
end
