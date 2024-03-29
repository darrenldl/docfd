open Cmdliner
open Misc_utils

let max_depth_arg_name = "max-depth"

let max_depth_arg =
  let doc =
    "Scan up to N levels in the file tree."
  in
  Arg.(
    value
    & opt int Params.default_max_file_tree_depth
    & info [ max_depth_arg_name ] ~doc ~docv:"N"
  )

let exts_arg_name = "exts"

let exts_arg =
  let doc =
    "File extensions to use, comma separated. Leading dots of any extension are removed."
  in
  Arg.(
    value
    & opt string Params.default_recognized_exts
    & info [ exts_arg_name ] ~doc ~docv:"EXTS"
  )

let add_exts_arg_name = "add-exts"

let add_exts_arg =
  let doc =
    "Additional file extensions to use, comma separated."
  in
  Arg.(
    value
    & opt string ""
    & info [ add_exts_arg_name ] ~doc ~docv:"EXTS"
  )

let max_fuzzy_edit_dist_arg_name = "max-fuzzy-edit-dist"

let max_fuzzy_edit_dist_arg =
  let doc =
    "Maximum edit distance for fuzzy matches."
  in
  Arg.(
    value
    & opt int Params.default_max_fuzzy_edit_dist
    & info [ max_fuzzy_edit_dist_arg_name ] ~doc ~docv:"N"
  )

let max_token_search_dist_arg_name = "max-token-search-dist"

let max_token_search_dist_arg =
  let doc =
    "Maximum distance to look for the next matching token in search phrase.
If two tokens are adjacent, then they are 1 distance away from each other.
Note that contiguous spaces count as one token as well."
  in
  Arg.(
    value
    & opt int Params.default_max_token_search_dist
    & info [ max_token_search_dist_arg_name ] ~doc ~docv:"N"
  )

let max_linked_token_search_dist_arg_name = "max-linked-token-search-dist"

let max_linked_token_search_dist_arg =
  let doc =
    Fmt.str
      {|Similar to %s but for linked tokens.
Two tokens are linked if there is no space between them,
e.g. "-" and ">" are linked in "->" but not in "- >",
"and" "/" "or" are linked in "and/or" but not in "and / or".|}
      max_token_search_dist_arg_name
  in
  Arg.(
    value
    & opt int Params.default_max_linked_token_search_dist
    & info [ max_linked_token_search_dist_arg_name ] ~doc ~docv:"N"
  )

let index_chunk_token_count_arg_name = "index-chunk-token-count"

let index_chunk_token_count_arg =
  let doc =
    "Number of tokens to send as a task unit to the thread pool for indexing."
  in
  Arg.(
    value
    & opt int Params.default_index_chunk_token_count
    & info [ index_chunk_token_count_arg_name ] ~doc ~docv:"N"
  )

let cache_dir_arg =
  let doc =
    "Index cache directory."
  in
  let home_dir =
    match Sys.getenv_opt "HOME" with
    | None -> (
        exit_with_error_msg "environment variable HOME is not set";
      )
    | Some home -> home
  in
  let cache_home =
    match Sys.getenv_opt "XDG_CACHE_HOME" with
    | None -> Filename.concat home_dir ".cache"
    | Some x -> x
  in
  Arg.(
    value
    & opt string (Filename.concat cache_home "docfd")
    & info [ "cache-dir" ] ~doc ~docv:"DIR"
  )

let cache_size_arg_name = "cache-size"

let cache_size_arg =
  let doc =
    "Maximum number of indices to cache. One index corresponds to one file."
  in
  Arg.(
    value
    & opt int Params.default_cache_size
    & info [ cache_size_arg_name ] ~doc ~docv:"N"
  )

let no_cache_arg =
  let doc =
    Fmt.str "Disable caching."
  in
  Arg.(value & flag & info [ "no-cache" ] ~doc)

let index_only_arg =
  let doc =
    Fmt.str "Exit after indexing."
  in
  Arg.(value & flag & info [ "index-only" ] ~doc)

let debug_log_arg =
  let doc =
    Fmt.str "Specify debug log file to use and enable debug mode where additional info is displayed on UI. If FILE is -, then debug log is printed to stderr instead. Otherwise FILE is opened in append mode for log writing."
  in
  Arg.(
    value
    & opt (some string) None
    & info [ "debug-log" ] ~doc ~docv:"FILE"
  )

let start_with_search_arg =
  let doc =
    Fmt.str "Start interactive mode with search expression EXP."
  in
  Arg.(
    value
    & opt (some string) None
    & info [ "start-with-search" ] ~doc ~docv:"EXP"
  )

let search_arg =
  let doc =
    Fmt.str "Search with expression EXP in non-interactive mode."
  in
  Arg.(
    value
    & opt (some string) None
    & info [ "search" ] ~doc ~docv:"EXP"
  )

let search_result_count_per_doc_arg_name = "search-result-count-per-doc"

let search_result_count_per_doc_arg =
  let doc =
    "Number of search results per document to show in non-interactive search mode."
  in
  Arg.(
    value
    & opt int Params.default_non_interactive_search_result_count_per_document
    & info [ search_result_count_per_doc_arg_name ] ~doc ~docv:"N"
  )

let search_result_print_text_width_arg_name = "search-result-print-text-width"

let search_result_print_text_width_arg =
  let doc =
    "Text width to use when printing search results."
  in
  Arg.(
    value
    & opt int Params.default_search_result_print_text_width
    & info [ search_result_print_text_width_arg_name ] ~doc ~docv:"N"
  )

let paths_from_arg =
  let doc =
    Fmt.str "Read list of paths from FILE
and add to the final list of paths to be scanned."
  in
  Arg.(
    value
    & opt (some string) None
    & info [ "paths-from" ] ~doc ~docv:"FILE"
  )

let paths_arg =
  let doc =
    "PATH can be either file or directory.
Directories are scanned for files with matching extensions.
If any PATH is \"?\", then the list of files is passed onto fzf for user selection.
Multiple \"?\" are treated the same as one \"?\".
If no paths are provided or only \"?\" is provided,
then Docfd defaults to scanning the current working directory
unless --paths-from is used."
  in
  Arg.(value & pos_all string [] & info [] ~doc ~docv:"PATH")

let check
    ~max_depth
    ~max_fuzzy_edit_dist
    ~max_token_search_dist
    ~max_linked_token_search_dist
    ~index_chunk_token_count
    ~cache_size
    ~search_result_count_per_doc
    ~search_result_print_text_width =
  if max_depth < 1 then (
    exit_with_error_msg
      (Fmt.str "invalid %s: cannot be < 1" max_depth_arg_name)
  );
  if max_fuzzy_edit_dist < 0 then (
    exit_with_error_msg
      (Fmt.str "invalid %s: cannot be < 0" max_fuzzy_edit_dist_arg_name)
  );
  if max_token_search_dist < 1 then (
    exit_with_error_msg
      (Fmt.str "invalid %s: cannot be < 1" max_token_search_dist_arg_name)
  );
  if max_linked_token_search_dist < 1 then (
    exit_with_error_msg
      (Fmt.str "invalid %s: cannot be < 1" max_linked_token_search_dist_arg_name)
  );
  if index_chunk_token_count < 1 then (
    exit_with_error_msg
      (Fmt.str "invalid %s: cannot be < 1" index_chunk_token_count_arg_name)
  );
  if cache_size < 1 then (
    exit_with_error_msg
      (Fmt.str "invalid %s: cannot be < 1" cache_size_arg_name)
  );
  if search_result_count_per_doc < 1 then (
    exit_with_error_msg
      (Fmt.str "invalid %s: cannot be < 1" search_result_count_per_doc_arg_name)
  );
  if search_result_print_text_width < 1 then (
    exit_with_error_msg
      (Fmt.str "invalid %s: cannot be < 1" search_result_print_text_width_arg_name)
  )
