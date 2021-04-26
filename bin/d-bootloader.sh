#!/bin/bash
#
# GNU GENERAL PUBLIC LICENSE -- Version 3
#
# Copyright 2013 Pierre Innocent, Tsert Inc., All Rights Reserved
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
KERNEL="$(cat $TMP/selected-kernel 2> /dev/null)"
GPT_MODE="$(cat $TMP/selected-gpt-mode 2> /dev/null)"
DERIVED="$(cat $TMP/selected-derivative 2> /dev/null)"

add_loader() {

	if [ "$LOADERS" = "" ]; then
		LOADERS="$1"
	else
		LOADERS="$LOADERS,$1"
	fi
	return 0
}

get_root_fs() {

	local device="$(mount | grep -F " on $ROOTDIR/boot " | cut -f1 -d ' ')"

	if [ "$device" = "" ]; then
		device="$(mount | grep -F " on $ROOTDIR " | cut -f1 -d ' ')"
	fi

	local rootfs="$(lsblk -n -l -o 'fstype' $device)"

	echo -n "$rootfs"

	return 0
}

ROOT_FS="$(get_root_fs)"

if [ "$GPT_MODE" = "UEFI" ]; then
	add_loader gummiboot
	LOADER="gummiboot"
fi

if echo "$ROOT_FS" | grep -q -E '^(ext[234]|btrfs|vfat)$' ; then
	add_loader syslinux
	LOADER="syslinux"
fi

if [ "$DERIVED" = "debian" ]; then
	if [ "$GPT_MODE" = "UEFI" ]; then
		if [ "$ARCH" = "amd64" -o "$ARCH" = "x86_64" ]; then
			add_loader "grub-efi-amd64"
			LOADER="grub-efi-amd64"
		else
			add_loader "grub-efi-ia32"
			LOADER="grub-efi-ia32"
		fi
	else
		add_loader "grub-pc"
		LOADER="grub-pc"
	fi
fi

if [ "$GPT_MODE" != "UEFI" ]; then
	add_loader "lilo"

	if [ "$LOADER" = "" ]; then
		LOADER="lilo"
	fi
fi

if [ "$LOADERS" = "" ]; then
	echo "INSTALLER: FAILURE"
	exit 1
fi

echo "all-oses=no"
echo "loader=$LOADER"
echo "$LOADERS" 1> $TMP/bootloader.lst

exit 0

# end Breeze::OS setup script
