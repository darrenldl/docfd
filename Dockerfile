FROM docker.io/ocaml/opam:alpine-ocaml-5.1
USER root
RUN opam init --disable-sandboxing
RUN opam install dune containers fmt
RUN opam install utop ocp-indent
RUN opam install cmdliner
RUN opam install angstrom
RUN opam install spelll
RUN opam install notty
RUN opam install oseq
RUN opam install nottui
RUN opam install eio
RUN apk add linux-headers
RUN opam install eio_main
RUN opam install domainslib
RUN opam install kcas_data
RUN apk add poppler-utils
