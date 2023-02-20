# Notefd
Tag any text file with a simple header

## Installation

Statically linked binaries are available via [GitHub releases](https://github.com/darrenldl/notefd/releases)

## Usage

Notefd scans a given directory recursively (defaults to `.`),
and processes files with names which contain "note" after splitting on '.', e.g.
`meeting.note.md`, `timetable.note`, `note`.

The first 2KiB of the file is extracted, of which the first 10 lines are extracted
to try to parse a header.

A header consists of two main sections: title and tags.

Title is simply all text before the tag section (if present).

Tags are specified in `[]` as space separated list of words.
Tags cannot contain spaces, `[`, or `]`.
Tag section must be specified within a single line.

An example header reads as follows:
```
Meeting YYYY-MM-DD
[ tag0 tag1 tag2 ... ]
```

#### Searching

The following types of tag matches are available:

- `-e` [E]xact tag match
- `-f` [F]uzzy case-insensitive tag match
- `-i` Case-[i]nsensitive full tag match
- `-s` Case-insensitive [s]ubstring tag match

All search constraints are chained together by "and".

#### List tags

- `--tags` List all tags used
- `--ltags` List all tags used in lowercase

#### Output

Notefd lists the headers of all note files which satisfy the search constraints.

Example output:
```
$ notefd
@ ./test.note.md
  > Meeting YYYY-MM-DD
  [ tag0 tag1 ]
```

## Other valid header structure

#### Multiline title
```
Meeting YYYY-MM-DD
About topic ABC
[ tag0 tag1 tag2 ... ]
```

The final title computed by Notefd is simply all title lines
concatenated using ` `, i.e. `Meeting YYYY-MM-DD About topic ABC`.

#### Missing tag section
```
Meeting YYYY-MM-DD
About topic ABC
```

The final title is computed in the same way as above.

#### Multiple tag sections
```
Meeting YYYY-MM-DD
About topic ABC
[ tag0 tag1 tag2 ... ]
[ tagA tagB tagC ... ]
```

The final set of tags is the union of all specified tags.
