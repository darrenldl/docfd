# Docfd
TUI fuzzy document finder

## Installation

Statically linked binaries are available via
[GitHub releases](https://github.com/darrenldl/docfd/releases)

## Usage

#### Read from stdin

```
command | docfd
```

Docfd operates in **Single file mode**
when input is stdin.

#### Read from files

```
docfd [PATH...]
```

The list of paths can contain directories.
Each directory in the list is scanned recursively for
files with one of the following extensions:

- `.md`
- `.txt`

If the list of paths is empty,
then Docfd defaults to scanning the
current directory `.`.

If exactly one file is specified
in the list of paths, then Docfd operates
in **Single file mode**.
Otherwise, Docfd operates in **Normal mode**.

## Normal mode

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
- Clear search phrase
  - `x`
- Exit Docfd
  - `q` or `Ctrl+c`

`Content Search` mode

- Content search field is active in this mode
- `Enter` to confirm search phrase and exit search mode

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

