# Docfd
TUI multiline fuzzy document finder

Think interactive grep for text files, PDFs, DOCXs, etc,
but word/token based instead of regex and line based,
so you can search across lines easily.

Docfd aims to provide good UX via integration with common text editors
and PDF viewers,
so you can jump directly to a search result with a single key press.

---

![](demo-vhs-gifs/repo.gif)

## Features

- Multithreaded indexing and searching

- Multiline fuzzy search of multiple files

- Content view pane that shows the snippet surrounding the search result selected

- Text editor and PDF viewer integration

- Editable command history - rewrite/plan your actions in text editor

- Search scope narrowing - limit scope of next search based on current search results

- Clipboard integration

## Installation

Statically linked binaries for Linux and macOS are available via
[GitHub releases](https://github.com/darrenldl/docfd/releases).

Docfd is also packaged on the following platforms for Linux:

- [opam](https://ocaml.org/p/docfd/latest)
- [AUR](https://aur.archlinux.org/packages/docfd-bin) (as `docfd-bin`) by [kseistrup](https://github.com/kseistrup)
- Nix (as `docfd`) by [chewblacka](https://github.com/chewblacka)

The only way to use Docfd on Windows right now is via WSL.

**Notes for packagers**: Outside of the OCaml toolchain for building (if you are
packaging from source), Docfd also requires the following
external tools at run time for full functionality:

- `pdftotext` from `poppler-utils` for PDF support
- `pandoc` for support of `.epub`, `.odt`, `.docx`, `.fb2`, `.ipynb`, `.html`, and `.htm` files
- `fzf` for file selection menu
- `wl-clibpard` for clipboard support on Wayland
- `xclip` for clipboard support on X11

## Basic usage

The typical usage of Docfd is to either `cd` into the directory of interest
and launch `docfd` directly, or specify the paths as arguments:

```
docfd [PATH]...
```

The list of paths can contain directories.
Each directory in the list is scanned recursively for
files with the following extensions by default:

- For multiline search mode:
    - `.txt`,
      `.md`,
      `.pdf`,
      `.epub`,
      `.odt`,
      `.docx`,
      `.fb2`,
      `.ipynb`,
      `.html`,
      `.htm`
- For single line search mode:
    - `.log`,
      `.csv`,
      `.tsv`

You can change the file extensions to use via
`--exts` and `--single-line-exts`,
or add onto the list of extensions via
`--add-exts` and `--single-line-add-exts`.

If the list `PATH`s is empty,
then Docfd defaults to scanning the
current directory `.`
unless any of the following is used:
`--paths-from`, `--glob`, `--single-line-glob`.

## Documentation

See [GitHub Wiki](https://github.com/darrenldl/docfd/wiki) for usage guides,
examples, and technical information.

## Limitations

- File auto-reloading is not supported for PDF files,
  as PDF viewers are invoked in the background via shell.
  It is possible to support this properly
  in the ways listed below, but requires
  a lot of engineering for potentially very little gain:

    - Docfd waits for PDF viewer to terminate fully
      before resuming, but this
      prohibits viewing multiple search results
      simultaneously in different PDF viewer instances.

    - Docfd manages the launched PDF viewers completely,
      but these viewers are closed when Docfd terminates.

    - Docfd invokes the PDF viewers via shell
      so they stay open when Docfd terminates.
      Docfd instead periodically checks if they are still running
      via the PDF viewers' process IDs,
      but this requires handling forks.

    - Outside of tracking whether the PDF viewer instances
      interacting with the files are still running,
      Docfd also needs to set up file update handling
      either via `inotify` or via checking
      file modification times periodically.

## Acknowledgement

- Big thanks to [@lunacookies](https://github.com/lunacookies) and
  [@jthvai](https://github.com/jthvai) for the many UI/UX discussions and
  suggestions
- Demo gifs and some screenshots are made using [vhs](https://github.com/charmbracelet/vhs).
- [ripgrep-all](https://github.com/phiresky/ripgrep-all) was used as reference
  for text extraction software choices
- [Marc Coquand](https://mccd.space) (author of
  [Stitch](https://git.mccd.space/pub/stitch/)) for discussions and inspiration
  of results narrowing functionality
- Part of the search syntax was copied from [fzf](https://github.com/junegunn/fzf)
