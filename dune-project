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
 (description "")
 (documentation https://github.com/darrenldl/docfd)
 (version 1.10.0)
 (depends
   (ocaml (>= "5.1"))
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
   (eio (>= "0.10"))
   (domainslib (>= "0.5.0"))
   digestif
   yojson
   eio_main
   containers-data
   (timedesc (>= "2.0.0"))
   )
 (tags
  ("fuzzy" "document" "finder"
   ))
 )
