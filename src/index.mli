type line_loc = {
  page_num : int;
  line_num : int;
}

type loc = {
  page_num : int;
  line_num : int;
  pos_in_line : int;
}

type t

val empty : t

val of_seq : (line_loc * string) Seq.t -> t

val word_ci_of_pos : int -> t -> string

val word_of_pos : int -> t -> string

val word_ci_and_pos_s : ?range_inc:(int * int) -> t -> (string * Int_set.t) Seq.t

val words_of_line_num : int -> t -> string Seq.t

val line_of_line_num : int -> t -> string

val loc_of_pos : int -> t -> loc

val lines : t -> string Seq.t

val line_count : t -> int

val search : Search_phrase.t -> t -> Search_result.t array
