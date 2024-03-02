module Line_loc : sig
  type t

  val page_num : t -> int

  val line_num_in_page : t -> int

  val global_line_num : t -> int

  val compare : t -> t -> int
end

module Line_loc_map : Map.S with type key = Line_loc.t

module Loc : sig
  type t

  val line_loc : t -> Line_loc.t

  val pos_in_line : t -> int
end

type t

val make : unit -> t

val of_lines : string Seq.t -> t

val of_pages : string list Seq.t -> t

val word_ci_of_pos : int -> t -> string

val word_of_pos : int -> t -> string

val word_ci_and_pos_s : ?range_inc:(int * int) -> t -> (string * Int_set.t) Seq.t

val words_of_global_line_num : int -> t -> string Seq.t

val line_of_global_line_num : int -> t -> string

val line_loc_of_global_line_num : int -> t -> Line_loc.t

val loc_of_pos : int -> t -> Loc.t

val words_of_page_num : int -> t -> string Seq.t

val line_count_of_page_num : int -> t -> int

val search : Search_exp.t -> t -> Search_result.t array

val global_line_count : t -> int

val page_count : t -> int

val to_json : t -> Yojson.Safe.t

val of_json : Yojson.Safe.t -> t option
