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

# Check that boot and root devices are mounted
# on /target/boot and /target/root respectively
#
is_valid_target()
{
    local line=""
    local rootfs=""
    local target="$1"
    local devid="$(basename $1)"
    local partitions="$TMP/partitions-${devid}.csv"
    local filesystems="^(ext[234]|msdos|vfat|reiserfs)$"

    unlink $TMP/root-device 2> /dev/null
    unlink $TMP/boot-device 2> /dev/null

    cat /proc/mounts | cut -f1,2 -d' ' | tr -s ' ' 1> $TMP/targets.log

    while read line; do

        local device="$(echo "$line" | cut -f1 -d' ')"
        local mtpt="$(echo "$line" | cut -f2 -d' ')"

        if [ "$mtpt" = "$ROOTDIR/boot" ]; then
            if grep -qE "$target.*,/boot," $partitions ; then
                echo "$device" 1> $TMP/boot-device
            fi
        elif [ "$mtpt" = "$ROOTDIR" ]; then
            if grep -qE "$target.*,/," $partitions ; then
                echo "$device" 1> $TMP/root-device
            elif grep -qE "/dev/.*root.*,/," $partitions ; then
                echo "$device" 1> $TMP/root-device
            fi
        fi

        if [ -s $TMP/boot-device -a -s $TMP/root-device ]; then
            break
        fi
    done < $TMP/targets.log

    sync

    if [ ! -s $TMP/root-device ]; then
        echo_failure "L_MISSING_ROOT_FILESYSTEM"
        return 1
    fi

    if [ ! -s $TMP/boot-device ]; then
        cp $TMP/root-device $TMP/boot-device
    fi

    device="$(cat $TMP/boot-device 2> /dev/null)"
    rootfs="$(blkid -s TYPE -o value $device)"

    if [ -z "$rootfs" ] ; then
        echo_failure "L_BOOT_FILESYSTEM_INVALID"
        return 1
    fi

    if ! echo "$rootfs" | grep -q -E "$filesystems" ; then
        echo_failure "L_BOOT_FILESYSTEM_INVALID"
        return 1
    fi

    TARGET="$target"
    return 0
}

set_mountpoints()
{
    local target="$1"
    local drive_id="$2"
    local hdpath="$3"
    local drive_ssd="$(is_drive_ssd $target)"
    local schemefile=$TMP/mountpoints-${drive_id}.csv

	declare -a entries

    if [ -n "$hdpath" ]; then
        mkdir -p $ROOTDIR/$hdpath/
    fi

	reorder_rootfs "$schemefile"

    while read line; do

		IFS=',' read -r -a entries <<< "$line"

        local device="${entries[0]}"
        local mtpt="${entries[1]}"
        local fstype="${entries[2]}"
        local ptype="${entries[3]}"
        local mode="${entries[4]}"
        local crypto="${entries[5]}"
        local rawdevice="${entries[6]}"

		if [ "$mode" = "ignore" ]; then continue; fi

        echo_progress "((device,$device),(mountpoint,$mtpt),(filesystem,$fstype))"

        echo_message "TIP_SETTING_MOUNTPOINTS((device,$device),(mountpoint,$mtpt),(filesystem,$fstype))"

        umount $device 2> /dev/null

        if [ -n "$hdpath" ]; then
            if [ "$mtpt" = "/" ]; then
                mtpt="$hdpath"
            else
                mtpt="$hdpath/$mtpt"
            fi
        fi

        set_mountpoint "$device" "$mtpt" "$fstype" "$ptype" "$drive_ssd"

        if [ "$mode" = "crypt" -a "$crypto" != "encfs" -a "$mtpt" != "/boot" ]; then
            write_crypto_conf "$target" "$rawdevice" "$device" "$mtpt" "$CRYPTO"
        fi
    done < $schemefile

    return 0
}

# Main starst here ...
if [ -z "$ROOTDIR" -o "${#ROOTDIR}" = 1 ]; then
    echo_failure "L_INVALID_ROOTDIR"
    exit 1
fi

IDX=0
DEVICE="$1"
TARGET="$DEVICE"
ARGUMENT="$2"

if ! is_valid_device "$DEVICE" ; then
    echo_failure "L_NO_DEVICE_SPECIFIED"
    exit 1
fi

if ! is_safemode_drive "$DEVICE" ; then
    echo_error "L_SAFEMODE_DRIVE_SELECTED !"
    exit 1
fi

DRIVE_ID="$(basename $DEVICE)"

SELECTED="$(cat $TMP/selected-drive 2> /dev/null)"

if [ -z "$SELECTED" -o "$SELECTED" != "$DEVICE" ]; then
    echo_failure "L_SCRIPT_MISMATCH_ON_DEVICE"
    exit 1
fi

SELECTED="$(extract_value scheme-${DRIVE_ID} 'device')"

if [ -z "$SELECTED" -o "$SELECTED" != "$DEVICE" ]; then
    echo_failure "L_SCRIPT_MISMATCH_ON_DEVICE"
    exit 1
fi

CRYPTO="$(extract_value "crypto-${DRIVE_ID}" 'crypt-type')"
DISK_TYPE="$(extract_value "scheme-${DRIVE_ID}" 'disk-type')"
ENCRYPTED="$(extract_value "scheme-${DRIVE_ID}" 'encrypted')"

if [ "$DISK_TYPE" = "lvm" ]; then
    SELECTED="$(get_lvm_master_drive $TARGET)"

    if [ "$SELECTED" != "$TARGET" ]; then
        echo_failure "L_INVALID_TARGET_DRIVE"
        exit 1
    fi
fi

unlink $TMP/root-device 2> /dev/null
unlink $TMP/boot-selected 2> /dev/null
unlink $TMP/selected-target 2> /dev/null
unlink $TMP/fstab 2> /dev/null
unlink $TMP/dmcrypt 2> /dev/null
unlink $TMP/crypttab 2> /dev/null
unlink $TMP/crypto-devices 2> /dev/null
unlink $TMP/umount.errs 2> /dev/null

if ! grep -qF "$DEVICE" $TMP/drives-formatted.lst ; then
    echo_failure "L_SELECTED_DRIVE_NOT_FORMATTED"
    exit 1
fi

touch $TMP/fstab 2> /dev/null
touch $TMP/crypttab 2> /dev/null
touch $TMP/crypto-devices 2> /dev/null
touch $TMP/umount.errs 2> /dev/null

printf "dmcrypt_key_timeout=1\ndmcrypt_retries=5\n\n" 1> $TMP/dmcrypt

cat <<EOT >> $TMP/fstab
proc      /proc       proc        defaults   0   0
sysfs     /sys        sysfs       defaults   0   0
devtmpfs  /dev        devtmpfs    remount,nosuid,mode=0755  0     0
tmpfs     /tmp        tmpfs       defaults,nodev,nosuid,mode=1777  0   0
tmpfs     /dev/shm    tmpfs       defaults,nodev,nosuid,mode=1777  0   0
devpts    /dev/pts    devpts      gid=5,mode=620   0   0
#tmpfs     /var/tmp    tmpfs       defaults,nodev,nosuid,mode=1777  0   0
EOT

ACL="$(cat $TMP/selected-mac 2> /dev/null)"

if [ "$ACL" = "smack" ]; then
    echo "# SMACK security policy mounted on /smack" >> $TMP/fstab
    echo "smackfs /smack smackfs smackfsdef=* 0 0" >> $TMP/fstab
    echo "" >> $TMP/fstab
fi

FILESYSTEMS="msdos vfat ext2 ext3 ext4 reiserfs reiser4 jfs xfs nilfs2 f2fs btrfs"

set_mountpoints $TARGET $DRIVE_ID

if [ "$DISK_TYPE" != "lvm" ]; then
    while read line; do
        dev="$(echo "$line" | cut -f2 -d'=')"

        if [ "$dev" != "$TARGET" ]; then
            set_mountpoints $dev "$(basename $dev)" /mnt/hd/${IDX}
            IDX=$(( $IDX + 1 ))
        fi
    done < $TMP/fstab-target-drives
fi

add_fstab_cdrom "$TARGET"

if is_valid_target "$TARGET" ; then

    cat $TMP/fstab 1> $TMP/etc_fstab
    cat $TMP/dmcrypt 1> $TMP/etc_dmcrypt
    cat $TMP/crypttab 1> $TMP/etc_crypttab

    KEY="scheme-${DRIVE_ID}"
    SCHEME="$(extract_value $KEY 'scheme')"
    DISK_TYPE="$(extract_value $KEY 'disk-type')"
    ENCRYPTED="$(extract_value $KEY 'encrypted')"
    FSTYPE="$(extract_value $KEY 'fstype')"
    GPT_MODE="$(extract_value $KEY 'gpt-mode' 'upper')"
    BOOT_SIZE="$(extract_value $KEY 'boot-size')"
    SWAP_SIZE="$(extract_value $KEY 'swap-size')"
    SECTOR_SIZE="$(extract_value $KEY 'sector-size')"

    echo "$TARGET" 1> $TMP/selected-target
    echo "$TARGET" 1> $TMP/selected-drive
    echo "$TARGET" 1> $TMP/selected-boot-drive

    echo "$SCHEME" 1> $TMP/selected-scheme
    echo "$GPT_MODE" 1> $TMP/selected-gpt-mode
    echo "$DRIVE_ID" 1> $TMP/selected-drive-id
    echo "$DISK_TYPE" 1> $TMP/selected-disktype
    echo "$BOOT_SIZE" 1> $TMP/selected-boot-size
    echo "$SWAP_SIZE" 1> $TMP/selected-swap-size

    echo_message "L_TARGET_DRIVE_SELECTED"
    echo "INSTALLER: SUCCESS"
    exit 0
fi

echo "INSTALLER: FAILURE"
exit 1

# end Breeze::OS setup script
