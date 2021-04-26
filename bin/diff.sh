#!/bin/sh

ls $1/d-*sh 1> /tmp/filelist

prefix="$2"

if [ "$prefix" = "" ]; then
	prefix="."
fi

while read f; do
	if [ -f "$f" ]; then
		echo "============================================================"
		echo "Processing $f ..."
		diff -wEBb $f $prefix/install/bin/`basename $f`
	fi
done < /tmp/filelist

exit 0

