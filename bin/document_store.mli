open Docfd_lib

type t

type key = string

type value = Document.t * Search_result.t array

val size : t -> int

val empty : t

val update_content_reqs : stop_signal:Stop_signal.t -> Content_req_exp.t -> t -> t

val update_search_phrase : stop_signal:Stop_signal.t -> Search_phrase.t -> t -> t

val content_reqs : t -> Content_req_exp.t

val search_phrase : t -> Search_phrase.t

val add_document : stop_signal:Stop_signal.t -> Document.t -> t -> t

val of_seq : Document.t Seq.t -> t

val usable_documents : t -> value array

val min_binding : t -> (key * value) option

val single_out : path:string -> t -> t option
