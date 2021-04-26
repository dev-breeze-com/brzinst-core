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
# d-gpt-partition.sh create GPT disk partitions <dev@tsert.com>
#
# Initialize folder paths
. d-dirpaths.sh

DERIVED="`cat $TMP/selected-derivative 2> /dev/null`"
RELEASE="`cat $TMP/selected-release 2> /dev/null`"

SELECTED_SCHEME="`cat $TMP/selected-scheme 2> /dev/null`"
SELECTED_DRIVE="`cat $TMP/selected-drive 2> /dev/null`"
GPT_MODE="`cat $TMP/selected-gpt-mode 2> /dev/null`"
SECTOR_SIZE="`cat $TMP/sector-size 2> /dev/null`"
DRIVE_TOTAL="`cat $TMP/drive-total 2> /dev/null`"
DRIVE_ID="`basename $SELECTED_DRIVE`"
SAVELOG="$TMP/sectors_GPT_"$DRIVE_ID".sav"

if [ "$DRIVE_TOTAL" = "" -o "$DRIVE_ID" = "" -o \
	"$SELECTED_DRIVE" = "" -o "$SELECTED_SCHEME" = "" ]; then

	dialog --colors --clear \
		--backtitle "Breeze::OS $RELEASE Installer" \
		--title "Breeze::OS Setup -- Hard Drive Partitioning" \
		--msgbox "\nThe drive name or partition list is missing.\nYou must reselect the desired drive ... !\n" 11 60
	exit 1
fi

dialog --colors --clear \
	--backtitle "Breeze::OS $RELEASE Installer" \
	--title "Breeze::OS Setup -- Hard Drive Partitioning" \
	--yesno "\nAbout to \Z1partition\Zn drive \Z1$SELECTED_DRIVE\Zn. Proceed ? " 7 50

if [ "$?" != 0 ]; then
	exit 1
fi

sgdisk --mbrtogpt --backup "$SAVELOG" $SELECTED_DRIVE 2> $TMP/sgdisk.errlog

if [ "$?" != 0 ]; then

	dialog --colors --clear \
		--backtitle "Breeze::OS $RELEASE Installer" \
		--title "Breeze::OS Setup -- Partitioning $SELECTED_DRIVE" \
		--yesno "\nBacking-up of partition information failed; proceed anyways ? " 7 50

	if [ "$?" != 0 ]; then
		exit 1
	fi
fi

unlink /tmp/errors
touch /tmp/errors

lsblk -n -l -o 'kname,type,size,mountpoint' $SELECTED_DRIVE | \
	grep -E '^[a-z]+[0-9]' 1> $TMP/lsblk.log 2> $TMP/lsblk.error

sed -i "s/[ ][ ]*/ /g" $TMP/lsblk.log

while read line; do

	device="`echo "$line" | cut -f 1 -d ' '`"
	type="`echo "$line" | cut -f 2 -d ' '`"
	size="`echo "$line" | cut -f 3 -d ' '`"
	mountpoint="`echo "$line" | sed 's/^.* //g'`"

	echo "'$device' '$size' '$mountpoint'"

	if [ "$type" != "part" ]; then
		continue
	fi

	if [ "$size" = "" -o "$size" = "1K" ]; then
		continue
	fi

	if [ "`echo $mountpoint | grep '/var/mnt'`" != "" ]; then
		umount "/dev/$device" 1> /dev/null 2> /dev/null
	elif [ "`echo $mountpoint | grep '$ROOTDIR'`" != "" ]; then
		umount "/dev/$device" 1> /dev/null 2> /dev/null
	fi

	partition=$(echo "$device" | sed 's/[a-z]*//g')

	sgdisk -d $partition "$SELECTED_DRIVE" 1> $TMP/success.log 2> $TMP/error.log

	if [ "$?" = 3 ]; then
		sgdisk -g -d $partition "$SELECTED_DRIVE" \
			1> $TMP/success.log 2> $TMP/error.log
	fi

	if [ "$?" != 0 ]; then

		dialog --colors --clear \
			--backtitle "Breeze::OS $RELEASE Installer" \
			--title "Breeze::OS Setup -- Partitioning $SELECTED_DRIVE" \
			--yesno "\nCould not remove partition $partition ! " 7 50
		exit 1
	fi
done < $TMP/lsblk.log

#
# Default sector alignment is 2048 => 8.4M bytes for 4K drives
#
idx=1
size=0
sectors=0
end_sector=0
max_partitions=1

FACTOR=$(( 1024000 / $SECTOR_SIZE ))

for partition in $SELECTED_SCHEME; do
	max_partitions=$(( $max_partitions + 1 ))
done

for partition in $SELECTED_SCHEME; do

	name="`echo "$partition" | cut -f 1 -d ','`"
	ptype="`echo "$partition" | cut -f 2 -d ','`"
	size="`echo "$partition" | cut -f 3 -d ','`"
	fstype="`echo "$partition" | cut -f 4 -d ','`"
	mtpt="`echo "$partition" | cut -f 5 -d ','`"
	mode="`echo "$partition" | cut -f 6 -d ','`"

	sectors=$(( $size * $FACTOR ))

	if test $idx -lt $max_partitions; then
		end_sector=$(( $sectors + $end_sector ))
	else
		end_sector=0
	fi

	if [ "$ptype" = "EFI" ]; then
		FSTYPE="-t $idx:0xEF00"
	elif [ "$ptype" = "GPT" ]; then
		FSTYPE="-t $idx:0xEF02"
	elif [ "$fstype" = "SWAP" ]; then
		FSTYPE="-t $idx:0x8200"
	elif [ "$ptype" = "LVM" ]; then
		FSTYPE="-t $idx:0x8E00"
	else
		FSTYPE="-t $idx:0x$ptype"
	fi

	sgdisk -a 2048 -n "$idx:0:$end_sector" "$FSTYPE" \
		"$SELECTED_DRIVE" 1> $TMP/success.log 2> $TMP/error.log

	if [ "$?" != 0 ]; then
		dialog --colors --clear \
			--backtitle "Breeze::OS $RELEASE Installer" \
			--title "Breeze::OS Setup -- Hard Drive Partitioning" \
			--msgbox "\nCould not partition drive $SELECTED_DRIVE with\n\
	the selected scheme $SELECTED_SCHEME ... !\n" 15 60
		exit 1
	fi
	idx=$(( $idx + 1 ))
done

d-show-partitions.sh true format "$SELECTED_DRIVE"

cmd="`cat $TMP/disk-command`"

if [ "$cmd" = "FORMAT" ]; then
	exit 0
fi

if [ "$cmd" = "RESTORE" ]; then
	if [ -f "$SAVELOG" ]; then
		sgdisk --load-backup "$SAVELOG" $SELECTED_DRIVE 
	fi
	d-show-partitions.sh false restore "$SELECTED_DRIVE"
	unlink $TMP/disk-command 2> /dev/null
fi

exit 0

