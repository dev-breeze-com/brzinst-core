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

. d-format-utils.sh

set_boot_root_devices()
{
	local line=""
	local partitions="$1"

	unlink $TMP/root-device 2> /dev/null
	unlink $TMP/boot-device 2> /dev/null

	while read line; do

		local device="$(echo "$line" | cut -f1 -d' ')"
		local mtpt="$(echo "$line" | cut -f2 -d' ')"

		if [ "$mtpt" = "$ROOTDIR" ]; then
			echo "$device" 1> $TMP/root-device
		fi

		if [ "$mtpt" = "$ROOTDIR/boot" ]; then
			echo "$device" 1> $TMP/boot-device
		fi
	done < $partitions

	if [ ! -s $TMP/boot-device ]; then
		if [ -s $TMP/root-device ]; then
			cp $TMP/root-device $TMP/boot-device
		fi
	fi
	return 0
}

is_valid_target()
{
	local line=""
	local partitions="$1"
	local filesystems="^(ext[234]|btrfs|vfat|reiserfs)$"

	while read line; do

		local mtpt="$(echo "$line" | cut -f2 -d' ')"
		local device="$(echo "$line" | cut -f1 -d' ')"

		if [ "$mtpt" != "$ROOTDIR" -a "$mtpt" != "$ROOTDIR/boot" ]; then
			continue
		fi

		local rootfs="$(blkid -s TYPE -o value $device)"

		if echo "$rootfs" | grep -q -E "$filesystems" ; then
			return 0
		fi

		echo "INSTALLER: FAILURE L_BOOT_FILESYSTEM_INVALID"
		exit 1

	done < $partitions

	return 1
}

# Main starst here ...
DEVICE="$1"
ARGUMENT="$2"
DRIVE_ID="$(basename $1)"
DISK_TYPE="$(extract_value "scheme-${DRIVE_ID}" 'disk-type')"

if [ -z "$DISK_TYPE" ]; then
	DISK_TYPE="$(detect_disk_type $DEVICE)"
fi

if [ "$DISK_TYPE" = "lvm" -a "$ARGUMENT" != "mounts" ]; then
	echo "/dev/mapper/lvmstore-root" 1> $TMP/selected-target-dmcrypt
fi

echo "$DEVICE" 1> $TMP/selected-target-dmcrypt
echo "$DEVICE" 1> $TMP/selected-drive-dmcrypt
echo "yes" 1> $TMP/selected-update-dmcrypt

FORMAT_SCHEME=$TMP/dmcrypt-$DRIVE_ID.csv

openssl rand -base64 48 | \
	gpg --symmetric --cipher-algo aes --armor >/path/to/key.gpg

while read line; do

	DEVID="$(echo "$line" | cut -f 1 -d',')"
	PTYPE="$(echo "$line" | cut -f 2 -d',')"
	SIZE="$(echo "$line" | cut -f 3 -d',')"
	FSTYPE="$(echo "$line" | cut -f 4 -d',')"
	MTPT="$(echo "$line" | cut -f 5 -d',')"
	MODE="$(echo "$line" | cut -f 6 -d',')"

	echo "INSTALLER: PROGRESS ((device,$DEVID),(mountpoint,$MTPT),(filesystem,$FSTYPE))"

	if [ "$PTYPE" = "8200" -o "$PTYPE" = "82" -o "$FSTYPE" = "swap" ]; then
		activate_swap "$DEVID"
		write_fstab $DEVID "swap" "swap" "0"
	else
		set_mountpoint "$line"
	fi
done < $FORMAT_SCHEME

if is_valid_target $TMP/targets.log ; then
	set_boot_root_devices $TMP/targets.log
	echo "INSTALLER: MESSAGE L_TARGET_DRIVE_SELECTED"
	sync; sleep 2
	echo "INSTALLER: SUCCESS"
	exit 0
fi

echo "INSTALLER: FAILURE L_MISSING_ROOT_FILESYSTEM"
exit 1

# end Breeze::OS setup script
