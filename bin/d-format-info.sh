#!/bin/bash
#
# GNU GENERAL PUBLIC LICENSE Version 3
#
# Copyright 2015 Pierre Innocent, Tsert Inc., All Rights Reserved
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
. d-dirpaths.sh

# Main starts here ...
DEVICE="$1"

if ! is_valid_device "$DEVICE" ; then
	echo "INSTALLER: FAILURE L_NO_DRIVE_SELECTED"
	exit 1
fi

DRIVE_ID="$(basename $1)"

SELECTED="$(cat $TMP/selected-drive 2> /dev/null)"

if [ -z "$SELECTED" -o "$SELECTED" != "$DEVICE" ]; then
	echo "INSTALLER: FAILURE L_SCRIPT_MISMATCH_ON_DEVICE"
	exit 1
fi

SELECTED="$(extract_value scheme-${DRIVE_ID} 'device')"

if [ -z "$SELECTED" -o "$SELECTED" != "$DEVICE" ]; then
	echo "INSTALLER: FAILURE L_SCRIPT_MISMATCH_ON_DEVICE"
	exit 1
fi

unlink $TMP/${DRIVE_ID}.csv 2> /dev/null
touch $TMP/${DRIVE_ID}.csv 2> /dev/null

CRYPTO="$(extract_value crypto-${DRIVE_ID} 'type')"

while read line; do

	if [ "$CRYPTO" = "luks" ]; then
		if echo "$line" | grep -qF ',/boot,' ; then
			echo "$line" | \
				sed -re 's/,(format|create)/,format/g' >> $TMP/${DRIVE_ID}.csv
		elif echo "$line" | grep -qE -v ',(extended|/none|/boot),' ; then
			echo "$line" | \
				sed -re 's/,(format|create)/,crypt/g' >> $TMP/${DRIVE_ID}.csv
		else
			echo "$line" >> $TMP/${DRIVE_ID}.csv
		fi
	elif echo "$line" | grep -qE -v ',(extended|/none),' ; then
		echo "$line" | \
			sed -re 's/,(format|create)/,format/g' >> $TMP/${DRIVE_ID}.csv
	else
		echo "$line" >> $TMP/${DRIVE_ID}.csv
	fi
done < $TMP/partitions-${DRIVE_ID}.csv

if [ -s $TMP/${DRIVE_ID}.csv ]; then
	cp -f $TMP/${DRIVE_ID}.csv $TMP/partitions-${DRIVE_ID}.csv
	cat $TMP/${DRIVE_ID}.csv
	exit 0
fi

exit 1

# end Breeze::OS setup script
