FROM docker.io/ocaml/opam:alpine-ocaml-4.14
USER root
RUN opam init --disable-sandboxing
RUN opam install dune containers fmt
RUN opam install utop ocp-indent
RUN opam install cmdliner
RUN opam install angstrom
RUN opam install spelll
RUN opam install notty
