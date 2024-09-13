type t

type flattened = {
  hidden : Search_phrase.t list list;
  visible : Search_phrase.t list list;
}

val pp : Format.formatter -> t -> unit

val empty : t

val is_empty : t -> bool

val flattened : t -> flattened

val make : string -> t option

val equal : t -> t -> bool
