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
	OCAMLPARAM='_,ccopt=-static' dune build --release bin/docfd.exe
	mkdir -p statically-linked
	cp -f _build/default/bin/docfd.exe statically-linked/docfd

.PHONY: format
format :
	$(OCPINDENT)

.PHONY : clean
clean:
	dune clean
