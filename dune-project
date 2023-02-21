(lang dune 3.4)

(name notefd)

(generate_opam_files true)

(source
 (github darrenldl/notefd))

(authors "Darren Ldl")

(maintainers "Darren Ldl")

(license MIT)

(package
 (name notefd)
 (synopsis "Tag your notes with a simple header")
 (description "")
 (documentation https://github.com/darrenldl/notefd)
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
  ("note"
   ))
 )
