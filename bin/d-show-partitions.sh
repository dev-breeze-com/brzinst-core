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
PROMPT="$1"
COMMAND="$2"
SELECTED_DRIVE="$3"

# Initialize folder paths
. d-dirpaths.sh

unlink "$TMP/gpt-partition-found" 2> /dev/null

DRIVE_ID="$(basename $SELECTED_DRIVE)"
DRIVE_TOTAL="$(cat $TMP/drive-total 2> /dev/null)"

/bin/lsblk -d -n -o 'model' "/dev/$DRIVE_ID" 1> $TMP/all-drive-names

DRIVE_NAME="$(cat $TMP/all-drive-names 2> /dev/null)"

if [ "$PROMPT" = "true" ]; then
	if [ "$COMMAND" = "custom-partition" ]; then
		/bin/cp ./text/disk-custom-partitioning.txt $TMP/partitions.txt
	elif [ "$COMMAND" = "partition" ]; then
		/bin/cp ./text/disk-descr-partition.txt $TMP/partitions.txt
	else
		/bin/cp ./text/disk-descr-format.txt $TMP/partitions.txt
	fi
else
	/bin/cp ./text/disk-descr.txt $TMP/partitions.txt
fi

DRIVE_SIZE=$(( $DRIVE_TOTAL * 1024 / 1000000 ))

/bin/sed -i "s/%hard\-drive%/\/dev\/$DRIVE_ID/g" $TMP/partitions.txt
/bin/sed -i "s/%hard\-drive\-model%/$DRIVE_NAME/g" $TMP/partitions.txt
/bin/sed -i "s/%hard\-drive\-size%/$DRIVE_SIZE/g" $TMP/partitions.txt

if [ -x /bin/lsblk ]; then
	/bin/lsblk "/dev/$DRIVE_ID" 1> $TMP/parted.log
else
	/sbin/sfdisk -l -uM $SELECTED_DRIVE | \
		/bin/grep -E -v "Units|Empty" 1> $TMP/sfdisk.log
	/bin/grep -v "^$" $TMP/sfdisk.log 1> $TMP/parted.log # 2> /dev/null
fi

csplit --prefix $TMP/outfile_ \
   -k $TMP/partitions.txt '/entries/' '{3}' 2> /dev/null

/bin/cat $TMP/outfile_00 1> $TMP/partitions.txt 2> /dev/null
/bin/cat $TMP/parted.log >> $TMP/partitions.txt 2> /dev/null
/bin/cat $TMP/outfile_01 >> $TMP/partitions.txt 2> /dev/null

/bin/grep -v "entries" $TMP/partitions.txt 1> $TMP/partitions.log

if [ "$COMMAND" = "restore" ]; then
	/bin/sed -i -e 's/partitioned/restored/g' $TMP/partitions.log
fi

clear
/bin/cat $TMP/partitions.log
read cmd

if [ "$PROMPT" = "true" ]; then
	cmd=$(echo $cmd | tr '[:upper:]' '[:lower:]')

	if [ "$COMMAND" = "custom-partition" ]; then
		if [ "$cmd" = "r" ]; then
			echo -n "REMOVE" 1> $TMP/disk-command
		fi
	else
		if [ "$cmd" = "r" ]; then
			echo -n "RESTORE" 1> $TMP/disk-command
		elif [ "$cmd" = "p" ]; then
			echo -n "PARTITION" 1> $TMP/disk-command
		elif [ "$cmd" = "f" ]; then
			echo -n "FORMATTING" 1> $TMP/disk-command
		else
			echo -n "SWAP" 1> $TMP/disk-command
		fi
	fi
elif [ "$COMMAND" = "fstab" ]; then
	echo -n "CONTINUE" 1> $TMP/disk-command
else
	echo -n "FORMATTING" 1> $TMP/disk-command
fi

GPT="$(grep -F GPT $TMP/partitions.txt 2> /dev/null)"

if [ "$GPT" != "" ]; then
	echo "GPT" 1> $TMP/gpt-partition-found
fi

unlink $TMP/partitions.log 2> /dev/null
unlink $TMP/partitions.txt 2> /dev/null
unlink $TMP/sfdisk.log 2> /dev/null
unlink $TMP/parted.log 2> /dev/null

exit 0

# end Breeze::OS setup script
