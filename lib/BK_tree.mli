type 'a t

val empty : 'a t

val add : string -> 'a -> 'a t -> 'a t

val find : string -> 'a t -> 'a option

val to_seq : 'a t -> (string * 'a) Seq.t

val union : 'a t -> 'a t -> 'a t
