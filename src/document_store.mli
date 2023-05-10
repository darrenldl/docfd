type t

val empty : t

val update_search_constraints : Search_constraints.t -> t -> t

val add_document : Document.t -> t -> t

val usable_documents : t -> (Document.t * Search_result.t array) array
