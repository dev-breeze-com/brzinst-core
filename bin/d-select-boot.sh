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
. d-dirpaths.sh

BOOT_MODE="$1"
BOOT_DRIVE=""

RELEASE="`cat $TMP/selected-release 2> /dev/null`"
GPT_MODE="`cat $TMP/selected-gpt-mode 2> /dev/null`"

find_boot_partition() {

	fdisk -l $BOOT_DRIVE 1> $TMP/fdisk.log

	local found=false
	local windows=""

	while read line; do

		if [ "$line" = "" ]; then
			continue
		fi

		if [ "$found" = true ]; then
			if [ "`echo "$line" | grep -i -E 'NTFS|FAT'`" != "" ]; then
				windows="`echo "$line" | sed -r 's/[ ].*$//g'`"
				echo "$windows" 1> $TMP/windows-partition
				echo "$device_id" 1> $TMP/windows-device-id
				found=false
			fi
		fi

		if [ "`echo "$line" | grep -E '^/dev/[a-z][a-z0-9 ]*[*]'`" != "" ]; then
			BOOT_PARTITION="`echo "$line" | sed -r 's/[ ].*$//g'`"
			ROOT_DEVICE="$BOOT_PARTITION"
			ROOT_FS="`lsblk -n -l -o 'fstype' $ROOT_DEVICE`"
			PART_NO="`echo "$ROOT_DEVICE" | sed -r 's/[^0-9]*//g'`"
			echo "$BOOT_PARTITION" 1> $TMP/boot-partition
		fi

		if [ "`echo "$line" | grep -F 'Disk identifier:'`" != "" ]; then
			device_id="`echo "$line" | sed -r 's/.*[ ][ ]*//g'`"
			found=true
		fi
	done < "$TMP/fdisk.log"

	return 0
}

list_partitions() {

	local outfile="$1"
	local boot_drive="$2"

	echo "--menu \"\nThe \Z1first\Zn partition on \Z1/boot\Zn is the usual choice.\n\" 12 65 4 \\" 1> $outfile

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

mount_boot_partition() {

	BOOT_SELECTED="`cat $TMP/boot-selected 2> /dev/null`"

	if [ "$BOOT_SELECTED" != "" ]; then

		BOOT_DEVICE="`echo "$BOOT_SELECTED" | cut -f1 -d '|'`"
		BOOT_MTPT="`echo "$BOOT_SELECTED" | cut -f2 -d '|'`"

		mount $BOOT_DEVICE $ROOTDIR/$BOOT_MTPT

		if [ "$?" = 0 ]; then
			sleep 1
			return 0
		fi
	fi

	dialog --colors \
		--backtitle "Breeze::OS $RELEASE Installer" \
		--title "Breeze::OS Setup -- Boot Partition Selection" \
		--msgbox "\nCould not mount your boot partition !\n" 7 55

	return 1
}

# Main starts here ...
unlink $TMP/selected-boot-drive 2> /dev/null
unlink $TMP/boot-location 2> /dev/null
unlink $TMP/boot-partition 2> /dev/null
unlink $TMP/windows-partition 2> /dev/null

d-select-drive.sh boot

if [ "$?" != 0 ]; then
	exit 1
fi

BOOT_DRIVE="`cat $TMP/selected-boot-drive 2> /dev/null`"
BOOT_DEVICE="`mount | grep -F '/boot' | cut -f1 -d ' '`"

dialog --colors \
	--backtitle "Breeze::OS $RELEASE Installer" \
	--title "Breeze::OS Setup -- Boot Loader Settings" \
	--default-item "MBR" \
	--menu "\nSelect location of boot record [\Z1MBR\Zn] ?" 10 50 2 \
	"MBR" "Master Boot Record" \
	"BOOT" "Boot Partition" 2> $TMP/boot-location

if [ "$?" != 0 ]; then
	exit 1
fi

BOOT_MODE="`cat $TMP/boot-location 2> /dev/null`"

if [ "$BOOT_MODE" = "MBR" ]; then

	find_boot_partition

	if [ "$BOOT_DEVICE" = "" ]; then
		mount_boot_partition
		exit $?
	fi
fi

if [ "$BOOT_MODE" = "BOOT" ]; then

	d-select-partition.sh boot $BOOT_DRIVE

	if [ "$?" = 0 ]; then

		BOOT_PARTITION="`cat $TMP/selected-partition 2> /dev/null`"
		MTPT="`lsblk -n -l -o 'mountpoint' $BOOT_PARTITION`"

		echo "$BOOT_PARTITION" 1> $TMP/boot-partition
		echo "$BOOT_PARTITION,$MTPT" 1> $TMP/boot-selected

		if [ "$BOOT_DEVICE" = "" ]; then
			mount_boot_partition
			exit $?
		fi
	fi
	exit 1
fi

exit 0

# end Breeze::OS setup script
