SRCFILES = src/*.ml src/*.mli

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

.PHONY: format
format :
	$(OCPINDENT)

.PHONY : clean
clean:
	dune clean
