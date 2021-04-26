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

DEVICE="$2"
MEDIA="`echo "$1" | tr '[:lower:]' '[:upper:]'`"

DRIVE_TOTAL="`cat $TMP/drive-total 2> /dev/null`"
SELECTED_DRIVE="`cat $TMP/selected-drive 2> /dev/null`"
SELECTED_DEVICE="`cat $TMP/selected-device 2> /dev/null`"

unlink $TMP/drives 2> /dev/null
touch $TMP/drives

select_path() {

	local mtpt="$MOUNTPOINT"
	local path="`cat $TMP/selected-source-path`"

	if [ -f "$mtpt/$path" ]; then
		echo "$mtpt/$path" 1> $TMP/selected-source-path
		return 0
	fi
	echo "Not a valid path -- $path !"
	return 1
}

check_install_media() {

	RETCODE=1
	REMOUNT=true

	MEDIA="$1"
	DEVICE="$2"
	MOUNTPOINT="$3"
	LSB_RELEASE="$MOUNTPOINT/lsb-release"

	mounted="`mount | grep -F "$device" | cut -f 3 -d ' '`"

	if [ "$mounted" != "" ]; then
		if [ "$mounted" = "$MOUNTPOINT" ]; then
			REMOUNT=false
		else
			umount $DEVICE 2> $TMP/umount.errlog
			sleep 1
		fi
	fi

	if [ "$REMOUNT" = true ]; then
		if [ "$MEDIA" = "CDROM" ]; then
			mount -o ro -t iso9660 $DEVICE $MOUNTPOINT \
				1> /dev/null 2> $TMP/mount.errlog
		else
			mount -o ro $DEVICE $MOUNTPOINT \
				1> /dev/null 2> $TMP/mount.errlog
		fi
	fi

	if [ "$?" != 0 ]; then
		echo "$MEDIA $DEVICE failed to mount properly. Try again !"
		return 1
	fi

	for t in 1 2 3 4 5; do

		if [ -f "$LSB_RELEASE" ]; then
			if [ "`grep -F 'DISTRIB_ID=Breeze::OS' $LSB_RELEASE`" != "" ]; then
				RETCODE=0
			fi
		fi

		if [ "$RETCODE" = 0 ]; then
			echo "Breeze::OS INSTALL $MEDIA was recognized !"
			return 0
		fi
		sleep 2
	done
	echo "Breeze::OS INSTALL $MEDIA was not recognized !"
	return 1
}

select_partition()
{
	local count=1
	local device="$1"
	local title="$2"

	lsblk -n -l -o 'kname,type,size' $device | grep -F part 1> $TMP/lsblk.log

	/bin/sed -i "s/[ ][ ]*/ /g" $TMP/lsblk.log

	echo "--menu \"\" 0 60 0 \\" 1> $TMP/disk-usb.log

	cat $TMP/lsblk.log | while read line; do
		id="`echo "$line" | cut -f 1 -d ' '`"
		sz="`echo "$line" | cut -f 3 -d ' '`"
		echo "\"/dev/$id\" \"/dev/$id [ Partition_${count} -- $sz ]\" \\" >> $TMP/disk-usb.log
		count=$(( $count + 1 ))
	done

	dialog --colors \
		--backtitle "Breeze::OS $RELEASE Installer" \
		--title "$title" \
		--file $TMP/disk-usb.log 2> $TMP/selected-partition

	return $?
}

# Main starts here ...
#
if [ "$MEDIA" = "source" -a -f "$TMP/etc_fstab" ]; then

	dialog --colors \
		--backtitle "Breeze::OS $RELEASE Installer" \
		--title "Breeze::OS Setup -- Hard Drive Selection" \
		--defaultno \
		--yesno "\nTo start selecting your partitions anew;\n\
		reset your filesystem table (Yes/No) ?" 6 70

	if [ "$?" = 0 ]; then
		unlink $TMP/boot-selected 2> /dev/null
		unlink $TMP/root-device 2> /dev/null
		unlink $TMP/etc_fstab 2> /dev/null
		unlink $TMP/fstab 2> /dev/null
	fi
fi

if [ "$ARGUMENT" = "boot" ]; then

	DRIVE_ID="`basename $DEVICE`"

	NAME="`ls -l /dev/disk/by-id | \
		grep -F -m 1 "/$DRIVE_ID" | sed -r 's/ [-]>.*$//g'`"
	NAME="`echo "$NAME" | sed -r 's/^.*[ ]//g'`"

	echo "$DEVICE" 1> $TMP/boot-drive
	echo "$NAME" 1> $TMP/boot-drive-name

	echo "INSTALLER: SUCCESS"
	exit 0
fi

echo "$DEVICE" 1> $TMP/selected-source
echo "$MOUNTPOINT" 1> $TMP/selected-source-path

if [ "$MEDIA" = "CDROM" ]; then
	check_install_media "CDROM" "$DEVICE" "$MOUNTPOINT"

elif [ "$MEDIA" = "FLASH" ]; then
	check_install_media "FLASH" "$DEVICE" "$MOUNTPOINT"

else
	select_partition "$DEVICE" "$title"

	if [ "$?" = 0 ]; then

		PARTITION="`cat $TMP/selected-partition`"

		if [ "$ARGUMENT" = "memboost" ]; then
			echo "$PARTITION" 1> $TMP/selected-memboost
			echo "INSTALLER: SUCCESS"
			exit 0
		fi

		echo "$MOUNTPOINT" 1> $TMP/selected-source-path
		check_install_media "$MEDIA" "$PARTITION" "$MOUNTPOINT"

		if [ "$?" = 0 -a "$MEDIA" = "DISK" ]; then
			select_path $MOUNTPOINT
		fi
	fi
fi

if [ "$?" = 0 ]; then
	echo "INSTALLER: SUCCESS"
	exit 0
fi

echo "INSTALLER: FAILURE"
exit 1

# end Breeze::OS setup script
