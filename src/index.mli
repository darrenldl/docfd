type loc = {
  page_num : int;
  line_num_in_page : int;
  pos_in_line : int;
}

module Line_loc : sig
type t = {
  page_num : int;
  line_num_in_page : int;
}

val of_loc : loc -> t

val min : t -> t -> t

val max : t -> t -> t
end
type t

val empty : t

val of_seq : (Line_loc.t * string) Seq.t -> t

val word_ci_of_pos : int -> t -> string

val word_of_pos : int -> t -> string

val word_ci_and_pos_s : ?range_inc:(int * int) -> t -> (string * Int_set.t) Seq.t

val words_of_line_loc : Line_loc.t -> t -> string Seq.t

val line_of_line_loc : Line_loc.t -> t -> string

val loc_of_pos : int -> t -> loc

val line_count_of_page : int -> t -> int

val line_loc_seq : start:Line_loc.t -> end_inc:Line_loc.t -> t -> Line_loc.t Seq.t

val search : Search_phrase.t -> t -> Search_result.t array
