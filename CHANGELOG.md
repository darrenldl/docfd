# Changelog

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
