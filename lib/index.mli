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

val index_lines : Task_pool.t -> doc_hash:string -> string Seq.t -> unit

val index_pages : Task_pool.t -> doc_hash:string -> string list Seq.t -> unit

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

val refresh_last_used : doc_hash:string -> unit
