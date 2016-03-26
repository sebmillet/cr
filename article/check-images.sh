#!/bin/sh

U=0

if [ "$2" != "" ]; then
	U=1
fi
if [ "$1" = "" ]; then
	U=0
else
	if [ "$1" != "-v" ]; then
		U=1
	fi
fi

if [ $U -eq 1 ]; then
	echo "Usage:"
	echo "  ./check-images.sh [-v]"
	exit
fi

./list-images.sh > tmp-file.txt
ls images | egrep -v "^img\.sh$" > tmp-dir.txt

cmp tmp-file.txt tmp-dir.txt 2>&1 > /dev/null
if [ "$?" -ne "0" ]; then
	echo "** NOT IDENTICAL **"
else
	echo "OK"
fi

if [ "$1" = "-v" ]; then
	sha256sum tmp-file.txt
	sha256sum tmp-dir.txt
fi

