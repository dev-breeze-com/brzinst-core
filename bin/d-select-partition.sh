#!/bin/bash
#
# GNU GENERAL PUBLIC LICENSE Version 3
#
# Copyright 2015 Pierre Innocent, Tsert Inc. All rights reserved.
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

OPTION="$1"
SELECTED_DRIVE="$2"
RELEASE="`cat $TMP/selected-release 2> /dev/null`"

list_partitions() {

	local outfile="$1"
	local boot_drive="$2"

	if [ "$OPTION" = "boot" ]; then
		echo "--menu \"\nThe \Z1first\Zn partition on \Z1/boot\Zn is the usual choice.\n\" 12 65 4 \\" 1> $outfile
	else
		echo "--menu \"\nSelect a partition !\n\" 10 55 4 \\" 1> $outfile
	fi

	lsblk -n -l -o 'kname,size,type,model' $boot_drive 1> $TMP/lsblk.log
	sed -i "s/[ ][ ]*/ /g" $TMP/lsblk.log

	while read line; do

		kname="`echo "$line" | cut -f 1 -d ' '`"
		size="`echo "$line" | cut -f 2 -d ' '`"
		type="`echo "$line" | cut -f 3 -d ' '`"

		if [ "$type" != "part" ]; then
			continue
		fi

		model="`echo "$line" | sed 's/^.*part //g'`"

#		size="`echo "$size" | sed 's/.*[:] //g'`"
#		size=$(( size / 1000 * 1024 / 1000000000 ))

		mounted="`mount | grep -F "$kname" | cut -f 3 -d ' '`"

		if [ "$mounted" = "" ]; then
			echo "\"/dev/${kname}\" \"[ ${size} (available) ]\" \\" >> $outfile
		else
			echo "\"/dev/${kname}\" \"[ ${size} ($mounted) ]\" \\" >> $outfile
		fi
	done < $TMP/lsblk.log

	return 0
}

# Main starts here ...
list_partitions $TMP/all-partitions $SELECTED_DRIVE

if [ "$?" = 0 ]; then

	dialog --colors \
		--backtitle "Breeze::OS $RELEASE Installer" \
		--title "Breeze::OS Setup -- Partition Selection" \
		--file $TMP/all-partitions 2> $TMP/selected-partition

	exit $?
fi

exit 0

# end Breeze::OS setup script
