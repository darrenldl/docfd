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

val word_ci_of_pos : doc_hash:string -> int -> string

val word_of_pos : doc_hash:string -> int -> string

val words_of_global_line_num : doc_hash:string -> int -> string Dynarray.t

val line_of_global_line_num : doc_hash:string -> int -> string

val line_loc_of_global_line_num : doc_hash:string -> int -> Line_loc.t

val loc_of_pos : doc_hash:string -> int -> Loc.t

val max_pos : doc_hash:string -> int

val words_of_page_num : doc_hash:string -> int -> string Dynarray.t

val line_count_of_page_num : doc_hash:string -> int -> int

val search :
  Task_pool.t ->
  Stop_signal.t ->
  doc_hash:string ->
  within_same_line:bool ->
  Diet.Int.t option ->
  Search_exp.t ->
  Search_result.t array option

val global_line_count : doc_hash:string -> int

val page_count : doc_hash:string -> int

val is_indexed : doc_hash:string -> bool

val refresh_last_used_batch : string Seq.t -> unit

module Raw : sig
  type t

  val of_lines : Task_pool.t -> string Seq.t -> t

  val of_pages : Task_pool.t -> string list Seq.t -> t
end

val load_raw_into_db : Sqlite3.db -> doc_hash:string -> Raw.t -> unit
