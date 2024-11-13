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

type t

val make : unit -> t

val equal : t -> t -> bool

val of_lines : Task_pool.t -> string Seq.t -> t

val of_pages : Task_pool.t -> string list Seq.t -> t

val word_ci_of_pos : int -> t -> string

val word_of_pos : int -> t -> string

val word_ci_and_pos_s : ?range_inc:(int * int) -> t -> (string * Int_set.t) Seq.t

val words_of_global_line_num : int -> t -> string Seq.t

val line_of_global_line_num : int -> t -> string

val line_loc_of_global_line_num : int -> t -> Line_loc.t

val loc_of_pos : int -> t -> Loc.t

val max_pos : t -> int

val words_of_page_num : int -> t -> string Seq.t

val line_count_of_page_num : int -> t -> int

val search :
  Task_pool.t ->
  Stop_signal.t ->
  within_same_line:bool ->
  Diet.Int.t option ->
  Search_exp.t ->
  t ->
  Search_result.t array

val global_line_count : t -> int

val page_count : t -> int

val to_cbor : t -> CBOR.Simple.t

val of_cbor : CBOR.Simple.t -> t option

val to_compressed_string : t -> string

val of_compressed_string : string -> t option
