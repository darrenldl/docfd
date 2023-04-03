# Advanced usage

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
