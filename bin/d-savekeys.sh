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

. d-format-utils.sh

. d-crypto-utils.sh

copy_crypto_keys()
{
    local device="$1"
    local container="$2"

    echo_message "L_COPYING_CRYPTO_KEYS"

    mount -t auto $device /mnt/cryptokeys && sync

    if [ $? != 0 ]; then
        exit 1
    fi

    mkdir -p /mnt/cryptokeys/etc/ && sync

    rsync -av $TMP/etc/keys /mnt/cryptokeys/etc/ && sync

    rsync -av $TMP/boot /mnt/cryptokeys/ && sync

    if [ $? != 0 ]; then
        echo_failure "L_COPYING_CRYPTO_KEYS"
        exit 1
    fi

    umount $device && sync

    if [ "$container" = "crypted" ]; then
        echo_message "L_CLOSING_CRYPTO_CONTAINER"
        cryptsetup luksClose lukskeys
    fi

    return 0
}

# Main starst here ...
DEVICE="$1"
FATSIZE="16"
LUKSDEVICE="${DEVICE}3"

GDISK="$(which gdisk)"
SGDISK="$(which sgdisk)"
MKDOSFS="$(which mkdosfs)"

if ! is_valid_device "$DEVICE" ; then
    echo_failure "L_NO_DEVICE_SPECIFIED"
    exit 1
fi

DRIVE_ID="$(basename $DEVICE)"

TARGET="$(cat $TMP/selected-target 2> /dev/null)"
SOURCE="$(cat $TMP/selected-source 2> /dev/null)"
SRCMEDIA="$(cat $TMP/selected-source-media 2> /dev/null)"

CRYPTO="$(extract_value crypto-${DRIVE_ID} 'type')"
SELECTED="$(extract_value crypto-${DRIVE_ID} 'device')"
PASSWORD="$(extract_value crypto-${DRIVE_ID} 'password')"
CONFIRM="$(extract_value crypto-${DRIVE_ID} 'confirm')"
CONTAINER="$(extract_value crypto-${DRIVE_ID} 'container')"

mkdir -p /mnt/cryptokeys

if [ "$DEVICE" != "$SELECTED" -o "$DEVICE" = "$TARGET" ]; then
    echo_error "L_INVALID_KEYS_DRIVE_SELECTED"
    exit 1

elif [ "$SOURCE" = "$DEVICE" -o "$SRCMEDIA" = "$DEVICE" ]; then
    echo_error "L_INVALID_KEYS_DRIVE_SELECTED"
    exit 1

elif ! is_drive_usb $DEVICE ; then
    echo_error "L_INVALID_KEYS_DRIVE_SELECTED"
    exit 1

elif grep -qF "$DEVICE" $TMP/formatted-partitions ; then
    echo_error "L_INVALID_KEYS_DRIVE_SELECTED"
    exit 1

elif ! is_safemode_drive $DEVICE ; then
    echo_error "L_INVALID_KEYS_DRIVE_SELECTED"
    exit 1

else
    DISK_SIZE="$(get_drive_size $DEVICE)"

    if test $DISK_SIZE -gt 4000; then FATSIZE="32"; fi

    if test $DISK_SIZE -gt 32000; then
        echo_error "L_INVALID_KEYS_DRIVE_SELECTED"
        exit 1
    fi
fi

umount /mnt/cryptokeys 2> /dev/null

cryptsetup close lukskeys 2> /dev/null

if [ "$CONTAINER" = "crypted" ]; then

    if [ -z "$PASSWORD" ]; then
        echo_error "L_CRYPTO_PASSWORD_MISSING"
        exit 1
    fi

    if [ "$CONFIRM" != "$PASSWORD" ]; then
        echo_error "L_CRYPTO_PASSWORD_MISMATCH"
        exit 1
    fi
elif [ "$CONTAINER" = "reuse" ]; then

    LUKSDEVICE="$(blkid ${DEVICE}3)"

    if [ -z "$LUKSDEVICE" ]; then
        echo_error "L_INCORRECTLY_FORMATTED_DRIVE"
        exit 1
    fi

    if echo "$LUKSDEVICE" | grep -qF crypto_LUKS ; then
        echo "$PASSWORD" | cryptsetup luksOpen ${DEVICE}3 lukskeys
        LUKSDEVICE="/dev/mapper/lukskeys"
    else
        LUKSDEVICE="${DEVICE}3"
    fi

    copy_crypto_keys "$LUKSDEVICE" "$CONTAINER"

    exit $?

elif [ "$CONTAINER" = "factory" ]; then

    LUKSDEVICE="$(blkid ${DEVICE}2)"

    if [ -n "$LUKSDEVICE" ]; then
        echo_error "L_INCORRECTLY_FORMATTED_DRIVE"
        exit 1
    fi

    LUKSDEVICE="${DEVICE}1"

    if ! blkid -t TYPE=vfat -o device | grep -qF "$LUKSDEVICE" ; then
        echo_error "L_INCORRECTLY_FORMATTED_DRIVE"
        exit 1
    fi

    fatlabel $LUKSDEVICE "BRZCRYPTO"

    copy_crypto_keys "$LUKSDEVICE" "$CONTAINER"

    exit $?
fi

# Use sgdisk to wipe and then setup the USB device:
# - 1 MB BIOS boot partition

# - 100 MB EFI system partition
# - Let Breeze::OS have the rest
# - Make the Linux partition "legacy BIOS bootable"
# Make sure that there is no MBR nor a partition table anymore:
# Because of a bug in gdisk (v0.6.10), we do the following:
echo_message "L_INITIALIZING_DEVICE"
dd if=/dev/zero of=$DEVICE bs=4096 count=2024 conv=notrunc 2> /dev/null

# The first sgdisk command is allowed to have non-zero exit code:
echo_message "L_CREATING_GPT_PARTITIONS"
$SGDISK -og $DEVICE || true
$SGDISK \
    -n 1:2048:4095 -c 1:"BIOS Boot Partition" -t 1:ef02 \
    -n 2:4096:208895 -c 2:"EFI System Partition" -t 2:ef00 \
    -n 3:208896:0 -c 3:"Breeze::OS Crypto Keys" -t 3:8300 \
    $DEVICE

if [ $? != 0 ]; then
    echo "INSTALLER: FAILURE"
    exit 1
fi

# Make partition active
$SGDISK -A 3:set:2 $DEVICE

if [ $? != 0 ]; then
    echo "INSTALLER: FAILURE"
    exit 1
fi

# Show what we did to the USB stick:
#$SGDISK -p -A 3:show $DEVICE

# Create filesystems:
# Not enough clusters for a 32 bit FAT:
#mkdosfs -s 2 -n "DOS" ${DEVICE}1 && sync
echo_message "L_CREATING_DOS_FILE_SYSTEM"
mkfs.vfat -s 2 -n "BRZDOS" ${DEVICE}1 && sync

if [ $? != 0 ]; then
    echo "INSTALLER: FAILURE"
    exit 1
fi

echo_message "L_CREATING_VFAT_FILE_SYSTEM"
mkfs.vfat -F${FATSIZE} -s 2 -n "BRZLUKS" ${DEVICE}2 && sync
#mkdosfs -F${FATSIZE} -s 2 -n "BRZLUKS" ${DEVICE}2 && sync

if [ $? != 0 ]; then
    echo "INSTALLER: FAILURE"
    exit 1
fi

# KDE tends to automount.. so try an umount:
if mount | grep -qw $LUKSDEVICE ; then
    umount $LUKSDEVICE || true
fi

if [ "$CONTAINER" = "crypted" ]; then

    echo_message "L_OPENING_CRYPTO_CONTAINER"
    LUKSDEVICE="$(init_crypto_luks $DEVICE ${DEVICE}3 keys keys "$PASSWORD")"

    if [ $? != 0 ]; then
        echo "INSTALLER: FAILURE"
        exit 1
    fi
fi

echo_message "L_CREATING_CONTAINER_FILE_SYSTEM"
mkfs.ext4 -F -F -L "BRZCRYPTO" -m 0 $LUKSDEVICE && sync

if [ $? != 0 ]; then
    echo "INSTALLER: FAILURE"
    exit 1
fi

echo_message "L_TUNING_CONTAINER_FILE_SYSTEM"
tune2fs -c 0 -i 0 $LUKSDEVICE && sync

if [ $? != 0 ]; then
    echo "INSTALLER: FAILURE"
    exit 1
fi

copy_crypto_keys "$LUKSDEVICE" "$CONTAINER"
exit $?

# end Breeze::OS setup script
