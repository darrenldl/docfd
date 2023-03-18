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
   (ocaml (>= "4.14"))
   ocaml
   dune
   (fmt (>= "0.9.0"))
   (angstrom (>= "0.15.0"))
   (containers (>= "3.6"))
   cmdliner
   )
 (tags
  ("document"
   ))
 )
