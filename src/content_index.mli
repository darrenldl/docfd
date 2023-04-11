type t

val empty : t

val index : (int * string) Seq.t -> t

val word_ci_of_pos : int -> t -> string

val word_of_pos : int -> t -> string

val word_ci_and_pos_s : ?range_inc:(int * int) -> t -> (string * Int_set.t) Seq.t
