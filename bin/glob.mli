type t

val make : string -> t option

val is_empty : t -> bool

val case_sensitive : t -> bool

val string : t -> string

val original_string : t -> string

val match_ : t -> string -> bool
