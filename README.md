# Docfd
TUI fuzzy document finder

## Installation

Statically linked binaries are available via
[GitHub releases](https://github.com/darrenldl/docfd/releases)

## Normal mode

Docfd scans for files recursively (defaults to `.`) with the following extensions:

- `.md`
- `.txt`

and builds an index of the "document" content.

Searching `is left` in repo root:
![](screenshots/main0.png)

Searching `[github]` in repo root:
![](screenshots/main1.png)

The default TUI is divided into four sections:
- Left is the list of documents which satisfy the search constraints
- Top right is the preview of the document
- Bottom right is the ranked content search result list
- Bottom is the search interface

### Controls

Docfd operates in modes, the initial mode is `Navigation` mode.

`Navigation` mode
- Scroll down the document list
  - `j` or down arrow
  - Scroll down with mouse wheel when hovering above the area
- Scroll up the document list
  - `k` or up arrow
  - Scroll up with mouse wheel when hovering above the area
- Scroll down the content search result list
  - `Shift`+`j` or `Shift`+Down arrow
  - Scroll down with mouse wheel when hovering above the area
- Scroll up the document list
  - `Shift`+`k` or `Shift`+Up arrow
  - Scroll up with mouse wheel when hovering above the area
- Open document
  - `Enter`
    - Docfd tries to use `$VISUAL` first, if that fails then Docfd tries `$EDITOR`
- Switch to `Content Search` mode
  - `/`
- Exit Docfd
  - `q` or `Ctrl+c`

`Content Search` mode

- Content search field is active in this mode
- `Enter` to confirm search constraints and exit search mode

## Single file mode

If the specified path to Docfd is not a directory, then single file mode
is used.

Searching `is left` in repo root:
![](screenshots/single-file0.png)

Searching `[github]` in repo root:
![](screenshots/single-file1.png)

In this mode, the TUI is divided into only two sections:
- Top is ranked content search result list
- Bottom is the search interface

The controls are also simplified:
- `j`, `k`, Up arrow and Down arrow can now be used to scroll the content search result
  list without `Shift`.

## Advanced usage

Docfd recognizes "note" files, which can contain tags.
A file is classified as a note if the name contains "note" or "notes" after splitting on '.', e.g.
`meeting.notes.md`, `timetable.note.txt`, `note.txt`.

If any such file is detected, then tag related UI components become active.

A note is split into three sections:
- title
- tags
- content

Title is simply all text before the tag section (if present).

Tags are specified in `[]`, `||`, or `@@` as space separated list of words.
Tags cannot contain spaces or the delimiter chosen for the section.
Tag section must be specified within a single line.
Multiple consecutive tag sections can be specified, however.

The remainder text is considered as content.

An example header reads as follows:
```
Meeting YYYY-MM-DD
[ tag0 tag1 tag2 ... ]
```

The remainder of the file is considered content, and is indexed
in the same way as a document.

### Tag search

The following types of tag matches are available:

- `-e` [E]xact tag match
- `-f` [F]uzzy case-insensitive tag match
- `-i` Case-[i]nsensitive full tag match
- `-s` Case-insensitive [s]ubstring tag match

All search constraints are chained together by "and".

### List tags

- `--tags` List all tags used
- `--ltags` List all tags used in lowercase

## Other header structure

### Multiline title
```
Meeting YYYY-MM-DD
About topic ABC
[ tag0 tag1 tag2 ... ]
...
```

The final title computed by Docfd is simply all title lines
concatenated using ` `, i.e. `Meeting YYYY-MM-DD About topic ABC`.

### Missing tag section
```
Meeting YYYY-MM-DD
About topic ABC
...
```

The first line is used as the final title.

### Multiple consecutive tag sections
```
Meeting YYYY-MM-DD
About topic ABC
[ tag0 tag1 tag2 ... ]
[ tagA ]
| tagB ... |
...
```

The final set of tags is the union of all specified tags.
