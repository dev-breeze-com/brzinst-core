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

ARCH="$(cat $TMP/selected-arch 2> /dev/null)"

add_loader() {

	if [ -z "$LOADERS" ]; then
		LOADERS="$1"
	elif ! echo "$LOADERS" | grep -qF "$1" ; then
		LOADERS="$LOADERS,$1"
	fi
	return 0
}

get_boot_fs() {

	local device="$(mount | grep -F " on $ROOTDIR/boot " | cut -f1 -d ' ')"

	if [ -z "$device" ]; then
		device="$(mount | grep -F " on $ROOTDIR " | cut -f1 -d ' ')"
	fi

	local bootfs="$(lsblk -n -l -o 'fstype' $device)"

	if [ -z "$bootfs" ]; then
		bootfs="$(blkid -s TYPE -o value $device)"
	fi

	echo -n "$bootfs"
	return 0
}

DEVICE="$1"
LOADERS=""
LOADER="syslinux"

if ! is_valid_device "$DEVICE" ; then
	echo_failure "L_NO_DEVICE_SPECIFIED"
	exit 1
fi

if ! is_safemode_drive "$DEVICE" ; then
	echo_failure "L_INVALID_DEVICE_SPECIFIED"
	exit 1
fi

DRIVE_ID="$(basename $DEVICE)"
GPT_MODE="$(extract_value scheme-${DRIVE_ID} 'gpt-mode' 'upper')"
BOOT_FS="$(get_boot_fs)"

if [ "$GPT_MODE" = "S_UEFI" ]; then
	add_loader "grub"
	add_loader "gummiboot"
	LOADER="gummiboot"
fi

if echo "$BOOT_FS" | grep -q -E '^(ext[234]|btrfs|vfat)$' ; then
	add_loader "grub"
	add_loader "syslinux"
	LOADER="syslinux"
fi

if echo "$BOOT_FS" | grep -q -E '^(reiserfs)$' ; then
	add_loader "grub"
	LOADER="grub"
fi

if [ "$GPT_MODE" = "MBR" ]; then
	add_loader "lilo"

	if [ -z "$LOADER" ]; then
		LOADER="lilo"
	fi
fi

if [ -z "$LOADERS" ]; then
	echo_failure "L_NO_VALID_BOOTLOADER_FOUND"
	exit 1
fi

echo "gpt-mode=$GPT_MODE" 1> $TMP/bootloader.map
echo "loaders=$LOADERS" 1> $TMP/bootloader.map
echo "loader=$LOADER" 1> $TMP/bootloader.map
echo "linuxes=no" >> $TMP/bootloader.map
echo "windows=no" >> $TMP/bootloader.map

echo "$LOADERS" 1> $TMP/bootloader.lst
echo "$LOADER" 1> $TMP/selected-bootloader

exit 0

# end Breeze::OS setup script
