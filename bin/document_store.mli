open Docfd_lib

type t

type key = string

type document_info = Document.t * Search_result.t array

val size : t -> int

val empty : t

val update_search_exp : Task_pool.t -> Stop_signal.t -> Search_exp.t -> t -> t

val search_exp : t -> Search_exp.t

val add_document : Task_pool.t -> Document.t -> t -> t

val of_seq : Task_pool.t -> Document.t Seq.t -> t

val usable_documents : t -> document_info array

val min_binding : t -> (key * document_info) option

val single_out : path:string -> t -> t option
