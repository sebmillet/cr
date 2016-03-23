all: cryptographie-pratique.html

cryptographie-pratique.html: cryptographie-pratique.adoc
	asciidoctor cryptographie-pratique.adoc
	sed -i '/fonts.googleapis.com/d' cryptographie-pratique.html

