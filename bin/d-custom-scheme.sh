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

DEFLT_FS="`cat $TMP/selected-fstype 2> /dev/null`"
GPT_MODE="`cat $TMP/selected-gpt-mode 2> /dev/null`"

DRIVE_TOTAL="`cat $TMP/drive-total 2> /dev/null`"
typeset -i DRIVE_TOTAL

#DRIVE_TOTAL=1000000000
DRIVE_TOTAL=$(( $DRIVE_TOTAL / 1000 ))

PT_NB=1
PT_SIZE=""
PT_SWAP="no"
PT_MTPT=""
PT_FSTYPE=""
PT_BOOT="no"

DRIVE="`cat $TMP/selected-drive 2> /dev/null`"

if [ "$GPT_MODE" = "UEFI" ]; then
	PT_SIZE=512
	PT_MTPT="/boot/efi"

elif [ "$GPT_MODE" = "GPT" ]; then
	PT_SIZE=512
	PT_MTPT="/boot"

else
	PT_SIZE=2
	PT_MTPT=""
fi

FILESYSTEMS="vfat ext2 ext3 ext4 reiserfs btrfs jfs xfs"

unlink $TMP/selected-scheme
touch  $TMP/selected-scheme

while [ 0 ]; do

	count=1
	OK=false

	RETCODE=1
	PT_BOOT="no"
	PT_SWAP="no"
	PT_FSTYPE="$DEFLT_FS"

	dialog --colors --ok-label "Submit" \
		--backtitle "Breeze::OS $RELEASE Installer" \
		--title "Breeze::OS $RELEASE Setup -- Custom Partition" \
		--form "\nPartition is \Z1$DRIVE$PT_NB\Zn and the filesystems to choose from are:\n\
\Z1VFAT\Zn is the traditional Microsoft file system. \
\Z1Ext2\Zn is the traditional Linux filesystem. \
\Z1Ext3\Zn is the journaling version of the Ext2 filesystem. \
\Z1Ext4\Zn is the successor to the Ext3 filesystem. \
\Z1ReiserFS\Zn is a journaling filesystem using only B-trees. \
\Z1BtrFS\Zn is a new B-tree copy-on-write filesystem. \
\Z1JFS\Zn is IBM's journaling filesystem, used in enterprise servers. \
\Z1XFS\Zn is SGI's journaling filesystem that originated on IRIX.\n\n\
Enter the partition information below ...\n" 22 70 5 \
			"Bootable: " 1 1 "$PT_BOOT" 1 13 50 0 \
			"As Swap: " 2 1 "$PT_SWAP" 2 13 50 0 \
			"Size (MB): " 3 1 "$PT_SIZE" 3 13 50 0 \
			"Filesystem: " 4 1 "$PT_FSTYPE" 4 13 50 0 \
			"Mountpoint: " 5 1 "$PT_MTPT" 5 13 50 0 2> $TMP/fields.txt

	if [ "$?" != 0 ]; then
		exit 1
	fi

	while read f; do
		case $count in
			1) BOOT="$f" ;;
			2) SWAP="$f" ;;
			3) SIZE="$f" ;;
			4) FSTYPE="$f" ;;
			5) MTPT="$f" ;;
			*) ;;
		esac
		count=$(( $count + 1 ))

	done < "$TMP/fields.txt"

	BOOT="`echo "$BOOT" | tr '[:upper:]' '[:lower:]'`"
	SWAP="`echo "$SWAP" | tr '[:upper:]' '[:lower:]'`"
	FSTYPE="`echo "$FSTYPE" | tr '[:upper:]' '[:lower:]'`"

	if [ "$SWAP" = "yes" ]; then
		OK=true
		FSTYPE="swap"
	else
		for fs in $FILESYSTEMS; do
			if [ "$fs" = "$FSTYPE" ]; then
				OK=true
				break
			fi
		done
	fi

	if [ "$BOOT" != "no" -a "$BOOT" != "yes" ]; then
		dialog --colors --clear \
			--backtitle "Breeze::OS $RELEASE Installer" \
			--title "Breeze::OS $RELEASE Setup -- Custom Partition" \
			--msgbox "\nThe entry \Z1'Bootable'\Zn must be \Z1yes\Zn or \Z1no\Zn !" 8 60 2> /dev/null
		continue
	fi

	if [ "$SWAP" != "no" -a "$SWAP" != "yes" ]; then
		dialog --colors --clear \
			--backtitle "Breeze::OS $RELEASE Installer" \
			--title "Breeze::OS $RELEASE Setup -- Custom Partition" \
			--msgbox "\nThe entry \Z1'As swap'\Zn must be \Z1yes\Zn or \Z1no\Zn !" 8 60 2> /dev/null
		continue
	fi

	if [ "$OK" = false -o "$FSTYPE" = "" ] || [ "$MTPT" = "" -a "$SWAP" = "no" ]; then
		dialog --colors --clear \
			--backtitle "Breeze::OS $RELEASE Installer" \
			--title "Breeze::OS $RELEASE Setup -- Custom Partition" \
			--msgbox "\nYou must properly specify the \Z1filesystem type\Zn; as well as, the \Z1mount point\Zn for the partition !" 8 60 2> /dev/null
		continue
	fi

	if [ "$SWAP" = "yes" ]; then
		MTPT="/swap"
	fi

	if [ "$BOOT" = "yes" ]; then
		BOOT="*"
	else
		BOOT=""
	fi

	TOTAL=$(( $DRIVE_TOTAL - $SIZE ))

	if test "$TOTAL" -lt 10; then
		dialog --colors --clear \
			--backtitle "Breeze::OS $RELEASE Installer" \
			--title "Breeze::OS $RELEASE Setup -- Custom Partition" \
			--yesno "\nYou have no more drive space to allocate, exit (y/n) !" 8 60 2> /dev/null

		RETCODE="$?"

		if [ "$RETCODE" != 0 ]; then
			continue
		fi
	fi

	echo "$DRIVE$NB:$MTPT:$SIZE:$FSTYPE" >> $TMP/selected-scheme
	echo ",$SIZE,L,$BOOT" >> $TMP/fdisk-scheme

	if [ "$PT_NB" = 3 -a $RETCODE != 0 ]; then
		echo ",,E" >> $TMP/fdisk-scheme
	fi

	PT_NB=$(( $PT_NB + 1 ))
	DRIVE_TOTAL=$(( $DRIVE_TOTAL - $SIZE ))
	PT_SIZE="$DRIVE_TOTAL"
	PT_MTPT=""

	if [ "$RETCODE" = 0 ]; then
		exit 0
	fi
done

exit 0

# end Breeze::OS setup script

