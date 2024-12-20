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

val lines : Task_pool.t -> doc_hash:string -> string Seq.t -> unit

val pages : Task_pool.t -> doc_hash:string -> string list Seq.t -> unit

val word_ci_of_pos : doc_hash:string -> int -> string

val word_of_pos : doc_hash:string -> int -> string

val word_ci_and_pos_s : ?range_inc:(int * int) -> doc_hash:string -> (string * Int_set.t) Seq.t

val words_of_global_line_num : doc_hash:string -> int -> string Seq.t

val line_of_global_line_num : doc_hash:string -> int -> string

val line_loc_of_global_line_num : doc_hash:string -> int -> Line_loc.t

val loc_of_pos : doc_hash:string -> int -> Loc.t

val max_pos : doc_hash:string -> int

val words_of_page_num : doc_hash:string -> int -> string Seq.t

val line_count_of_page_num : doc_hash:string -> int -> int

val search :
  Task_pool.t ->
  Stop_signal.t ->
  within_same_line:bool ->
  Diet.Int.t option ->
  Search_exp.t ->
  Search_result.t array

val global_line_count : doc_hash:string -> int

val page_count : doc_hash:string -> int
