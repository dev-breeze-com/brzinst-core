#!/bin/sh

if [[ $1 == "" || $2 == "" ]]; then
	echo "========= YOU MUST SPECIFY 2 FILES or 2 FOLDERS =========="
fi

srcdir=$1
destdir=$2

if [ -d $srcdir ]; then
	/bin/echo "========== Folder " $1 "==========================="
	find $srcdir/$3 1> /tmp/filelist

elif [ -f $srcdir ]; then
	/bin/echo "========== File " $1 "==========================="
	/usr/bin/diff -b $1 $2
	exit 0
fi

while read f; do
	target="`echo $f | sed -e "s/$srcdir/$destdir/g"`"

	if [ -h $f ]; then
		/bin/echo "======= Link file $f ========="
		/usr/bin/diff -b $f $target
	elif [ -x $f ]; then
		/bin/echo "======= Executable file $f ========="
		/usr/bin/diff -b $f $target
	elif [ -f $f ]; then
		/bin/echo "======= Regular file $f ========="
		/usr/bin/diff -b $f $target
	elif [ -d $f ]; then
		/bin/echo "======= Folder $f ========="
		/usr/bin/diff -b $f $target
	elif [ -b $f ]; then
		/bin/echo "======= Block special $f ========="
		/usr/bin/diff -b $f $target
	else
		/bin/echo "ERROR: NOT A REGULAR FILE " $f
	fi
done < /tmp/filelist

