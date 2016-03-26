#!/bin/sh

S=cryptographie-pratique.adoc

VERSION=`cat "$S" | egrep "^:revnumber:" | sed 's/^:revnumber:\s*//'`

echo "Version = $VERSION"

F=cryptographie-pratique-${VERSION}.tar
tar -cvf "$F" cryptographie-pratique.adoc images
gzip -9 "$F"

echo "Created ${F}.gz"

