#!/bin/sh

asciidoc -b docbook cryptographie-pratique.asc
xsltproc --stringparam paper.type A4 /usr/share/xml/docbook/stylesheet/docbook-xsl/fo/docbook.xsl cryptographie-pratique.xml > cryptographie-pratique.fo
fop -fo cryptographie-pratique.fo -pdf cryptographie-pratique.pdf

