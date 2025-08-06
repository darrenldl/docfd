# Changelog

## 12.0.0 (future release)

#### Changes since 12.0.0-alpha.11

#### Highlights of changes since 11.0.1

- Replaced filter glob with a more powerful filter language, with
  autocomplete in filter field (12.0.0-alpha.1, 12.0.0-alpha.2,
  12.0.0-alpha.5, 12.0.0-alpha.6, 12.0.0-alpha.10, 12.0.0-alpha.11)

- Added content view pane scrolling (12.0.0-alpha.5, 12.0.0-alpha.8)

    - Controlled by `-`/`=`

- Added "save script" and "load script" functionality to make it
  actually viable to reuse Docfd commands (12.0.0-alpha.8,
  12.0.0-alpha.9)

- SQL query optimizations for prefix and exact search terms
  (12.0.0-alpha.3)

- Key binding info grid improvements (12.0.0-alpha.4)

    - Added more key bindings

    - Packed columns more tightly

- Added `--paths-from -` to accept list of paths from stdin
  (12.0.0-alpha.3)

- Added WSL clipboard integration (12.0.0-alpha.4)

- Added more marking key bindings (12.0.0-alpha.4)

    - `mark listed` (`ml`) marks all currently listed documents
    - `unmark listed` (`Ml`) unmarks all currently listed documents

- `--open-with` placeholder handling fixes (12.0.0-alpha.4)

    - Using `{page_num}` and `{line_num}` crashes in 11.0.1
      when there are no search results

- Added sorting to document list (12.0.0-alpha.11)

- Added additional attributes to document list entry (12.0.0-alpha.11)

    - Path date

- Reworked the internal architecture of document store snapshots
  storage and management, which makes the overall interaction
  between UI and core code much more robust (12.0.0-alpha.11)

## 12.0.0-alpha.11

- Removed disabling of drop mode key binding `d` when searching or filtering is ongoing

- Fixed content view pane offset not resetting when mouse is used to scroll search result list

- Fixed content view pane staying small while scrolling up when the search result is close to the bottom of the file

- Swapped all mutexes to Eio mutexes to hopefully remove the very random freezes that occur quite rarely

    - They feel like deadlocks due to mixing Eio mutexes
      (which block fiber) and stdlib mutexes (which block an entire domain)

- Added sorting to document list

    - `s` for sort ascending mode and `Shift+S` for sort descending mode
    - Under the sort modes, the sort by types are as follows:
        - `p` sort by path
        - `d` sort by path date
        - `s` sort by score
        - `m` sort by modification time

- Added `yyyymmdd` path date extraction

- Added `mod-date` to filter language

- Added additional attributes to document list entry

    - Path date

- Reworked the internal architecture of document store snapshots storage and management

    - Snapshots are now centrally managed by `Document_store_manager`

    - This makes the overall interaction between UI and core code
      much more robust, and eliminates random workarounds used to
      deal with UI and data synchronization, which have
      been riddled with random minor bugs

## 12.0.0-alpha.10

- Added basic autocomplete to filter field

- Improved script save autocomplete to insert longest common prefix

- Fixed script save autocomplete so it no longer erases original text when no recommendations are available

## 12.0.0-alpha.9

- Disabled `Tab` handling in edit fields to reduce friction in UX

- Added `nano`-style autocomplete to save commands field with listing of existing scripts

## 12.0.0-alpha.8

- Changed `--commands-from` to `--script`

- Added "save commands as script" and "load script" functionality to streamline reusing of commands

- Improved content view pane scrolling control

    - The internal counter no longer scrolls past the limit

## 12.0.0-alpha.7

- Fixed interactive use of `--commands-from`

- Added `mark listed` and `unmark listed` to template command history file help info

## 12.0.0-alpha.6

- Fixed `not` operator parsing

    - Previously `not ext:txt and not ext:md` would be parsed as `not (ext:txt and not ext:md)`, which is not what is typically expected

    - `not` now binds tightly, so `not ext:txt and not ext:md` is parsed as `(not ext:txt) and (not ext:md)`

## 12.0.0-alpha.5

- Added content view pane scrolling

    - Controlled by `-`/`=`

- Removed extraneous marking functionality

    - `mark unlisted`
    - `unmark unlisted`

- Added `"..."` as a shorthand to `content:"..."` to filter expression

    - For example, `content:keyword AND path-date:>2025-01-01` can be written as `"keyword" AND path-date:>2025-01-01`

    - The quotation is necessary to differentiate between typos
      and actual query, otherwise incorrect input like
      `pathfuzzy:...` would be parsed as content queries instead

## 12.0.0-alpha.4

- Added additional marking functionality

    - `mark listed` (`ml`) marks all currently listed documents
    - `mark unlisted` (`mL`) marks all currently unlisted documents
    - `unmark listed` (`Ml`) unmarks all currently listed documents
    - `unmark unlisted` (`ML`) unmarks all currently unlisted documents

- `unmark all` is moved to key binding `Ma`

- Reworked key binding info grid to pack columns more tightly

- Added WSL clipboard integration

- Minor fix in command history file template help text

- Added `Tab` key to key binding info grid

- Added key binding info about scrolling through document list and search result list

- Minor fix for `{line_num}` placeholder handling in `--open-with`

    - This should always be usable for text files but previously
      Docfd crashes when `{line_num}` is specified in `--open-with` 
      and user opens a text file when no search has been made

    - This is fixed by defaulting `{line_num}` to 1 when
      there are no search results present

- Minor fix for `{page_num}` and `{search_word}` placeholders handling in `--open-with`

    - This should always be usable for PDF files but previously
      Docfd crashes when `{page_num}` or `{search_word}` is specified in `--open-with`
      and user opens a PDF file when no search has been made

    - This is fixed by defaulting `{page_num}` to 1
      and `{search_word}` to empty string when
      there are no search results present

## 12.0.0-alpha.3

- **Users are advised to recreate the index DB**

- Adjusted SQL indices and swapped to specialized SQL queries
  for exact and prefix search terms, e.g. `'hello`, `^worl`

    - Handling of these terms is now 10-20% faster depending on the document

- Fixed command history recomputation not using the reloaded version
  of document store

    - This issue is most noticeable when you've edited a text file after hitting `Enter` in Docfd (after which Docfd reloads the file for you),
      and you hit `h` to modify the command history

    - The replaying of the command history would use the old copy of the file instead of the new edited version of the text file

- Added missing SQL transaction in code path for reloading a single document

    - Previously, reloading a single document was incredibly slow, which was very noticeable if you edited a text file
      after hitting `Enter` in Docfd, unless the text file was very small

- Updated `--paths-from` argument handling

    - Added `--paths-from -` for accepting list of paths from stdin

    - Adjusted to accept comma separated list of paths, e.g. `--paths-from path-list0.txt,path-list1.txt`

- Removed builtin piping to fzf triggered by providing `?` as a file path, e.g. `docfd ?`

    - The `--paths-from -` handling makes this obsolete and a lot less flexible by comparison

- Fixed interaction between search and filter

    - Previously, starting a search would incorrectly cancel an ongoing filtering operation.
      Now only a new filtering operation can cancel an ongoing filtering operation.
      A new search still cancels an ongoing search.

    - Starting a new filtering operation also still cancels any ongoing search. This is fine since the search results
      are refreshed after the filtering has been completed.

        - The refreshing of the search results also means that the following sequences of events are still handled correctly,
          namely they still arrive at the same normal form of the document store:

            - Example 1:

                - (0) Filter `f_exp0` (filtering is canceled by step (2), but the updating of filter expression is never canceled)
                - (1) Search `s_exp0` (search is canceled by step (2), but the updating of search expression is never canceled)
                - (2) Filter `f_exp1` (refreshes search results using `s_exp0`)

            - Example 2:

                - (0) Search `s_exp0` (search is canceled by step (1), but updating of search expression is never canceled)
                - (1) Filter `f_exp0` (this stage is canceled by step (2),
                    either during the filtering or during the
                    refreshing of search results, but the updating
                    of filter expression is never canceled)
                - (2) Filter `f_exp1` (refreshes search results using `s_exp0`)

- Renaming query expression/language to filter expression/language in help text and documentation

- Added a separate loading indicator for filter field

- Fixed concurrency issue where an update of document store may cause the
  filter field and search field in UI to be out of sync with the actual
  filter expression and search expression used by the underlying document store

    - Suppose we have the following sequence of events:

        - (0) Document store `store0` carries filter expression
            `f_exp0` and search expression `s_exp0`, which we write
            as pair `(f_exp0, s_exp0)`
        - (1) User initiates filter/search operation by placing `(f_exp1, s_exp1)` into the input fields.

            We name the document store resulting from this filter/search operation as `store1a`,
            which carries `(f_exp1, s_exp1)` when finalized.
        - (2) While filter/search operation is ongoing,
        user drops a set of documents from the
            current document store. Since `store1a` is not
            finalized yet, the current document store is still `store0`, thus the new document store encoding the result of the drop operation, `store1b`, is computed from `store0` instead of `store1a`.

            In other words, both `store1a` and `store1b` share
            `store0` as their parent.
            Note that `store1b` carries `(f_exp0, s_exp0)` as
            inherited from `store0`,
            since a drop operation does not alter the filter expression or search expression.
        - (3) As a drop operation immediately updates the document store
        and cancels ongoing filter/search operation, step (2) canceled the computation of `store1a`, and instead places `store1b` as the current document store.

    - However, this means the input fields are `(f_exp1, s_exp1)`
      while the current document store `store1b` actually carries
      `(f_exp0, s_exp0)`.

      The fix in this update is then to add an
      extra "sync from input fields" step whenever a document store
      is updated. To illustrate, we continue from the above
      sequence of events, where the updated version of Docfd
      carries out the following step missing from previous
      versions.

        - (4) Update input fields to `(f_exp0, s_exp0)`

    - This addresses the mismatch between the underlying document store and the UI input fields.

    - In practice this is very unlikely to occur with human input, as the modes that update document store
      are disabled if document store manager is carrying out any ongoing filtering or search.

      However, since the UI is async, there will be gaps in timing between UI input/feedback and actual updates of values,
      opening up to TOCTOU problems.
      So there is always a chance that a document store update will be requested before the modes are are disabled.

- Made interrupted filter/search operation to not yield a document store at all instead of yielding an empty document store
  to simplify reasoning about filter/search cancellations and UI fields being in sync

## 12.0.0-alpha.2

- Added `path-date` clause to query expression

    - This allows filtering based on date recognized from document path, for example, `path-date:>=2025-01-01 AND path-date:<2025-02-01`
      would allow `/home/user/meeting-notes-2025-01-10.md` to pass through

    - This gives a very lightweight method of attaching date information to any document

    - See [relevant Wiki page](https://github.com/darrenldl/docfd/wiki/Document-filtering) for details

## 12.0.0-alpha.1

- Added a more powerful filter mode that replaces the filter glob mode and "pipe to fzf" feature

    - Filter query mode uses a proper query language that supports file path globbing and file path fuzzy matching among other features

    - This mode uses key binding `f`

- Removed `q` exit key binding to avoid accidental exiting

## 11.0.1

- Added better search cancellation handling, removing massive lags in some scenarios

## 11.0.0

- Minor fix for search scope narrowing logic:

    - Search scope should also be set to empty if the document is not passing the file filter, not just when the search results are empty

    - The old behavior can be confusing when a document passes an old file filter and thus has search results in memory,
      but fail to pass a new file filter,
      yet appears in later searches when file filter is reset

    - It is simpler to make it so if a document is not listed for
      whatever reason, search scope of that document just becomes
      empty during narrowing

- Added missing commands in the list of possible commands in the command history file template

    - `clear search`

    - `clear filter`

- Minor breaking change, filter regex mode should have been called filter glob mode

    - The key binding `fr` is changed to `fg`

- Changed UI text "File path filter" to "File path glob" to be more descriptive

## 10.2.0

- Added `--open-with` to allow customising the command used to open a file based on file extension

    - Example: `--open-with pdf:detached='okular {path}'`

    - Can be specified multiple times

- Added non-interactive use of `--commands-from`

    - Non-interactive use can be triggered by pairing `--commands-from` with `-l`/`--files-with-match`

    - Useful for advanced document management workflow

- Adjustments to search scope narrowing

    - Added `narrow level: 0` for resetting the search scopes of
      all documents back to full

    - Narrowing now no longer drops unlisted document, so the
      previous set of documents remain accessible for later
      searches after resetting the search scopes

- Reworked search into multi-stage pipeline

    - This improves the search speed by around 30%

    - The core search procedure was reworked into an API that
      generates grouped search jobs which can be easily distributed
      to threads.
      This gives a better workload distribution than the current
      multithreading approach.

## 10.1.3

- Minor fixes

    - "Reload document" now removes the document if the document is no longer accessible

    - Docfd now only checks the existence of directly specified files
      at launch, e.g. `file.txt` in `docfd file.txt`. This means
      "reload all documents" now does not error out due to files becoming
      no longer accessible.

## 10.1.2

- Minor fix for "reload all doucments" when fzf was used to pick documents initially, i.e. `docfd [PATH]... ?`, or any variation where `?` appears anywhere in the path list

    - Under this workflow, later "reload all" should use the same selection
      instead of having the user select again in fzf, which is cumbersome

    - Now Docfd correctly reuses the selection when "reload all" is requested,
      if fzf was used initially to pick documents

    - This does technically mean the functionality is now less flexible,
      since if `docfd ?` alike is used, "reload all" no longer discovers
      new files

    - But the convenience from reusing the selection outweighs the flexibility
      in practically all use cases from author's experience

## 10.1.1

- Minor fix for "filter files via fzf" functionality

    - Previously, if instead of making a selection,
      the user quits fzf (e.g. pressing `Ctrl`+`C`, `Ctrl`+`Q`),
      Docfd also closes with it

    - Now Docfd just discards the interaction and goes back to the main UI

## 10.1.0

- Added back index DB entry pruning

    - Previously missing after swapping to SQLite DB

    - Also renamed `--cache-soft-limit` to `--cache-limit` to
      reflect the new pruning logic

    - Fixes [issue #12](https://github.com/darrenldl/docfd/issues/12)

- Swapped to a better `doc_id` allocation strategy to minimise
  `doc_id` size in DB

- Added blinking when drop mode is disabled but `d` is pressed

## 10.0.0

- Reworked document indexing into a multi-stage pipeline

    - This significantly improves the indexing throughput by allowing
      I/O tasks and computational tasks to run concurrently

    - See [issue #11](https://github.com/darrenldl/docfd/issues/11)

- **Breaking** changes in index DB design - index DBs made by previous version
  of Docfd are not compatible

    - Optimized DB design, on average the index DB is roughly 60% smaller
      compared to Docfd 9.0.0 index DB

    - See [issue #11](https://github.com/darrenldl/docfd/issues/11)

- Added functionality to filter files via fzf

    - This is grouped under filter mode. The previous filter mode
      is renamed to filter regex mode.

    - `f` enters filter mode

        - `f` again activates filter files via fzf functionality

        - `r` activates the filter regex mode, which was previously
          just called the filter mode

- Fixed incomplete search results when file path filter field is updated while
  search is ongoing

    - Updating file path filter always cancels the current search (if there is one)
      and start a new search after the filter is in place

    - Previously, documents with partial search results due to cancellation
      are kept

    - Docfd now discards said documents, forcing the new search to complete the
      search results of these documents

- Removed `--no-cache` flag

    - Previously was unused completey

    - It is difficult to share an in-memory SQlite DB
      between threads, so discarding this flag entirely

    - See [issue #11](https://github.com/darrenldl/docfd/issues/11)

- Swapped to using proper unicode segmentation for tokenisation

    - This should reduce the index size for Western non-English languages
      significantly

- Added screen split ratios for hiding left or right pane completely

- Minor UI/UX fixes

    - Drop mode is now disabled when search is still ongoing or when either search field or filter field has an error

    - Added missing update of search and filter status when undoing/redoing, or when replaying command history

        - This is most noticeable when the status indicates an error, but undoing does not return it to OK

## 9.0.0

- Swapped over to using SQLite for index

    - Memory usage is much slimmer/stays flat

        - For the sample of 1.4GB worth of PDFs used, after indexing, 9.0.0-rc1 uses
          1.9GB of memory, while 9.0.0-rc2 uses 39MB

    - Search is a bit slower

    - Added token length limit of 500 bytes to accommodate word table limit in index DB

        - This means during indexing, if Docfd encounters a very long token,
          e.g. serial number, long hex string, it will be split into chunks of
          up to 500 bytes

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

- Renamed `drop path` command to just `drop`

- Added drop unselected key binding, and the associated command `drop all except`

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
      from progressing if previous search was still being canceled

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
