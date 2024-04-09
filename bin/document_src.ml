type file_collection = {
  default_search_mode_files : String_set.t;
  single_line_search_mode_files : String_set.t;
}

let seq_of_file_collection (x : file_collection) =
  Seq.append
    (String_set.to_seq x.default_search_mode_files)
    (String_set.to_seq x.single_line_search_mode_files)

let file_collection_size (x : file_collection) =
  String_set.cardinal x.default_search_mode_files
  + String_set.cardinal x.single_line_search_mode_files

let empty_file_collection =
  {
    default_search_mode_files = String_set.empty;
    single_line_search_mode_files = String_set.empty;
  }

type t =
  | Stdin of string
  | Files of file_collection
