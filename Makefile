SRCFILES = lib/*.ml lib/*.mli bin/*.ml bin/*.mli profile/*.ml tests/*.ml

OCPINDENT = ocp-indent \
	--inplace \
	$(SRCFILES)

.PHONY: all
all :
	python3 update-version-string.py
	dune build @all

.PHONY: podman-build
podman-build:
	podman build --format docker -t localhost/docfd -f containers/docfd/Containerfile .

.PHONY: podman-build-demo-vhs
podman-build-demo-vhs:
	podman build --format docker -t localhost/docfd-demo-vhs -f containers/demo-vhs/Containerfile .

.PHONY: lock
lock:
	opam-2.2 lock .

.PHONY: release-static
release-static :
	python3 update-version-string.py
	OCAMLPARAM='_,ccopt=-static' dune build --release bin/docfd.exe
	mkdir -p statically-linked
	cp -f _build/default/bin/docfd.exe statically-linked/docfd
	chmod 755 statically-linked/docfd

.PHONY: tests
tests :
	# Cleaning and rebuilding here to make sure cram tests actually use a recent binary,
	# since Dune (as of 3.14.0) doesn't trigger rebuild of binary when
	# invoking cram tests, even if the source code has changed.
	make clean
	make
	OCAMLRUNPARAM=b dune exec tests/main.exe --no-buffer --force
	dune build @line-wrapping-tests
	dune build @misc-behavior-tests
	dune build @file-collecting-tests

.PHONY: demo-vhs
demo-vhs :
	for file in demo-vhs-tapes/*; do ./demo-vhs.sh $$file; done
	rm dummy.gif

.PHONY: profile
profile :
	OCAMLPARAM='_,ccopt=-static' dune build --release profile/main.exe

.PHONY: format
format :
	$(OCPINDENT)

.PHONY : clean
clean:
	dune clean
