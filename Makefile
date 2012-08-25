all: compile

compile: asciidoc_html asciidoc_txt

asciidoc_txt:
	./cabal-dev/bin/pandoc -f markdown -t asciidoc data-traceability.markdown > \
    data-traceability.txt

asciidoc_html: asciidoc_txt
	asciidoc data-traceability.txt

clean:
	rm -f data-traceability.txt
	rm -f data-traceability.html
