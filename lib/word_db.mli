type t

val make : unit -> t

val equal : t -> t -> bool

val add : t -> string -> int

val size : t -> int

val word_of_index : t -> int -> string

val index_of_word : t -> string -> int

val encode : t -> Pbrt.Encoder.t -> unit

val decode : Pbrt.Decoder.t -> t
