(lang dune 3.4)

(name docfd)

(generate_opam_files true)

(source
 (github darrenldl/docfd))

(authors "Darren Ldl")

(maintainers "Darren Ldl")

(license MIT)

(package
 (name docfd)
 (synopsis "TUI fuzzy document finder")
 (description "")
 (documentation https://github.com/darrenldl/docfd)
 (depends
   (ocaml (>= "5.0"))
   dune
   (fmt (>= "0.9.0"))
   (angstrom (>= "0.15.0"))
   (containers (>= "3.6"))
   oseq
   spelll
   notty
   nottui
   (lwd (>= "0.2"))
   (cmdliner (>= "1.1.0"))
   (eio (>= "0.9"))
   (domainslib (>= "0.5.0"))
   kcas_data
   )
 (tags
  ("fuzzy" "document" "finder"
   ))
 )
