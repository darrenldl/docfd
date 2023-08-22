# Changelog

## 1.2.0

- Removed UI components for search cancellation

- Added real time refresh of search

- Added code to open selected text file at selected search result for:

    - nano
    - neovim/vim/vi
    - helix
    - kakoune
    - emacs
    - micro

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
