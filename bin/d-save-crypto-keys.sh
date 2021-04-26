#!/bin/bash
#
# GNU GENERAL PUBLIC LICENSE Version 3
#
# Copyright 2016 Pierre Innocent, Tsert Inc. All rights reserved.
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

. d-crypto-utils.sh

# Check that boot and root devices are mounted
# on /target/boot and /target/root respectively
#
is_valid_usb()
{
	if ! lsblk -o MODEL "$1" | grep -iqF "usb flash" ; then
		return 1
	elif ! lsblk -o RM "$1" | grep -qF '1' ; then
		return 1
	fi
	return 0
}

exit_with_error()
{
	echo "INSTALLER: MESSAGE L_INVALID_CRYPTO_DRIVE_SELECTED"
	sync; sleep 1
	exit 1
}

# Main starst here ...
DEVICE="$1"
FATSIZE="16"
DRIVE_ID="$(basename $1)"
LUKSLABEL="BRZCRYPTO"
LUKSDEVICE="${DEVICE}3"

SOURCE="$(cat $TMP/selected-source 2> /dev/null)"
SRCMEDIA="$(cat $TMP/selected-source-media 2> /dev/null)"

DISK_SIZE="$(get_drive_size $DEVICE)"

if test $DISK_SIZE -gt 4000; then FATSIZE="32"; fi

if [ "$SOURCE" = "$DEVICE" -o "$SRCMEDIA" = "$DEVICE" ]; then
	exit_with_error

elif test $DISK_SIZE -gt 16000; then
	exit_with_error

elif ! is_valid_usb $DEVICE ; then
	exit_with_error
fi

CRYPTO="$(extract_value crypto-${DRIVE_ID} 'crypto-type')"
PASSWORD="$(extract_value crypto-${DRIVE_ID} 'password')"
CONTAINER="$(extract_value crypto-${DRIVE_ID} 'container')"
ENCRYPTED="$(extract_value scheme-${DRIVE_ID} 'encrypted')"

# Use sgdisk to wipe and then setup the USB device:
# - 1 MB BIOS boot partition
# - 100 MB EFI system partition
# - Let Breeze::OS have the rest
# - Make the Linux partition "legacy BIOS bootable"
# Make sure that there is no MBR nor a partition table anymore:
dd if=/dev/zero of=$DEVICE bs=4096 count=1024 conv=notrunc

# The first sgdisk command is allowed to have non-zero exit code:
sgdisk -og $DEVICE || true
sgdisk \
	-n 1:2048:4095 -c 1:"BIOS Boot Partition" -t 1:ef02 \
	-n 2:4096:208895 -c 2:"EFI System Partition" -t 2:ef00 \
	-n 3:208896:0 -c 3:"Breeze::OS Crypto Keys" -t 3:8300 \
	$DEVICE

if [ $? != 0 ]; then
	echo "INSTALLER: FAILURE"
	exit 1
fi

# Make partition active
#sgdisk -A 3:set:2 $DEVICE

# Show what we did to the USB stick:
#sgdisk -p -A 3:show $DEVICE

# Create filesystems:
# Not enough clusters for a 32 bit FAT:
mkdosfs -s 2 -n "BRZDOS" ${DEVICE}1 && sync

if [ $? != 0 ]; then
	echo "INSTALLER: FAILURE"
	exit 1
fi

mkdosfs -F${FATSIZE} -s 2 -n "BRZEFI" ${DEVICE}2 && sync

if [ $? != 0 ]; then
	echo "INSTALLER: FAILURE"
	exit 1
fi

# KDE tends to automount.. so try an umount:
if mount | grep -qw ${DEVICE}3 ; then
	umount ${DEVICE}3 || true
fi

mkfs.ext4 -F -F -L "${LUKSLABEL}" -m 0 ${DEVICE}3 && sync

if [ $? != 0 ]; then
	echo "INSTALLER: FAILURE"
	exit 1
fi

tune2fs -c 0 -i 0 ${DEVICE}3 && sync

if [ $? != 0 ]; then
	echo "INSTALLER: FAILURE"
	exit 1
fi

if [ "$CONTAINER" = "crypted" ]; then
	LUKSDEVICE="$(init_crypto_luks $DEVICE ${DEVICE}3 keys)"
fi

mount -t auto $LUKSDEVICE /mnt/lukskeys && sync

if [ $? != 0 ]; then
	echo "INSTALLER: FAILURE"
	exit 1
fi

cp -a $TMP/boot /mnt/lukskeys/ && sync

if [ $? != 0 ]; then
	echo "INSTALLER: FAILURE"
	exit 1
fi

umount $LUKSDEVICE && sync

exit $?

# end Breeze::OS setup script
