type t

val make : ?case_sensitive:bool -> string -> t option

val equal : t -> t -> bool

val is_empty : t -> bool

val case_sensitive : t -> bool

val string : t -> string

val match_ : t -> string -> bool
