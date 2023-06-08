SRCFILES = bin/*.ml bin/*.mli lib/*.ml lib/*.mli

OCPINDENT = ocp-indent \
	--inplace \
	$(SRCFILES)

.PHONY: all
all :
	./update-version-string.sh
	dune build @all

.PHONY: release-static
release-static :
	./update-version-string.sh
	OCAMLPARAM='_,ccopt=-static' dune build --release src/docfd.exe
	mkdir -p statically-linked
	cp _build/default/src/docfd.exe statically-linked/docfd

.PHONY: format
format :
	$(OCPINDENT)

.PHONY : clean
clean:
	dune clean
