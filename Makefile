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

.PHONY: profile
profile :
	OCAMLPARAM='_,ccopt=-static' dune build --release profile/main.exe

.PHONY: format
format :
	$(OCPINDENT)

.PHONY : clean
clean:
	dune clean
