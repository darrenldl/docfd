(lang dune 3.4)

(name docfd)

(generate_opam_files true)

(source
 (github darrenldl/docfd))

(authors "Darren Li")

(maintainers "Darren Li")

(license MIT)

(package
 (name docfd)
 (synopsis "TUI multiline fuzzy document finder")
 (description "
Think interactive grep for text files, PDFs, DOCXs, etc,
but word/token based instead of regex and line based,
so you can search across lines easily.

Docfd aims to provide good UX via integration with common text editors
and PDF viewers,
so you can jump directly to a search result with a single key press.

Features:

- Multithreaded indexing and searching

- Multiline fuzzy search of multiple files or a single file

- Swap between multi-file view and single file view on the fly

- Content view pane that shows the snippet surrounding the search result selected

- Text editor and PDF viewer integration
              ")
 (documentation https://github.com/darrenldl/docfd)
 (depends
   (ocaml (>= "5.2"))
   dune
   (fmt (>= "0.9.0"))
   (angstrom (>= "0.15.0"))
   (containers (>= "3.12"))
   oseq
   spelll
   notty
   (nottui (= "0.3"))
   lwd
   (cmdliner (>= "1.1.0"))
   (eio (>= "0.14"))
   digestif
   eio_main
   containers-data
   (timedesc (>= "2.0.0"))
   (re (>= "1.11.0"))
   (ppx_deriving (>= "5.0"))
   decompress
   progress
   cbor
   diet
   (alcotest :with-test)
   (qcheck-alcotest :with-test)
   (qcheck :with-test)
   )
 (tags
  ("fuzzy" "document" "finder"
   ))
 )
