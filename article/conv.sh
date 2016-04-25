#!/bin/sh

if [ -z "$2" -o -n "$3" ]; then
	echo "Usage:"
	echo "  ./conv.sh INPUTFILE OUTPUTFILE"
	echo "Convert INPUTFILE from asciidoctor to markdown then to HTML"
	exit
fi

O="$1"
OB=`echo $O | sed 's/\.[^.]\+$//'`
T1=${OB}.md
T2="$2"

echo "$O => $T1"
./conv.pl "$O" "$T1"

echo "$T1 => $T2"
pandoc -s -f markdown "$T1" -t html > "$T2"

