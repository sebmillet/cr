#!/bin/sh

if [ -z "$2" ]; then
	echo "Usage:"
	echo "  ./img.sh FILE RATIO"
	echo "Example:"
	echo "  ./img.sh img-firefox-6.png 50%"
	exit
fi

S="$1"
R="$2"
D=`echo "$S" | sed 's/\.png$//'`-redim.png

echo "Source:      '$S'"
echo "Destination: '$D'"

cp -i "$S" "$D"

mogrify -resize $R "$D"

