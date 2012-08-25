all: compile

compile: asciidoc_txt asciidoc_html

asciidoc_txt:
	./cabal-dev/bin/pandoc -f markdown -t asciidoc data-traceability.markdown > \
    data-traceability.txt

asciidoc_html: asciidoc_html
	asciidoc data-traceability.txt

clean:
	rm data-traceability.txt
	rm data-traceability.html
