type file_collection = {
  all_files : String_set.t;
  single_line_files : String_set.t;
}

let empty_file_collection =
  {
    all_files = String_set.empty;
    single_line_files = String_set.empty;
  }

type t =
  | Stdin of string
  | Files of file_collection
