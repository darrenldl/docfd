FROM ocaml/opam
USER root
RUN opam install dune ocp-indent containers fmt fileutils cmdliner timere timere-parse otoml dune-build-info
RUN opam install mparser utop
