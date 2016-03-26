#!/bin/sh

S=cryptographie-pratique.adoc

cat "$S" | sed 's/\]/\]\n/g' | egrep "image:" | sed 's/^.*image::\?//; s/\[.*\]//' | sort
