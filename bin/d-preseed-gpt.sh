#!/bin/bash
#
# Copyright 2013 Pierre Innocent, Tsert Inc., All Rights Reserved
#
# Redistribution and use of this script, with or without modification, is 
# permitted provided that the following conditions are met:
#
# 1. Redistributions of this script must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
#
#  THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR IMPLIED
#  WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF 
#  MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO
#  EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, 
#  SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
#  PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
#  OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, 
#  WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR 
#  OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF 
#  ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#

# Initialize folder paths
. d-dirpaths.sh $DISTRO

unlink $TMP/partman-recipe 2> /dev/null
touch $TMP/partman-recipe

IDX=1
COUNT=1
PRIO=30
BOOT=""

cat $TMP/selected-scheme | while read line; do
	COUNT=$(( $COUNT + 1 ))
done

cat $TMP/selected-scheme | while read line; do

	DEVICE="$(echo "$line" | cut -f 1 -d ':')"
	MTPT="$(echo "$line" | cut -f 2 -d ':')"
	SIZE="$(echo "$line" | cut -f 3 -d ':')"
	FSTYPE="$(echo "$line" | cut -f 4 -d ':')"

	if test $IDX -lt $COUNT; then
		MAXSIZE="$SIZE"
	else
		MAXSIZE="1000000000"
	fi

	if [ "$MTPT" = "/none" ]; then

		echo "$SIZE 30 $SIZE $FSTYPE $defaultignore{ } method{ } format{ } . \\" >> $TMP/partman-recipe

	elif [ "$MTPT" = "/efi" -o "$MTPT" = "/boot/efi" ]; then

		PRIO=$(( $PRIO + 5 ))

		echo "$SIZE $PRIO $MAXSIZE vfat $primary{ } method{ format } format{ } \\" >> $TMP/partman-recipe

		echo " use_filesystem{ } filesystem{ vfat } mountpoint{ $MTPT } $bootable{ } . \\" >> $TMP/partman-recipe

	elif [ "$MTPT" = "/swap" ]; then

		BOOT="$MTPT"
		PRIO=$(( $PRIO + 5 ))

		echo "$SIZE $PRIO $SIZE swap $defaultignore{ } method{ swap } format{ } . \\" >> $TMP/partman-recipe

#	elif [ "$MTPT" = "/linux" -o "$MTPT" = "/linux-raid" ]; then
	else
		PRIO=$(( $PRIO + 5 ))

		if [ "$ROOT_MTPT" = "" ]; then
			ROOT_MTPT="/"
			MTPT="/"
		fi

		echo "$SIZE $PRIO $MAXSIZE $FSTYPE $primary{ } method{ format } format{ } \\" >> $TMP/partman-recipe

		if [ "$MTPT" = "/" -a "$BOOT" = "" ]; then
			echo " use_filesystem{ } filesystem{ $FSTYPE } mountpoint{ $MTPT } $bootable{ } . \\" >> $TMP/partman-recipe
		else
			echo " use_filesystem{ } filesystem{ $FSTYPE } mountpoint{ $MTPT } . \\" >> $TMP/partman-recipe
		fi
	fi

	IDX=$(( $IDX + 1 ))
done

echo "" >> $TMP/partman-recipe

exit "$?"

# end Breeze::OS script

