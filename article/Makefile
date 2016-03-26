# Makefile for cryptographie-pratique.adoc

all: cryptographie-pratique.html

allin1: cryptographie-pratique.html
	asciidoctor -a data-uri cryptographie-pratique.adoc
	./clean-html.sh

cryptographie-pratique.html: cryptographie-pratique.adoc
	asciidoctor ${OPT} cryptographie-pratique.adoc
	./clean-html.sh

pdf: cryptographie-pratique.pdf

doctorpdf: cryptographie-pratique.adoc
	sudo asciidoctor-pdf cryptographie-pratique.adoc

dist: cryptographie-pratique.adoc
	./create-source.sh

check:
	./check-images.sh

cryptographie-pratique.pdf: cryptographie-pratique.adoc
	./asctopdf.sh

clean:
	rm -f tmp-dir.txt
	rm -f tmp-file.txt
	rm -f cryptographie-pratique.fo
	rm -f cryptographie-pratique.xml

mrproper:
	make clean
	rm -f cryptographie-pratique.html
	rm -f cryptographie-pratique.pdf

