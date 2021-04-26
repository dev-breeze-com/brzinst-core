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

FSTYPE="`cat $TMP/selected-fstype 2> /dev/null`"
RELEASE="`cat $TMP/selected-release 2> /dev/null`"

GPT_MODE="`cat $TMP/selected-gpt-mode 2> /dev/null`"
SMACK_ENABLED="`cat $TMP/selected-smack 2> /dev/null`"
SELECTED_DRIVE="`cat $TMP/selected-drive 2> /dev/null`"
SELECTED_DEVICE="`cat $TMP/selected-device 2> /dev/null`"

#ask_mtpt( mtpt ) - Asks the user the filesystem mount point to use
#                   for the named device. Answer in $TMP/retcode
ask_mtpt() {

	local device="$1"
	local ptype="$2"
	local mtpt="$3"
	local size="$4"
	local ssize="`lsblk -n -o 'size' $device | crunch`"
	typset -i size

	if [ "$ptype" = "EF00" ]; then
		mtpt="/boot/efi"
	elif [ "$ptype" = "8E00" -o "$ptype" = "FD00" -o \
		"$ptype" = "8E" -o "$ptype" = "FD" ]; then
		mtpt="/$ptype-`basename $device`"
	elif [ "$mtpt" = "/none" ]; then
		mtpt=""
	elif [ "$mtpt" != "/swap" ] && [ 10 -gt "$size" ]; then
		mtpt="/bios"
	elif [ "$mtpt" != "/swap" ] && [ 300 -gt "$size" ]; then
		mtpt="/boot"
	fi

	dialog --colors \
		--backtitle "Breeze::OS $RELEASE Installer." \
		--title "Breeze::OS Setup -- Formatting ($device)" \
		--inputbox "\nIf the partition is to be used as \Z1swap\Zn, enter \Z1/swap\Zn.\n\
If the partition is to be used as \Z1bios boot\Zn, enter \Z1/bios\Zn.\n\
If the partition is to be used as \Z1mbr boot\Zn, enter \Z1/boot\Zn.\n\
If the partition is not to be used, then leave empty.\n\n\
Partition \Z1$device\Zn is of type \Z1$DESCRIPTION\Zn\n\
The total size of \Z1$device\Zn is $ssize\n\n\
You must specify a filesystem \Z1path\Zn, for example:\n\
   '/boot', '/home', '/var', '/share', '/usr', or '/' as \Z1root\Zn\n\n\
Enter filesystem \Z1path\Zn !\n" 20 70 "$mtpt" 2> $TMP/selected-mountpoint

	if [ "$?" != 0 ]; then
		dialog --colors \
			--backtitle "Breeze::OS $RELEASE Installer" \
			--title "Breeze::OS Setup -- Formatting ($device)" \
			--msgbox "\nYou just chose to cancel formatting !\n" 7 45
		return 1
	fi
	return 0
}

skip_partition() {

	local device="$1"
	local ptype="$2"
	local mtpt="$3"
	local ssize="`lsblk -n -o 'size' $device | crunch`"

	local bsd="`echo "$DESCRIPTION" | grep -F -i 'BSD'`"
	local windows="`echo "$DESCRIPTION" | grep -E -i 'NTFS|VFAT'`"

	if [ "$ptype" = "EF02" ]; then
		if [ "$GPT_MODE" != "MBR" ]; then
			partnum="`echo $device | sed 's/^[^0-9]*//g'`"
			sgdisk --typecode=partnum:0xEFO2 $device

			dialog --colors \
				--backtitle "Breeze::OS $release Installer" \
				--title "Breeze::OS Setup -- Formatting ($device)" \
				--msgbox "\nSetting as \Z1$DESCRIPTION (BBP)\Zn !\n" 7 65
		else	
			dialog --colors \
				--backtitle "Breeze::OS $release Installer" \
				--title "Breeze::OS Setup -- Formatting ($device)" \
				--msgbox "\nSkipping partition of type \Z1$DESCRIPTION\Zn and size \Z1$ssize\Zn !\n" 7 65
		fi
		echo -n "ignored" 1> $TMP/selected-mountpoint
		return 0
	fi

	if [ "$mtpt" = "/none" ]; then
		dialog --colors \
			--backtitle "Breeze::OS $release Installer" \
			--title "Breeze::OS Setup -- Formatting ($device)" \
			--msgbox "\nSkipping partition of type \Z1$DESCRIPTION\Zn and size \Z1$ssize\Zn !\n" 7 65
		echo -n "ignored" 1> $TMP/selected-mountpoint
		return 0
	fi

	if [ "$bsd" != "" -o "$windows" != "" ]; then
		dialog --colors \
			--backtitle "Breeze::OS $RELEASE Installer" \
			--title "Breeze::OS Setup -- Formatting ($device)" \
			--msgbox "\nSkipping partition of type \Z1$DESCRIPTION\Zn and size \Z1$ssize\Zn !\n" 7 65
		echo -n "ignored" 1> $TMP/selected-mountpoint
		return 0
	fi
	return 1
}

# Main starts here ...

command="$1"
device="$2"
ptype="`echo "$3" | tr '[:lower:]' '[:upper:]'`"
mtpt="$4"
psize="$5"

. d-select-fsdescr.sh "$ptype"

DESCRIPTION="`grep -E -i "^$ptype[=]" $FSTYPES | cut -f2 -d '='`"

if [ "$command" = "CHECK" ]; then

	skip_partition "$device" "$ptype" "$mtpt" "$psize"

	if [ "$?" = 0 ]; then
		exit 1
	fi
	exit 0
fi

while true; do

	skip_partition "$device" "$ptype" "$mtpt" "$psize"

	if [ "$?" = 0 ]; then
		unlink $TMP/selected-mountpoint 2> /dev/null
		exit 2
	fi

	ask_mtpt "$device" "$ptype" "$mtpt" "$psize"

	if [ "$?" != 0 ]; then
		unlink $TMP/selected-mountpoint 2> /dev/null
		exit 1
	fi

	MTPT="`cat $TMP/selected-mountpoint 2> /dev/null`"
	MTPT="`echo "$MTPT" | sed 's/ //g'`"

	if [ "$MTPT" = "" ]; then
		unlink $TMP/selected-mountpoint 2> /dev/null
		exit 2
	fi

	# add / to start of path
	if [ "`echo "$MTPT" | cut -b1`" != "/" ]; then
		MTPT="/$MTPT"
	fi

	if [ "$MTPT" = "/" ]; then
		FMTPT=""
	else
		FMTPT="$MTPT"
	fi

	MNTDEV="`mount | grep -F "$ROOTDIR$FMTPT" | cut -f1 -d ' '`"

	if [ "$MNTDEV" = "" -o "$MNTDEV" = "$device" ]; then 
		echo -n "$MTPT" 1> $TMP/selected-mountpoint
		exit 0
	fi

	dialog --colors \
		--backtitle "Breeze::OS $RELEASE Installer" \
		--title "Breeze::OS Setup -- Formatting ($device)" \
		--msgbox "\nPath \Z1$MTPT\Zn was already selected !\n" 7 65

	MTPT="$mtpt"
done

exit 0

# end Breeze::OS script
