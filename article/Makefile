# Makefile to process cryptographie-pratique.adoc and associated files

VERSION = $(shell cat "cryptographie-pratique.adoc" | egrep "^:revnumber:" | sed 's/^:revnumber:\s*//')
INCLUDES = $(shell egrep include "cryptographie-pratique.adoc" | sed 's/^.*:://; s/\[\]$\//')
U = $(shell whoami)

all: cryptographie-pratique.html

nodatauri: cryptographie-pratique-small.html

cryptographie-pratique.html: cryptographie-pratique.adoc
	asciidoctor -a data-uri $< -o $@
	sed -i '/fonts.googleapis.com/d' $@

cryptographie-pratique-small.html: cryptographie-pratique.adoc
	asciidoctor $< -o $@
	sed -i '/fonts.googleapis.com/d' $@

pdf: cryptographie-pratique.pdf

cryptographie-pratique.pdf: cryptographie-pratique.adoc
	sudo asciidoctor-pdf $<
	sudo chown $(U): $@

altpdf: cryptographie-pratique.adoc
	asciidoc -b docbook cryptographie-pratique.adoc
	xsltproc --stringparam paper.type A4 /usr/share/xml/docbook/stylesheet/docbook-xsl/fo/docbook.xsl \
		cryptographie-pratique.xml > cryptographie-pratique.fo
	fop -fo cryptographie-pratique.fo -pdf cryptographie-pratique.pdf

dist:
	tar -cvf "cryptographie-pratique-$(VERSION).tar" cryptographie-pratique.adoc Makefile check-images.sh \
		images $(INCLUDES)
	gzip -9 "cryptographie-pratique-$(VERSION).tar"

distclean:
	rm -f "cryptographie-pratique-$(VERSION).tar.gz"

check:
	./check-images.sh

clean:
	rm -f tmp-dir.txt
	rm -f tmp-file.txt
	rm -f cryptographie-pratique.fo
	rm -f cryptographie-pratique.xml

mrproper:
	$(MAKE) clean
	rm -f cryptographie-pratique.html
	rm -f cryptographie-pratique-small.html
	rm -f cryptographie-pratique.pdf

