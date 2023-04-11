type t

val empty : t

val index : (int * string) Seq.t -> t

val word_ci_of_pos : int -> t -> string

val word_of_pos : int -> t -> string

val word_ci_and_pos_s : ?range_inc:(int * int) -> t -> (string * Int_set.t) Seq.t

val words_of_line_num : int -> t -> string Seq.t

val line_of_line_num : int -> t -> string

val loc_of_pos : int -> t -> int * int

val lines : t -> string Seq.t

val line_count : t -> int
