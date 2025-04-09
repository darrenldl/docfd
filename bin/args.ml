open Cmdliner
open Misc_utils

let no_pdftotext_arg_name = "no-pdftotext"

let no_pdftotext_arg =
  let doc =
    Fmt.str {|Disable use of pdftotext command.
    Files that require use of pdftotext are excluded.
    |}
  in
  Arg.(value & flag & info [ no_pdftotext_arg_name ] ~doc)

let no_pandoc_arg_name = "no-pandoc"

let no_pandoc_arg =
  let doc =
    Fmt.str {|Disable use of pandoc command.
    Files that require use of pandoc are excluded.
    |}
  in
  Arg.(value & flag & info [ no_pandoc_arg_name ] ~doc)

let hidden_arg_name = "hidden"

let hidden_arg =
  let doc =
    Fmt.str {|Scan hidden files and directories.
By default, hidden files and directories are skipped.

A file or directory is hidden if the base name starts
with a dot, e.g. ".gitignore".
    |}
  in
  Arg.(value & flag & info [ hidden_arg_name ] ~doc)

let max_depth_arg_name = "max-depth"

let max_depth_arg =
  let doc =
    Fmt.str
      "Scan up to N levels when exploring file trees.
This applies to directory paths provided
and ** in globs.
Note that --%s 0 results in no-op when scanning
directories, and --%s 1 means only scanning for
direct children."
      max_depth_arg_name
      max_depth_arg_name
  in
  Arg.(
    value
    & opt int Params.default_max_file_tree_scan_depth
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

let single_file_exts_arg_name = Fmt.str "single-line-%s" exts_arg_name

let single_line_exts_arg =
  let doc =
    Fmt.str "Same as --%s, but use single line search mode instead.
If an extension appears in both --%s and --%s,
then single line search mode is used for that extension."
      exts_arg_name
      exts_arg_name
      single_file_exts_arg_name
  in
  Arg.(
    value
    & opt string Params.default_recognized_single_line_exts
    & info [ single_file_exts_arg_name ] ~doc ~docv:"EXTS"
  )

let add_exts_arg_name = "add-exts"

let add_exts_arg =
  let doc =
    "Additional file extensions to use, comma separated.
May be specified multiple times."
  in
  Arg.(
    value
    & opt_all string []
    & info [ add_exts_arg_name ] ~doc ~docv:"EXTS"
  )

let single_line_add_exts_arg_name = Fmt.str "single-line-%s" add_exts_arg_name

let single_line_add_exts_arg =
  let doc =
    Fmt.str "Same as --%s, but use single line search mode instead." add_exts_arg_name
  in
  Arg.(
    value
    & opt_all string []
    & info [ single_line_add_exts_arg_name ] ~doc ~docv:"EXTS"
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
    "Maximum distance to look for the next matching token in document.
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
Two tokens are linked if there is no space between them in the search phrase,
e.g. "-" and ">" are linked in "->" but not in "- >",
"and" "/" "or" are linked in "and/or" but not in "and / or".|}
      max_token_search_dist_arg_name
  in
  Arg.(
    value
    & opt int Params.default_max_linked_token_search_dist
    & info [ max_linked_token_search_dist_arg_name ] ~doc ~docv:"N"
  )

let tokens_per_search_scope_level_arg_name = "tokens-per-search-scope-level"

let tokens_per_search_scope_level_arg =
  let doc =
    Fmt.str
      {|Number of tokens to use around the current search
results for each search scope level in narrow mode.|}
  in
  Arg.(
    value
    & opt int Params.default_tokens_per_search_scope_level
    & info [ tokens_per_search_scope_level_arg_name ] ~doc ~docv:"N"
  )

let index_chunk_size_arg_name = "index-chunk-size"

let index_chunk_size_arg =
  let doc =
    "Number of tokens to send as a task unit to the thread pool for indexing."
  in
  Arg.(
    value
    & opt int Params.default_index_chunk_size
    & info [ index_chunk_size_arg_name ] ~doc ~docv:"N"
  )

let cache_dir_arg =
  let doc =
    "Index cache directory."
  in
  let cache_home = Xdg_utils.cache_home in
  Arg.(
    value
    & opt string (Filename.concat cache_home "docfd")
    & info [ "cache-dir" ] ~doc ~docv:"DIR"
  )

let cache_limit_arg_name = "cache-limit"

let cache_limit_arg =
  let doc =
    "Maximum number of documents to keep in index.
Docfd resets the cache to this limit at launch."
  in
  Arg.(
    value
    & opt int Params.default_cache_limit
    & info [ cache_limit_arg_name ] ~doc ~docv:"N"
  )

let index_only_arg =
  let doc =
    Fmt.str "Exit after indexing."
  in
  Arg.(value & flag & info [ "index-only" ] ~doc)

let debug_log_arg =
  let doc =
    Fmt.str "Specify debug log file to use and enable debug mode where
additional checks are enabled and additional info is displayed on UI.
If FILE is -, then debug log is printed to stderr instead.
Otherwise FILE is opened in append mode for log writing."
  in
  Arg.(
    value
    & opt (some string) None
    & info [ "debug-log" ] ~doc ~docv:"FILE"
  )

let start_with_search_arg_name = "start-with-search"

let start_with_search_arg =
  let doc =
    Fmt.str "Start interactive mode with search expression EXP."
  in
  Arg.(
    value
    & opt (some string) None
    & info [ start_with_search_arg_name ] ~doc ~docv:"EXP"
  )

let sample_arg_name = "sample"

let samples_per_doc_arg_name = "samples-per-doc"

let sample_arg =
  let doc =
    Fmt.str "Search with expression EXP in non-interactive mode but only
show top N results where N is controlled by --%s."
      samples_per_doc_arg_name
  in
  Arg.(
    value
    & opt (some string) None
    & info [ sample_arg_name ] ~doc ~docv:"EXP"
  )

let samples_per_doc_arg =
  let doc =
    Fmt.str
      "Number of search results to show per document when --%s is used
or when samples printing is triggered."
      sample_arg_name
  in
  Arg.(
    value
    & opt int Params.default_samples_per_document
    & info [ samples_per_doc_arg_name ] ~doc ~docv:"N"
  )

let search_arg_name = "search"

let search_arg =
  let doc =
    "Search with expression EXP in non-interactive mode and show all results."
  in
  Arg.(
    value
    & opt (some string) None
    & info [ search_arg_name ] ~doc ~docv:"EXP"
  )

let style_mode_options = [ ("never", `Never); ("always", `Always); ("auto", `Auto) ]

let color_arg =
  let doc =
    Fmt.str
      "Set color mode for search result printing, one of: %s."
      (String.concat ", " (List.map fst style_mode_options))
  in
  Arg.(
    value
    & opt (Arg.enum style_mode_options) `Auto
    & info [ "color" ] ~doc ~docv:"MODE"
  )

let underline_arg =
  let doc =
    Fmt.str
      "Set underline mode for search result printing, one of: %s."
      (String.concat ", " (List.map fst style_mode_options))
  in
  Arg.(
    value
    & opt (Arg.enum style_mode_options) `Auto
    & info [ "underline" ] ~doc ~docv:"MODE"
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

let search_result_print_snippet_min_size_arg_name = "search-result-print-snippet-min-size"

let search_result_print_snippet_min_size_arg =
  let doc =
    "If the search result to be printed has fewer than N non-space tokens,
then Docfd tries to add surrounding lines to the snippet
to give better context."
  in
  Arg.(
    value
    & opt int Params.default_search_result_print_snippet_min_size
    & info [ search_result_print_snippet_min_size_arg_name ] ~doc ~docv:"N"
  )

let search_result_print_snippet_max_add_lines_arg_name = "search-result-print-snippet-max-add-lines"

let search_result_print_snippet_max_add_lines_arg =
  let doc =
    "This controls the maximum number of surrounding lines
Docfd can add in each direction."
  in
  Arg.(
    value
    & opt int Params.default_search_result_print_snippet_max_additional_lines_each_direction
    & info [ search_result_print_snippet_max_add_lines_arg_name ] ~doc ~docv:"N"
  )

let commands_from_arg_name = "commands-from"

let commands_from_arg =
  let doc =
    Fmt.str "Read and run command file FILE."
  in
  Arg.(
    value
    & opt (some string) None
    & info [ commands_from_arg_name ] ~doc ~docv:"FILE"
  )

let paths_from_arg_name = "paths-from"

let paths_from_arg =
  let doc =
    Fmt.str "Read list of paths from FILE
and add to the final list of paths to be scanned."
  in
  Arg.(
    value
    & opt_all string []
    & info [ paths_from_arg_name ] ~doc ~docv:"FILE"
  )

let glob_arg_name = "glob"

let glob_arg =
  let doc =
    "Add to the final list of paths to be scanned using glob pattern.
The pattern should pick up the files directly.
Directories picked up by the pattern are not further scanned
for files with suitable extensions."
  in
  Arg.(
    value
    & opt_all string []
    & info [ glob_arg_name ] ~doc ~docv:"PATTERN"
  )

let single_line_glob_arg_name = Fmt.str "single-line-%s" glob_arg_name

let single_line_glob_arg =
  let doc =
    Fmt.str
      "Same as --%s, but use single line search mode instead.
If the file are picked up by both patterns from --%s and --%s,
then single line search mode is used."
      glob_arg_name
      glob_arg_name
      single_line_glob_arg_name
  in
  Arg.(
    value
    & opt_all string []
    & info [ single_line_glob_arg_name ] ~doc ~docv:"PATTERN"
  )

let single_line_arg =
  let doc =
    "Use single line search mode by default."
  in
  Arg.(
    value
    & flag
    & info [ "single-line" ] ~doc
  )

let open_with_arg_name = "open-with"

let open_with_arg =
  let doc =
    Fmt.str "Specify custom command for
opening files under a specific file extension.
May be specified multiple times.
Format of SPEC: [EXT]:[fg|foreground|bg|background]=[CMD].
Leading dots of extension [EXT] are removed.
Foreground is for commands which Docfd
should run in the terminal and wait for completion,
e.g. text editors, pagers.
Background is for background
commands, such as PDF viewers or
other GUI tools.
[CMD] may contain the following placeholders
to be filled in by Docfd:
{path} - file path,
{page_num} - page number (PDF only),
{line_num} - line number,
{search_word} - most unique word of the page
(PDF only, useful for passing to PDF viewer).
Examples: \"--%s pdf:bg='okular --page {page_num} --find {search_word} {path}'\",
\"--%s txt:fg='nano +{line_num} {path}'\".
"
      open_with_arg_name
      open_with_arg_name
  in
  Arg.(
    value
    & opt_all string []
    & info [ open_with_arg_name ] ~doc ~docv:"SPEC"
  )

let files_with_match_arg_name = "files-with-match"

let files_with_match_arg =
  let doc =
    Fmt.str "If paired with
--%s or --%s,
then print the paths of documents with at least one match
instead of printing the search results.
If paired with --%s, then print paths of documents
that would have be listed in the UI
after running the commands in interactive mode."
      search_arg_name
      sample_arg_name
      commands_from_arg_name
  in
  Arg.(
    value
    & flag
    & info [ "l"; files_with_match_arg_name ] ~doc
  )

let files_without_match_arg_name = "files-without-match"

let files_without_match_arg =
  let doc =
    Fmt.str "If paired with
--%s or --%s,
then print the paths of documents with no matches
instead of printing the search results.
If paired with --%s, then print paths of documents
that would have be unlisted in the UI
after running the commands in interactive mode."
      search_arg_name
      sample_arg_name
      commands_from_arg_name
  in
  Arg.(
    value
    & flag
    & info [ files_without_match_arg_name ] ~doc
  )

let paths_arg =
  let doc =
    Fmt.str
      "PATH can be either file or directory.
Directories are scanned for files with matching extensions.
If any PATH is \"?\", then the list of files is passed onto fzf for user selection.
Multiple \"?\" are treated the same as one \"?\".
If no paths are provided or only \"?\" is provided,
then Docfd defaults to scanning the current working directory
unless any of the following is used: %a.
To use piped stdin as input, the list of paths must be empty."
      Fmt.(list ~sep:comma (fun fmt s -> Fmt.pf fmt "--%s" s))
      [ paths_from_arg_name; glob_arg_name; single_line_glob_arg_name ]
  in
  Arg.(value & pos_all string [] & info [] ~doc ~docv:"PATH")

let check
    ~max_depth
    ~max_fuzzy_edit_dist
    ~max_token_search_dist
    ~max_linked_token_search_dist
    ~tokens_per_search_scope_level
    ~index_chunk_size
    ~cache_limit
    ~samples_per_doc
    ~search_result_print_text_width
    ~search_result_print_snippet_min_size
    ~search_result_print_max_add_lines
    ~print_files_with_match
    ~print_files_without_match
  =
  if max_depth < 0 then (
    exit_with_error_msg
      (Fmt.str "invalid %s: cannot be < 0" max_depth_arg_name)
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
  if tokens_per_search_scope_level < 1 then (
    exit_with_error_msg
      (Fmt.str "invalid %s: cannot be < 1" tokens_per_search_scope_level_arg_name)
  );
  if index_chunk_size < 1 then (
    exit_with_error_msg
      (Fmt.str "invalid %s: cannot be < 1" index_chunk_size_arg_name)
  );
  if cache_limit < 1 then (
    exit_with_error_msg
      (Fmt.str "invalid %s: cannot be < 1" cache_limit_arg_name)
  );
  if samples_per_doc < 1 then (
    exit_with_error_msg
      (Fmt.str "invalid %s: cannot be < 1" samples_per_doc_arg_name)
  );
  if search_result_print_text_width < 1 then (
    exit_with_error_msg
      (Fmt.str "invalid %s: cannot be < 1" search_result_print_text_width_arg_name)
  );
  if search_result_print_snippet_min_size < 0 then (
    exit_with_error_msg
      (Fmt.str "invalid %s: cannot be < 0" search_result_print_snippet_min_size_arg_name)
  );
  if search_result_print_max_add_lines < 0 then (
    exit_with_error_msg
      (Fmt.str "invalid %s: cannot be < 0" search_result_print_snippet_max_add_lines_arg_name)
  );
  if print_files_with_match && print_files_without_match then (
    exit_with_error_msg
      (Fmt.str "cannot specify both --%s and --%s" files_with_match_arg_name files_without_match_arg_name)
  )
