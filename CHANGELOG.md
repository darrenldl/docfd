# Changelog

## 9.0.0-rc2

- Swapped over to using SQLite for index

    - Memory usage is much slimmer/stays flat

        - For the sample of 1.4GB worth of PDFs used, after indexing, 9.0.0-rc1 uses
          1.9GB of memory, while 9.0.0-rc2 uses 39MB

    - Search is a bit slower

- Added `Ctrl`+`C` exit key binding to key binding info on screen

- Updated exit keys

    - To exit Docfd: `q`, `Ctrl`+`Q` or `Ctrl`+`C`

    - To exit other modes: `Esc`

- Now defaults to not scanning hidden files and directories

    - This behaviour is now enabled via the `--hidden` flag

- Changed to allow `--add-exts` and `--single-line-add-exts` to be specified multiple times

- Changed return code to be 1 when there are no results for `--sample` or `--search`

- Added `--no-pdftotext` and `--no-pandoc` flags

    - Docfd also notes the presence of these flags in error message if there
      are PDF files but no pdftotext command is available, and same with files
      relying on pandoc

- Various key binding improvements

- Various key binding help info grid adjustments

## 9.0.0-rc1

- Changed default cache size from 100 to 10000

    - Index after compression doesn't take up that much space, and storage is
      generally cheap enough these days

- Adjusted cache eviction behaviour to be less strict on when eviction happens
  and thus less expensive

- Renamed `--cache-size` to `--cache-soft-limit`

- Removed periodic GC compact call to avoid freezes when working with many
  files

- Removed GC compact call during file indexing core loops to reduce overhead

- Added progress bars to initial document processing stage

- Swapped to using C backend for BLAKE2B hashing, this gives >20x speedup depending on CPU

- Swapped from JSON+GZIP to CBOR+GZIP serialization for indices

- Changed help info rotation key from `h` to `?`

- Renamed discard mode to drop mode

- Added command history editing functionality

- Added `--commands-from` command line argument

- Added `--tokens-per-search-scope-level` command line argument

- Concurrency related bug fixes

    - Unlikely to encounter in normal workflows with human input speed

    - https://github.com/darrenldl/docfd/commit/14fcc45b746e6156f29eb989d70700476977a3d7

    - https://github.com/darrenldl/docfd/commit/bfd63d93562f8785ecad8152005aa0f823185699

    - https://github.com/darrenldl/docfd/commit/4e0aa6785ce80630d0cd3cda6e316b7b15a4fb4b

- Replaced print mode with copy mode

- Replaced single file view with key binding to change screen split ratio
  to remove feature discrepencies

- Added narrow mode for search scope narrowing

- Renamed `--index-chunk-token-count` to `--index-chunk-size`

- Renamed `--sample-count-per-doc` to `--samples-per-doc`

## 8.0.3

- Fixed single file view crash

## 8.0.2

- Reworked asynchronous search/filter UI code to avoid noticeable lag due to
  waiting for cancellations that take too long

    - Previously there was still a lockstep somewhere that would prevent UI
      from progressing if previous search was still being cancelled

    - The current implementation allows newest requests to override older
      requests entirely, and not wait for cancellations at all

- Adjusted document counter in multi-file view to be visible even when no files
  are listed

## 8.0.1

- Fixed missing file path filter field update when undoing or redoing document
  store updates

- Fixed case insensitive marker handling in glob command line arguments

## 8.0.0

- Removed `--markdown-headings atx` from pandoc commandline
  arguments

- Removed `Alt`+`U` undo key binding

- Removed `Alt`+`E` redo key binding

- Removed `Ctrl`+`Q` exit key binding

- Added documentation for undo, redo key bindings

- Added clear mode and moved clear search field key binding
  under this mode for multi-file view

- Added file path filtering functionality to multi-file view

## 7.1.0

- Added initial macOS support

    - Likely to have bugs, but will need macOS users to report back

- Major speedup from letting `pdftotext` output everything in one pass and split
  on Docfd side instead of asking `pdftotext` to output one page per invocation

    - For very large PDFs the indexing used to take minutes but now only takes
      seconds

    - Page count may be inaccurate if the PDF page contains form feed character
      itself (not fully sure if `pdftotext` filters the form feed character from
      content), but should be rare

- Significant reduction of index file size by adding GZIP
  compression to the index JSON

## 7.0.0

- Added discard mode to multi-file view

- Changed to using thin bars as pane separators, i.e. tmux style

- Added `g` and `G` key bindings for going to top and bottom of document list respectively

- Added `-l`/`--files-with-match` and `--files-without-match` for printing just paths
  in non-interactive mode

- Grouped print key bindings under print mode

- Added more print key bindings

- Grouped reload key bindings under reload mode

- Added fixes to ensure Docfd does not exit until all printing is done

- Slimmed down memory usage by switching to OCaml 5.2 which enables use of `Gc.compact`

    - Still no auto-compaction yet, however, will need to wait for a future
      OCaml release

- Added `h` key binding to rotate key binding info grid

- Added exact, prefix and suffix search syntax from fzf

- Fixed extraneous document path print in non-interactive mode when documents have no search results

- Added "explicit spaces" token `~` to match spaces

## 6.0.1

- Fixed random UI freezes when updating search field

    - This is due to a race condition in the search cancellation mechanism that
      may cause UI fiber to starve and wait forever for a cancellation
      acknowledgement

    - This mechanism was put in place for asynchronous search since 4.0.0

    - As usual with race conditions, this only manifests under some specific
      timing by chance

## 6.0.0

- Fixed help message of `--max-linked-token-search-dist`

- Fixed search result printing where output gets chopped off if terminal width is too small

- Added smart additional line grabbing for search result printing

    - `--search-result-print-snippet-min-size N`
        - If the search result to be printed has fewer than `N` non-space tokens,
          then Docfd tries to add surrounding lines to the snippet
          to give better context.
    - `--search-result-print-snippet-max-add-lines`
        - Controls maximum number of surrounding lines that can be added in each direction.

- Added search result underlining when output is not a terminal,
  e.g. redirected to file, piped to another command

- Changed `--search` to show all search results

- Added `--sample` that uses `--search` previous behavior where (by default)
  only a handful of top search results are picked for each document

- Changed `--search-result-count-per-doc` to `--sample-count-per-doc`

- Added `--color` and `--underline` for controlling behavior of search result
  printing, they can take one of:

    - `never`
    - `always`
    - `auto`

- Removed blinking for `Tab` key presses

## 5.1.0

- Fixed help message of `--max-token-search-dist`

- Adjusted path display in UI to hide current working directory segment when
  applicable

- Added missing blinking for `Tab` key presses

## 5.0.0

- Added file globbing support in the form of `--glob` argument

- Added single line search mode arguments

    - `--single-line-exts`
    - `--single-line-add-exts`
    - `--single-line-glob`
    - `--single-line`

- Fixed crash on empty file

   - This was due to assertion failure of `max_line_num` in
     `Content_and_search_result_render.content_snippet`

- Changed search result printing via `Shift+P` and `p` within TUI to not exit
  after printing, allowing printing of more results

- Added blinking to key binding info grid to give better visual feedback,
  especially for the new behavior of search result printing

- Changed to allow `--paths-from` to be specified multiple times

- Fixed handling of `.htm` files

    - `htm` is not a valid value for pandoc's `--format` argument
    - Now it is rewritten to `html` before being passed to pandoc

- Changed `--max-depth`:

    - Changed default from 10 to 100
    - Changed to accept 0

## 4.0.0

- Made document search asynchronous to search field input, so UI remains
  smooth even if search is slow

- Added status to search bar:

    - `OK` means Docfd is idling
    - `...` means Docfd is searching
    - `ERR` means Docfd failed to parse the search expression

- Added search cancellation. Triggered by editing or clearing search field.

- Added dynamic search distance adjustment based on notion of linked tokens

    - Two tokens are linked if there is no space between them,
      e.g. `-` and `>` are linked in `->`, but not in `- >`

- Replaced `word` with `token` in the following options for consistency

    - `--max-word-search-dist`
    - `--index-chunk-word-count`

- Replaced `word` with `token` in user-facing text

## 3.0.0

- Fixed crash from search result snippet being bigger the content view pane

    - Crash was from `Content_and_search_result_render.color_word_image_grid`

- Added key bindings

    - `p`: exit and print search result to stderr
    - `Shift+P`: exit and print file path to stderr

- Changed `--debug-log -` to use stderr instead of stdout

- Added non-interactive search mode where search results are printed to stdout

    - `--search EXP` invokes non-interactive search mode with search expression `EXP`
    - `--search-result-count-per-document` sets the number of top search results printed per document
    - `--search-result-print-text-width`  sets the text width to use when printing

- Added `--start-with-search` to prefill the search field in interactive mode

- Removed content requirement expression from multi-file view

    - Originally designed for file filtering, but I have almost never used
      it since its addition in 1.0.0

- Added word based line wrapping to following components of document list in multi-file view

    - Document title
    - Document path
    - Document content preview

- Added word breaking in word based line wrapping logic so all of the original characters
  are displayed even when the terminal width is very small or when a word/token is very long

- Added `--paths-from` to specify a file containing list of paths to (also) be scanned

- Fixed search result centering in presence of line wrapping

- Renamed `--max-fuzzy-edit` to `--max-fuzzy-edit-dist` for consistency

- Changed error messages to not be capitalized to follow Rust's and Go's
  guidelines on error messages

- Added fallback rendering text so Docfd does not crash from trying
  to render invalid text.

- Added pandoc integration

- Changed the logic of determining when to use stdin as document source

    - Now if any paths are specified, stdin is ignored
    - This change mostly came from Dune's cram test mechanism
      not providing a tty to stdin, so previously Docfd would keep
      trying to source from stdin even when explicit paths are provided

## 2.2.0

- Restored behaviour of skipping file extension checks for top-level
  user specified files. This behaviour was likely removed during some
  previous overhaul.

    - This means, for instance, `docfd bin/docfd.ml` will now open the file
      just fine without `--add-exts ml`

- Bumped default max word search distance from 20 to 50

- Added consideration for balanced opening closing symbols in search result ranking

    - Namely symbol pairs: `()`, `[]`, `{}`

- Fixed crash from reading from stdin

    - This was caused by calling `Notty_unix.Term.release` after closing the underlying
      file descriptor in stdin input mode

- Added back handling of optional operator `?` in search expression

- Added test corpus to check translation of search expression to search phrases

## 2.1.0

- Added text editor integration for `jed`/`xjed`

    - See [PR #3](https://github.com/darrenldl/docfd/pull/3)
      by [kseistrup](https://github.com/kseistrup)

## 2.0.0

- Added "Last scan" field display to multi-file view and single file view

- Reduced screen flashing by only recreating `Notty_unix.Term.t` when needed

- Added code to recursively mkdir cache directory if needed

- Search procedure parameter tuning

- UI tuning

- Added search expression support

- Adjusted quit key bindings to be: `Esc`, `Ctrl+C`, and `Ctrl+Q`

- Added file selection support via `fzf`

## 1.9.0

- Added PDF viewer integration for:

    - okular
    - evince
    - xreader
    - atril
    - mupdf

- Fixed change in terminal behavior after invoking text editor
  by recreating `Notty_unix.Term.t`

- Fixed file auto-reloading to apply to all file types instead of
  just text files

## 1.8.0

- Swapped to using Nottui at [a337a77](https://github.com/let-def/lwd/commit/a337a778001e6c1dbaed7e758c9e05f300abd388)
  which fixes event handling, and pasting into edit field works correctly as a result

- Caching is now disabled if number of documents exceeds cache size

- Moved index cache to `XDG_CACHE_HOME/docfd`, which overall
  defaults to `$HOME/.cache/docfd`

- Added cache related arguments

    - `--cache-dir`
    - `--cache-size`
    - `--no-cache`

- Fixed search result centering in content view pane

- Changed `--debug` to `--debug-log` to support outputting debug log to a file

- Fixed file opening failure due to exhausting file descriptors

    - This was caused by not bounding the number of concurrent fibers when loading files
      via `Document.of_path` in `Eio.Fiber.List.filter_map`

- Added `--index-only` flag

- Fixed document rescanning in multi-file view

## 1.7.3

- Fixed crash from using mouse scrolling in multi-file view

    - The mouse handler did not reset the search result selected
      when selecting a different document
    - This leads to out of bound access if the newly selected document
      does not have enough search results

## 1.7.2

- Fixed content pane sometimes not showing all the lines
  depending on terminal size and width of lines

- Made chunk size dynamic for parallel search

## 1.7.1

- Parallelization fine-tuning

## 1.7.0

- Added back parallel search

- General optimizations

- Added index file rotation

## 1.6.3

- Further underestimate space available for the purpose of line wrapping

## 1.6.2

- Fixed line wrapping

## 1.6.1

- Fixed line wrapping

## 1.6.0

- Docfd now saves stdin into a tmp file before processing
  to allow opening in text editor

- Added `--add-exts` argument for additional file extensions

- Added real-time response to terminal size changes

## 1.5.3

- Updated key binding info pane of multi-file view

## 1.5.2

- Added line number into search result ranking consideration

## 1.5.1

- Tuned search procedure and search result ranking

    - Made substring bidirectional matching differently weighted based
      on direction
    - Made reverse substring match require at least 3 characters
    - Case-sensitive bonus only applies if search phrase
      is not all ascii lowercase

## 1.5.0

- Made substring matching bidirectional

- Tuned search result ranking

## 1.4.0

- Moved reading of environment variables `VISUAL` and `EDITOR` to program start

- Performance tuning

    - Increased cache size for search phrase automata

## 1.3.4

- Added dispatching of search to task pool at file granularity

## 1.3.3

- Performance tuning

    - Switched back to using the old default max word search distance of 20
    - Reduced default max fuzzy edit distance from 3 to 2 to prevent massive
      slowdown on long words

## 1.3.2

- Performance tuning

    - Added caching to search phrase automata construction
    - Removed dispatching of search to task pool
    - Adjusted search result limits

## 1.3.1

- Added more commandline argument error checking

- Adjusted help messages

- Adjusted max word search range calculation

- Renamed `max-word-search-range` to `max-word-search-dist`

## 1.3.0

- Index data structure optimizations

- Search procedure optimizations

## 1.2.2

- Fixed editor recognition for kakoune

## 1.2.1

- Fixed search results when multiple words are involved

## 1.2.0

- Removed UI components for search cancellation

- Added real time refresh of search

- Added code to open selected text file to selected search result for:

    - nano
    - neovim/vim/vi
    - helix
    - kakoune
    - emacs
    - micro

- Added "rescan for documents" to multi-file view

## 1.1.1

- Fixed releasing Notty terminal too early

## 1.1.0

- Added index saving and loading

- Added search cancellation

## 1.0.2

- Fixed file tree scan

## 1.0.1

- Minor UI tweaks

## 1.0.0

- Added expression language for file filtering in multi-file view

- Adjusted default file tree depth

- Added `--exts` argument for configuring file extensions recognized

- Fixed parameters passing from binary to library

## 0.9.0

- Added PDF search support via `pdftotext`

- Added UTF-8 support

## 0.8.6

- Minor wording fix

## 0.8.5

- Added check to skip re-searching if search phrase is equivalent to the previous one

## 0.8.4

- Index data structure optimization

- Code cleanup

## 0.8.3

- Optimized multi-file view reload so it does not redo the search over all documents

- Implemented a proper document store

## 0.8.2

- Fixed single file view document reloading not refreshing search results

## 0.8.1

- Replaced shared data structures with multicore safe versions

- Fixed work partitioning for parallel indexing

## 0.8.0

- Added multicore support for indexing and searching

## 0.7.4

- Fixed crashing and incorrect rendering in some cases of files with blank lines

    - This is due to `Index.line_count` being incorrectly calculated

- Added auto refresh on change of file

    - Change detection is based on file modification time

- Added reload file via `r` key

## 0.7.3

- Bumped the default word search range from 15 to 40

    - Since spaces are also counted as words in the index,
      15 doesn't actually give a lot of range

- Added minor optimization to search

## 0.7.2

- Code refactoring

## 0.7.1

- Delayed `Nottui_unix` term creation so pre TUI
  printing like `--version` would work

- Added back mouse scrolling support

- Added Page Up and Page Down keys support

## 0.7.0

- Fixed indexing bug

- Added UI mode switch

- Adjusted status bar to show current file name in single file mode

- Adjusted content view to track search result

- Added content view to single file mode

## 0.6.3

- Adjusted status bar to not display index of document selected
  when in single document mode

- Edited debug message a bit

## 0.6.2

- Fixed typo in error message

## 0.6.1

- Added check of whether provided files exist

## 0.6.0

- Upgraded status bar and help text/key binding info

## 0.5.9

- Changed help text to status bar + help text

## 0.5.8

- Fixed debug print of file paths

- Tuned UI text slightly

## 0.5.7

- Changed word db to do global word recording to further reduce memory footprint

## 0.5.6

- Optimized overall memory footprint

    - Content index memory usage

    - Switched to using content index to render content
      lines instead of storing file lines again after indexing

## 0.5.5

- Fixed weighing of fuzzy matches

- Fixed bug in scoring of substring matches

## 0.5.4

- Fixed handling of search phrase with uppercase characters

- Prioritized search results that match the case

## 0.5.3

- Cleaned up code

## 0.5.2

- Cleaned up code

## 0.5.1

- Cleaned up code and debug info print a bit

## 0.5.0

- Removed tags handling

- Added stdin piping support

## 0.4.1

- Tuning content search result scoring

## 0.4.0

- Improved content search result scoring

- Added limit on content search results to consider to avoid
  slowdown

- General optimizations

## 0.3.3

- Fixed crash due to not resetting content search result selection
  when changing document selection

## 0.3.2

- Fixed internal line numbering, but displayed line numbering
  still begins at 1

## 0.3.1

- Adjusted line number to begin at 1

## 0.3.0

- Adjusted colouring

## 0.2.9

- Fixed word position tracking in content indexing

## 0.2.8

- Fixed content indexing

## 0.2.7

- Changed to vim style highlighting for content search results

- Color adjustments in general

## 0.2.6

- Added single file UI mode

- Added support for specifying multiple files in command line

## 0.2.5

- Added limit to word search range of each step in content search

    - This speeds up usual search while giving good enough results,
      and prevents search from becoming very slow in large documents

## 0.2.4

- Adjusted displayed document list size

- Updated style of document list view

## 0.2.3

- Added sanitization to file view text

- Docfd now accepts file being passed as argument

## 0.2.2

- Fixed tokenization of user provided content search input

- Fixed content indexing to not include spaces

## 0.2.1

- Optimized file discovery procedure

- Added `--max-depth` option to limit scanning depth

- Added content search results view

- Adjusted tokenization procedure

## 0.2.0

- Switched to interactive TUI

- Renamed to Docfd

## 0.1.6

- Optimized parsing code slightly

## 0.1.5

- Adjusted parsing code slightly

## 0.1.4

- Adjusted `--tags` and `--ltags` output slightly

## 0.1.3

- Upgraded `--tags` and `--ltags` output to be more human readable
  when output is terminal

    - Changed behavior to output each tag in individual line when output
      is not terminal

## 0.1.2

- Fixed output text when output is not terminal

## 0.1.1

- Fixed checking of whether output is terminal

## 0.1.0

- Flipped output positions of file path and tags

## 0.0.9

- Notefd now adds color to title and matching tags if output is terminal

- Improved fuzzy search index building

## 0.0.8

- Code cleanup

## 0.0.7

- Made file recognition more lenient

- Added support for alternative tag section syntax

    - `| ... |`
    - `@ ... @`

## 0.0.6

- Fixed Notefd to only handle consecutive tag sections

## 0.0.5

- Added `--tags` and `--ltags` flags

- Adjusted parsing to allow multiple tag sections

## 0.0.4

- Fixed tag extraction

## 0.0.3

- Made header extraction more robust to files with very long lines

## 0.0.2

- Added `-s` for case-insensitive substring tag match

- Renamed `-p` to `-e` for exact tag match

## 0.0.1

- Base version
