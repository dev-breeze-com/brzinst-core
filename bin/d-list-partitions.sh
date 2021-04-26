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

DEVICE="$1"
OUTPUT_FILE="$TMP/drive-info.csv"

unlink "$OUTPUT_FILE" 1> /dev/null 2>&1
touch "$OUTPUT_FILE"

lsblk -p -l -n -o 'kname,type,size,fstype,mountpoint' $DEVICE | \
	grep -F part 1> $TMP/lsblk.log

if [ "$?" = 0 -a -s $TMP/lsblk.log ]; then
	/bin/sed -i "s/[ ][ ]*/ /g" $TMP/lsblk.log

	if [ "$?" = 0 ]; then
		while read line; do
			device="$(echo "$line" | cut -f 1 -d ' ')"
			size="$(echo "$line" | cut -f 3 -d ' ')"
			fstype="$(echo "$line" | cut -f 4 -d ' ')"
			mtpt="$(echo "$line" | cut -f 5 -d ' ')"
			echo "$device [$size] $fstype $mtpt=$device"
		done < $TMP/lsblk.log

		echo "INSTALLER: SUCCESS"
		exit 0
	fi
fi

echo "INSTALLER: FAILURE"
exit 1

# end Breeze::OS setup script
