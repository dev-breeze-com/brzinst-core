#!/bin/bash
#
# GNU GENERAL PUBLIC LICENSE Version 3
#
# Copyright 2015, Pierre Innocent, Tsert Inc. All Rights Reserved
#
# Took hints from SeTpartitions from Slackware
#
# Initialize folder paths
. d-dirpaths.sh

. d-format-utils.sh

. d-crypto-utils.sh

# make_f2fs( dev, sz ) - Create a F2FS filesystem on the named device
make_f2fs() {

    local check="$3"
    local rsrvd="$4"
    local label="$5"
    local SETL=""

    show_settings $1 f2fs $2

    if [ -n "$label" ]; then
        SETL="-l ${label:0:16}"
    fi

    echo "---------------- f2fs $1 -----------------" >> $TMP/format.errs

    mkfs.f2fs $SETL $1 1> /dev/null 2>> $TMP/format.errs
    #mkfs.f2fs $SETL -a 1 -o $rsrvd $1 1> /dev/null 2>> $TMP/format.errs

    return $?
}

# make_nilfs2( dev, sz ) - Create a NILFS2 filesystem on the named device
make_nilfs2() {

    local check="$3"
    local rsrvd="$4"
    local label="$5"
    local SETL=""

    show_settings $1 nilfs2 $2

    if [ "$check" = "y" ]; then
        check="-c"
    fi

    if [ -n "$rsrvd" ]; then
        rsrvd="-m $rsrvd"
    fi

    if [ -n "$label" ]; then
        SETL="-L ${label:0:32}"
    fi

    echo "---------------- nilfs2 $1 -----------------" >> $TMP/format.errs

    echo "y" | \
        mkfs.nilfs2 $SETL -q -f -b 4096 $rsrvd $check $1 \
        1> /dev/null 2>> $TMP/format.errs

    return $?
}

# make_xfs( dev, sz ) - Create a XFS filesystem on the named device
make_xfs() {

    local SETL=""
    local label="$5"

    show_settings $1 xfs $2

    if [ -n "$label" ]; then
        SETL="-L ${label:0:11}"
    fi

    echo "---------------- xfs $1 -----------------" >> $TMP/format.errs

    mkfs.xfs $SETL -q -f $1 1> /dev/null 2>> $TMP/format.errs

    return $?
}

# make_btrfs( dev, sz ) - Create a btrfs filesystem on the named device
make_btrfs() {

    local sectors="$SECTOR_SIZE"
    local label="$5"
    local SETL=""

    show_settings $1 btrfs $2

    if [ -n "$label" ]; then
        SETL="-L ${label:0:32}"
    fi

    echo "---------------- btrfs $1 -----------------" >> $TMP/format.errs

    mkfs.btrfs -s $sectors -d single -m single $1 \
        1> /dev/null 2>> $TMP/format.errs

    return $?
}

# make_ext2( dev, sz, check ) - Create a ext2 filesystem on the named device
make_ext2() {

    local check="$3"
    local label="$5"
    local SETL=""

    show_settings $1 ext2 $2

    if [ "$check" = "y" ]; then
        check="-c"
    fi

    if [ -n "$label" ]; then
        SETL="-L ${label:0:16}"
    fi

    echo "---------------- ext2 $1 -----------------" >> $TMP/format.errs

    mkfs.ext2 -F $SETL $check $1 1> /dev/null 2>> $TMP/format.errs

    return $?
}

# make_ext3( dev, sz, check ) - Create a ext3 filesystem on the named device
make_ext3() {

    local check="$3"
    local rsrvd="$4"
    local label="$5"
    local options=""
    local SETL=""

    show_settings $1 ext3 $2

    if [ "$check" = "y" ]; then
        check="-c"
    fi

    if ! enough_real_memory $PLATFORM ; then
        options="$options -D"
    fi

    if grep -qE '1[.]4[3-9][.][3-9]' $TMP/mkfs.version ; then
        options="$options -O ^64bit"
    fi

    if [ -n "$rsrvd" ]; then
        rsrvd="-m $rsrvd"
    fi

    if [ -n "$label" ]; then
        SETL="-L ${label:0:16}"
    fi

    echo "---------------- ext3 $1 -----------------" >> $TMP/format.errs

    echo "y" | \
        mkfs.ext3 -F -q -j $SETL $check $rsrvd -b 4096 $1 \
        1> /dev/null 2>> $TMP/format.errs

    return $?
}

# make_ext4( dev, sz, check ) - Create a ext4 filesystem on the named device
make_ext4() {

    local check="$3"
    local rsrvd="$4"
    local label="$5"
    local options="-E lazy_journal_init=0,lazy_itable_init=0"
    local SETL=""

    show_settings $1 ext4 $2

    if [ "$check" = "y" ]; then
        check="-c"
    fi

    if ! enough_real_memory $PLATFORM ; then
        options="$options -D"
    fi

    if ! enough_real_memory $PLATFORM ; then
        options="$options -D"
    fi

    if grep -qE '1[.]4[3-9][.][3-9]' $TMP/mkfs.version ; then
        options="$options -O ^64bit"
    fi

    if [ -n "$rsrvd" ]; then
        rsrvd="-m $rsrvd"
    fi

    if [ -n "$label" ]; then
        SETL="-L ${label:0:16}"
    fi

    echo "---------------- ext4 $1 -----------------" >> $TMP/format.errs

    echo "y" | \
        mkfs.ext4 -F -q -j $SETL $check $rsrvd $options -b 4096 $1 \
        1> /dev/null 2>> $TMP/format.errs
    #echo "y" | mkfs.ext4 -F -q -j $SETL $check $rsrvd -b $BLKSIZE $1 1> /dev/null 2>> $TMP/format.errs

    return $?
}

# make_msdos( dev, sz, check ) - Create a DOS filesystem on the named device
make_msdos() {

    local check="$3"
    local label="$5"
    local SETL=""

    show_settings $1 msdos $2

    if [ "$check" = "y" ]; then
        check="-c"
    fi

    if [ -z "$label" ]; then label="DOS"; fi

    if [ -n "$label" ]; then
        SETL="-n ${label:0:11}"
    fi

    echo "---------------- msdos $1 -----------------" >> $TMP/format.errs

    mkdosfs $SETL $check -s 2 $1 1> /dev/null 2>> $TMP/format.errs
    #mkdosfs $SETL $check -s 2 -F 32 $1 1> /dev/null 2>> $TMP/format.errs

    return $?
}

# make_vfat( dev, sz, check ) - Create a VFAT filesystem on the named device
make_vfat() {

    local check="$3"
    local label="$5"
    local SETL=""

    show_settings $1 vfat $2

    if [ "$check" = "y" ]; then
        check="-c"
    fi

    if [ -n "$label" ]; then
        SETL="-n ${label:0:11}"
    fi

    echo "---------------- vfat $1 -----------------" >> $TMP/format.errs

    mkfs.vfat $SETL $check -F 32 $1 1> /dev/null 2>> $TMP/format.errs

    return $?
}

# make_jfs( dev, sz, check ) - Create a jfs filesystem on the named device
make_jfs() {

    local check="$3"
    local label="$5"
    local SETL=""

    show_settings $1 jfs $2

    if [ "$check" = "y" ]; then
        check="-c"
    fi

    if [ -n "$label" ]; then
        SETL="-L ${label:0:32}"
    fi

    echo "---------------- jfs $1 -----------------" >> $TMP/format.errs

    mkfs.jfs $SETL -q $check $1 1> /dev/null 2>> $TMP/format.errs

    return $?
}

# make_reiserfs( dev, sz ) - Create a reiserfs filesystem on the named device
#
make_reiserfs() {

    local SETL=""
    local label="$5"

    show_settings $1 reiserfs $2

    if [ -n "$label" ]; then
        SETL="-l ${label:0:16}"
    fi

    echo "---------------- reiserfs $1 -----------------" >> $TMP/format.errs

    echo "y" | \
        mkfs.reiserfs $SETL -b $BLKSIZE -q $1 1> /dev/null 2>> $TMP/format.errs

    return $?
}

# make_reiser4( dev, sz ) - Create a reiser4 filesystem on the named device
#
make_reiser4() {

    local SETL=""
    local label="$5"

    show_settings $1 reiser4 $2

    if [ -n "$label" ]; then
        SETL="-l ${label:0:16}"
    fi

    echo "---------------- reiserfs4 $1 -----------------" >> $TMP/format.errs

    echo "y" | \
        mkfs.reiser4 $SETL -b $BLKSIZE -q $1 1> /dev/null 2>> $TMP/format.errs

    return $?
}

do_format() {

    local device="$1"
    local mtpt="$2"
    local fstype="$3"
    local mode="$4"
    local partition="$2"
    local rsrvd="$RSRVD_BLKS"
    local check=""
    local label=""

    sync

    if [ -z "$rsrvd" ]; then rsrvd="0"; fi

    if [ "$mode" = "check" ]; then check="y"; fi

    local model="$(lsblk -dno serial $SELECTED | crunch)"

    if [ -z "$model" ]; then
        model="$(lsblk -dno model $SELECTED | crunch)"
    fi

    model="$(echo "$model" | sed 's/^[^ ]*[ ]//g')"

    if [ "$mtpt" = "/boot" ]; then
        label="BOOT_BRZ${model}"
    elif [ "$mtpt" = "/" ]; then
        label="ROOT_BRZ${model}"
        partition="/ or root"
    fi

    echo_message "TIP_FORMATTING_X_PARTITION((device,$device),(mountpoint,$mtpt),(filesystem,$fstype))"

    make_${fstype} "$device" "$mtpt" "$check" "$rsrvd" "$label"

    return $?
}

#---------------------------------------------------------------------------
# Main starts here ...
#---------------------------------------------------------------------------

DEVICE="$1"
FORMAT_MODE="$2"
FORMAT_SCHEME=$TMP/format.csv

PLATFORM="$(cat $TMP/selected-platform 2> /dev/null)"

if ! is_valid_device "$DEVICE" ; then
    echo_failure "L_NO_DEVICE_SPECIFIED"
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

if ! is_safemode_drive $DEVICE ; then
    echo_error "L_SAFEMODE_DRIVE_SELECTED !"
    exit 1
fi

touch $TMP/mt.errs 2> /dev/null
touch $TMP/umount.errs 2> /dev/null

unlink $TMP/format.errs 2> /dev/null
touch $TMP/format.errs 2> /dev/null

rm -f $TMP/swap-${DRIVE_ID}-activated

#BLKSIZE="$(extract_value scheme-${DRIVE_ID} 'block-size')"
BLKSIZE="4096"
FILESYSTEMS="msdos vfat ext2 ext3 ext4 reiserfs jfs xfs nilfs2"

GPT_MODE="$(extract_value scheme-${DRIVE_ID} 'gpt-mode' 'upper')"
FSTAB_ALL="$(extract_value scheme-${DRIVE_ID} 'fstab-all')"
RSRVD_BLKS="$(extract_value scheme-${DRIVE_ID} 'reserved')"
SECTOR_SIZE="$(extract_value scheme-${DRIVE_ID} 'sector-size')"
DISK_TYPE="$(extract_value scheme-${DRIVE_ID} 'disk-type')"

CRYPTO="$(extract_value crypto-${DRIVE_ID} 'type')"
PASSWORD="$(extract_value crypto-${DRIVE_ID} 'password')"
ENCRYPTED="$(extract_value scheme-${DRIVE_ID} 'encrypted')"

cp $FORMAT_SCHEME $TMP/format-${DRIVE_ID}.csv
cp $FORMAT_SCHEME $TMP/partitions-${DRIVE_ID}.csv

if [ "$DISK_TYPE" = "lvm" -o "$FORMAT_MODE" = "lvm" ]; then

    SELECTED="$(get_lvm_master_drive $DEVICE)"

    if [ -n "$SELECTED" -a "$SELECTED" != "$DEVICE" ]; then
        DEVICE="$SELECTED"
        DRIVE_ID="$(basename $DEVICE)"
    fi

    cp $FORMAT_SCHEME $TMP/lvm-${DRIVE_ID}.csv
fi

if [ ! -f "$FORMAT_SCHEME" ]; then
    echo_failure "L_INVALID_FORMAT_INFO"
    exit 1
fi

if ! is_valid_device "$DEVICE" ; then
    echo_failure "L_INVALID_DEVICE_SPECIFIED"
    exit 1
fi

if ! is_safemode_drive "$DEVICE" "$FORMAT_SCHEME" ; then
    echo_failure "L_INVALID_DEVICE_SPECIFIED"
    exit 1
fi

if [ "$ENCRYPTED" != "yes" ]; then
    if grep -qE ',crypt$' $FORMAT_SCHEME ; then
        echo_error "L_SELECT_CRYPTED_SCHEME"
        echo_failure "L_INVALID_FORMAT_INFO"
        exit 1
    fi
fi

if ! grep -q -m1 -F ',/,' "$FORMAT_SCHEME" ; then
    echo_failure "L_INVALID_FORMAT_INFO"
    exit 1
fi

echo "$DEVICE" 1> $TMP/${DRIVE_ID}-formatted
echo "no" 1> $TMP/${DRIVE_ID}-formatted

unmount_devices "$DEVICE" "$ENCRYPTED"

reorder_rootfs "$FORMAT_SCHEME"

if [ "$DISK_TYPE" = "lvm" -o "$FORMAT_MODE" = "lvm" ]; then
    echo_message "L_ACTIVATING_LVM_PARTITIONS"
    vgchange -ay 2>> $TMP/lvm.errs
    sync
fi

while read line; do

    LABEL=""
    ORIG_DEVICE=""

    PARTITION="$(echo "$line" | cut -f 1 -d',')"
    PTYPE="$(echo "$line" | cut -f 2 -d',')"
    SIZE="$(echo "$line" | cut -f 3 -d',')"
    FSTYPE="$(echo "$line" | cut -f 4 -d',')"
    MTPT="$(echo "$line" | cut -f 5 -d',')"
    MODE="$(echo "$line" | cut -f 6 -d',')"

    DEVICE="$PARTITION"
    DEVID="$(basename $DEVICE)"

    if ! echo "$DEVICE" | grep -qF "$SELECTED" ; then
        echo_failure "L_SCRIPT_MISMATCH_ON_DEVICE"
    fi

    if [ "$MODE" = "ignore" ]; then continue; fi

	echo_progress "((device,$DEVICE),(mountpoint,$MTPT),(filesystem,$FSTYPE))"

    if [ "$MODE" = "crypt" -a "$MTPT" != "/boot" ]; then

        if [ "$ENCRYPTED" = "yes" -a "$CRYPTO" != "encfs" ]; then

            if [ "$SUSPEND2DISK" = "no" ] &&
                [ "$PTYPE" = "8200" -o "$PTYPE" = "82" -o "$FSTYPE" = "swap" ]; then
                LABEL="${MTPT}_${IDX}"
                echo "$LABEL" > $TMP/crypto-$MTPT
                mkfs.ext2 -L "$LABEL" $DEVICE 1M
                IDX=$(( $IDX + 1 ))
            fi

            echo_message "TIP_CRYPTING_X_PARTITION((device,$DEVICE),(mountpoint,$MTPT),(filesystem,$FSTYPE))"

            ORIG_DEVICE="$DEVICE"

            cryptofn="init_crypto_${CRYPTO}"

            declare -F $cryptofn

            if [ "$MTPT" = "/" ]; then
                DEVICE="$($cryptofn $SELECTED $DEVICE format $MTPT "$PASSWORD" "$LABEL")"
            else
                DEVICE="$($cryptofn $SELECTED $DEVICE format $MTPT "" "$LABEL")"
            fi

            if [ $? != 0 ]; then
                echo_failure "L_CRYPTO_FORMATTING_FAILED"
                exit 1
            fi
        fi
    fi

    if [ "$PTYPE" = "8200" -o "$PTYPE" = "82" -o "$FSTYPE" = "swap" ]; then

        activate_swap "$DEVICE" "$DRIVE_ID"

        track_mountpoint "$DRIVE_ID" \
			"$DEVICE" "$MTPT" "$FSTYPE" "$PTYPE" "$MODE" "$CRYPTO" "$PARTITION" "$LABEL"

        continue
    fi

    if [ "$MODE" = "skip" -o "$MODE" = "keep" ]; then

        track_mountpoint "$DRIVE_ID" \
			"$DEVICE" "$MTPT" "$FSTYPE" "$PTYPE" "$MODE" "$CRYPTO" "$PARTITION"

        continue
    fi

    do_format "$DEVICE" "$MTPT" "$FSTYPE" "$MODE"

    if [ $? != 0 ]; then
        echo_failure "L_FORMATTING_FAILED"
        exit 1
    fi

    if [ -n "$ORIG_DEVICE" -a -z "$LABEL" ]; then
        if ! store_uuid_cryptokey "$SELECTED" "$ORIG_DEVICE" ; then
            echo_failure "L_BAD_DEVICE_UUID"
            exit 1
        fi
    fi

    if grep -q -i 'bad sector' $TMP/format.errs ; then
        echo_failure "L_BAD_SECTORS_FOUND"
        exit 1
    fi

    track_mountpoint "$DRIVE_ID" \
		"$DEVICE" "$MTPT" "$FSTYPE" "$PTYPE" "$MODE" "$CRYPTO" "$PARTITION"

done < "$FORMAT_SCHEME"

if [ $? = 0 ]; then
    echo "$DEVICE" >> $TMP/drives-formatted.lst
	wc -l $TMP/drives-formatted.lst | \
		cut -f1 -d' ' 1> $TMP/nb-target-drives
fi

exit 0

# end Breeze::OS script
