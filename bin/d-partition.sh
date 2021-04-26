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

DERIVED="`cat $TMP/selected-derivative 2> /dev/null`"
RELEASE="`cat $TMP/selected-release 2> /dev/null`"
SELECTED_DRIVE="`cat $TMP/selected-drive 2> /dev/null`"
SELECTED_SCHEME="`cat $TMP/selected-scheme 2> /dev/null`"
SELECTED_DRIVE_ID="`cat $TMP/drive-id 2> /dev/null`"
SFDISK_SCHEME="`cat $TMP/fdisk-scheme 2> /dev/null`"
DRIVE_TOTAL="`cat $TMP/drive-total 2> /dev/null`"
DRIVE_ID="`basename $SELECTED_DRIVE`"
SAVELOG="$TMP/sectors_"${DRIVE_ID}".save"

# A safeguard against a possible shell script bug, which causes
# symbol name clashing; and wiping of values within registers.
#
if [ "$DRIVE_ID" != "$SELECTED_DRIVE_ID" ]; then

	dialog --colors \
		--backtitle "Breeze::OS $RELEASE Installer" \
		--title "Breeze::OS Setup -- Hard Drive Partitioning" \
		--msgbox "\nYou may be running a computer with \Z1corrupted memory\Zn.\n\n                 Proceed anyways ?\n\n" 9 60

	if [ "$?" != 0 ]; then
		exit 1
	fi

	if [ "/dev/$SELECTED_DRIVE_ID" = "$SELECTED_DRIVE" ]; then
		DRIVE_ID="$SELECTED_DRIVE_ID"
	fi
fi

if [ "$DRIVE_TOTAL" = "" -o "$DRIVE_ID" = "" -o "$SFDISK_SCHEME" = "" -o \
	"$SELECTED_DRIVE" = "" -o "$SELECTED_SCHEME" = "" ]; then

	dialog --colors \
		--backtitle "Breeze::OS $RELEASE Installer" \
		--title "Breeze::OS Setup -- Hard Drive Partitioning" \
		--msgbox "\nThe drive name or partition list is missing.\nYou must reselect the desired drive ... !\n" 11 60

	exit 1
fi

if [ -s $TMP/gpt-partition-found ]; then

	dialog --colors \
		--backtitle "Breeze::OS $RELEASE Installer" \
		--title "Breeze::OS Setup -- Hard Drive Partitioning ($DRIVE_ID)" \
		--yesno "\nThe selected drive \Z1$SELECTED_DRIVE\Zn has a \Z1GPT\Zn partition.\n\
You must first remove it, before partitioning in \Z1MBR\Zn mode.\n\
Remember, \Z1all your data on the drive will be lost\Zn. Proceed (y/n) ?\n\n" 9 70

	if [ "$?" != 0 ]; then
		exit 1
	fi

	sgdisk --zap $SELECTED_DRIVE 1> sgdisk.log 2> $TMP/sgdisk.err

	if [ "$?" != 0 ]; then

		dialog --colors \
			--backtitle "Breeze::OS $RELEASE Installer" \
			--title "Breeze::OS Setup -- Hard Drive Partitioning" \
			--msgbox "\nFailed to remove the \Z1GPT\Zn partition.\n\n" 7 50

		exit 1
	fi
else
	dialog --colors \
		--backtitle "Breeze::OS $RELEASE Installer" \
		--title "Breeze::OS Setup -- Hard Drive Partitioning" \
		--yesno "\nAbout to \Z1partition\Zn drive \Z1$SELECTED_DRIVE\Zn. Proceed ? " 7 50

	if [ "$?" != 0 ]; then
		exit 1
	fi
fi

/bin/lsblk -n -l -o 'kname,mountpoint' $SELECTED_DRIVE | \
	1> $TMP/lsblk.log 2> $TMP/lsblk.error

/bin/sed -i "s/[ ][ ]*/ /g" $TMP/lsblk.log

while read line; do

	device=$(echo "$line" | cut -f 1 -d ' ')
	mountpoint=$(echo "$line" | sed 's/^.* //g')

	if [ "$mountpoint" != "" ]; then
		if [ "`echo "$mountpoint" | grep -F '/var/mnt'`" != "" ]; then
			umount "/dev/$device" 1> /dev/null 2> /dev/null
		elif [ "`echo "$mountpoint" | grep -F '$ROOTDIR'`" != "" ]; then
			umount "/dev/$device" 1> /dev/null 2> /dev/null
		fi
	fi
done < $TMP/lsblk.log

SECTOR_SIZE="`cat $TMP/sector-size 2> /dev/null`"

dialog --colors \
	--backtitle "Breeze::OS $RELEASE Installer" \
	--title "Breeze::OS Setup -- Hard Drive Partitioning" \
	--infobox "\nPlease wait, partitioning drive \Z1$SELECTED_DRIVE\Zn ...\n" 5 60

sync

if [ "$SECTOR_SIZE" = "4K" ]; then
	fdisk -H 224 -S 56 -B $TMP/fdisk-scheme $SELECTED_DRIVE \
		1> $TMP/fdisk.log 2> $TMP/fdisk.err
else
	fdisk -B $TMP/fdisk-scheme $SELECTED_DRIVE \
		1> $TMP/fdisk.log 2> $TMP/fdisk.err
fi

if [ "$?" != 0 ]; then
	dialog --colors \
		--backtitle "Breeze::OS $RELEASE Installer" \
		--title "Breeze::OS Setup -- Hard Drive Partitioning" \
		--msgbox "\nCould not partition drive $SELECTED_DRIVE with\n\
the selected scheme !\n" 15 60
	exit 1
fi

d-show-partitions.sh true format $SELECTED_DRIVE

command="`cat $TMP/disk-command`"

if [ "$command" = "FORMAT" ]; then
	exit 0
fi

#if [ "$command" = "RESTORE" ]; then
#	if [ -f "$SAVELOG" ]; then
#		sfdisk $OPTIONS $SELECTED_DRIVE -I "$SAVELOG"
#	fi
#	d-show-partitions.sh false restore "$SELECTED_DRIVE"
#	unlink $TMP/disk-command 2> /dev/null
#fi

exit 0

# end Breeze::OS setup script
