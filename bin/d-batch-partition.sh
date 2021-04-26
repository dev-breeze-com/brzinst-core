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
#
. d-dirpaths.sh

. d-format-utils.sh

. d-crypto-utils.sh

mbr_removal() {
#    Next version ...
#    sfdisk --dump ${harddrive} 1> "$SAVELOG".dump
#    or fdisk -O "$SAVELOG" ${harddrive}
#    sleep 1
    sync
    return 0
}

set_partitioning_scheme() {

    local bootable=", bootable"
    local harddrive="$1"
    local scheme="$2"
    local custom="$3"
    local sectors=""
    local start=""

    cat $FDISK_SCHEME < EOF
label: dos
device: $harddrive
unit: sectors
EOF

    while read line; do
        local partition="$(echo "$line" | cut -f1 -d,)"
        local size="$(echo "$line" | cut -f3 -d,)"
        local fstype="$(echo "$line" | cut -f4 -d,)"

        if [ "$custom" = "yes" ]; then
            printf "%s : start=%-16s, size=%-16sM, type=%-10s${bootable}\n" \
                $partition $size $fstype >> $FDISK_SCHEME
        else
            sectors=$(( $size * $FACTOR ))
            printf "%s : start=%-16s, size=%-16sM, type=%-10s${bootable}\n" \
                $partition $size $fstype >> $FDISK_SCHEME
            echo "$START,$SECTORS,L" >> $FDISK_SCHEME
        fi
        bootable=""
    done < $scheme

    return 0
}

fdisk_partitioning() {

    local harddrive="$1"
    local custom="$2"
    local ssd="$(is_drive_ssd $harddrive)"

    sync # Sync drives

    if [ "$custom" = "yes" ]; then

        if [ "$SECTOR_SIZE" = "4K" ]; then
            fdisk -H 224 -S 56 -B $FDISK_SCHEME ${harddrive} \
                1> $TMP/fdisk.log 2>> $TMP/fdisk.errs

        elif [ "$ssd" = "yes" ]; then
            fdisk -H 32 -S 32 -B $FDISK_SCHEME ${harddrive} \
                1> $TMP/fdisk.log 2>> $TMP/fdisk.errs
        else
            fdisk -B $FDISK_SCHEME ${harddrive} \
                1> $TMP/fdisk.log 2>> $TMP/fdisk.errs
        fi
    else
        if [ "$SECTOR_SIZE" = "4K" ]; then
            sfdisk -H 224 -S 56 ${harddrive} < $FDISK_SCHEME \
                1> $TMP/fdisk.log 2>> $TMP/fdisk.errs

        elif [ "$ssd" = "yes" ]; then
            sfdisk -H 32 -S 32 ${harddrive} < $FDISK_SCHEME \
                1> $TMP/fdisk.log 2>> $TMP/fdisk.errs
        else
            sfdisk ${harddrive} < $FDISK_SCHEME \
                1> $TMP/fdisk.log 2>> $TMP/fdisk.errs
        fi
    fi

    return $?
}

mbr_partitioning() {

    local harddrive="$1"
    local custom="$(custom_fdisk_in_use)"

    #if echo "$DISK_TYPE" | grep -qF 'bsd' ; then
    #fi

    if ! set_partitioning_scheme ${harddrive} ${OUTPUT_SCHEME} ${custom} ; then
        return 1
    fi

    if ! fdisk_partitioning ${harddrive} ${custom} ; then
        sync; sleep 1

        if ! grep -qiF 'device or resource busy' $TMP/fdisk.log ; then
            return 1
        fi

        #partx --add --nr 5: $harddrive
        #sync; sleep 1
    fi

    N1="$(fdisk -l ${harddrive} | grep -E '^/dev/' | wc -l | cut -f1 -d' ')"
    N2="$(cat $FDISK_SCHEME | wc -l | cut -f1 -d' ')"

    if [ "$N1" = "$N2" ]; then
        sync; sleep 1
        return 0
    fi

    return 1
}

gpart_removal() {

    local harddrive="$1"

    gpart destroy -f C -F "$harddrive" 1> gpart.log 2>> $TMP/gpart.errlog

    if [ "$?" != 0 -a "$?" != 2 ]; then
        echo "Zapping all partition information failed ! "
        echo_failure "L_GPART_ZAPPING_FAILED"
        return 1
    fi

    sync
    return 0
}

gpt_removal() {

    local harddrive="$1"

#    sgdisk --mbrtogpt --backup "$SAVELOG" ${harddrive} 2> $TMP/sgdisk.errlog
#
#    if [ "$?" != 0 ]; then
#        echo "Backing-up of partition information failed ! "
#        return 1
#    fi
#
#    while read line; do
#
#        mode="$(echo "$line" | cut -f 6 -d ',')"
#        device="$(echo "$line" | cut -f 1 -d ',')"
#        partno="$(echo "$device" | sed 's/[a-z\/]*//g')"
#
#        sgdisk -d $partno "${harddrive}" \
#            1>> $TMP/sgdisk.log 2>> $TMP/sgdisk.errs
#
#        if [ "$?" = 3 ]; then
#            sgdisk -g -d $partno "${harddrive}" \
#                1>> $TMP/sgdisk.log 2>> $TMP/sgdisk.errs
#        fi
#
#        if [ "$?" != 0 ]; then
#            echo "Could not remove partition $partition ! "
#            echo_failure "L_GPT_PARTITION_REMOVAL_FAILED"
#            return 1
#        fi
#    done < "$TMP/drive-info-${DRIVE_ID}.csv"

    echo "------------ GPT REMOVAL ----------------" 1>> $TMP/sgdisk.log
    echo "------------ GPT REMOVAL ----------------" 2>> $TMP/sgdisk.errs

    while read line; do
        #mode="$(echo "$line" | cut -f 6 -d ',')"
        device="$(echo "$line" | cut -f 1 -d ',')"
        partno="$(echo "$device" | sed 's/[a-z\/]*//g')"
        partx --delete $device $harddrive
    done < $OUTPUT_SCHEME

    sgdisk --mbrtogpt --zap ${harddrive} \
        1>> $TMP/sgdisk.log 2>> $TMP/sgdisk.errs

    if [ "$?" != 0 -a "$?" != 2 ]; then
        echo "Zapping all partition information failed ! "
        echo_failure "L_GPT_ZAPPING_FAILED"
        return 1
    fi

    sgdisk --mbrtogpt --zap-all ${harddrive} \
        1>> $TMP/sgdisk.log 2>> $TMP/sgdisk.errs

    if [ "$?" != 0 -a "$?" != 2 ]; then
        echo "Zapping all partition information failed ! "
        echo_failure "L_GPT_ZAPPING_FAILED"
        return 1
    fi

    sync
    return 0
}

gpt_partitioning() {

    # Default sector alignment is 2048 => 8.4M bytes for 4K drives
    #
    local size=0
    local line=""
    local partno=1
    local sectors=0
    local end_sector=0
    local start_sector=0
    local alignment=2048
    local harddrive="$1"
    #local factor=$(( 1024000 / 512 )) # by the logical sector size
    local factor=$(( 1048576 / 512 )) # by the logical sector size
    local max_partitions="$(wc -l "$OUTPUT_SCHEME" | cut -f1 -d' ' | crunch)"

    echo "------------ GPT PARTITION ----------------" 1>> $TMP/sgdisk.log
    echo "------------ GPT PARTITION ----------------" 2>> $TMP/sgdisk.errs

    while read line; do

        device="$(echo "$line" | cut -f 1 -d ',')"
        ptype="$(echo "$line" | cut -f 2 -d ',')"
        size="$(echo "$line" | cut -f 3 -d ',')"
        fstype="$(echo "$line" | cut -f 4 -d ',')"
        mtpt="$(echo "$line" | cut -f 5 -d ',')"
        mode="$(echo "$line" | cut -f 6 -d ',')"

        echo_progress "((device,$device),(mountpoint,$mtpt),(filesystem,$fstype))"

        if [ "${#ptype}" = 2 ]; then
            ptype="${ptype}00"
        fi

        if [ "$ptype" = "8500" -o "$ptype" = "85" ]; then
            partno=$(( $partno + 1 ))
            continue
        fi

        start_sector=0
        sectors=$(( $size * $factor ))

        if test $partno -lt $max_partitions; then
            end_sector=$(( $end_sector + $sectors + $alignment ))
        else
            end_sector=0
        fi

        if [ "$ptype" = "EFI" -o "$ptype" = "UEFI" ]; then
            FSTYPE="$partno:0xEF00"
        elif [ "$ptype" = "BBP" ]; then
            FSTYPE="$partno:0xEF02"

            # If Windows is to boot from a GPT disk,
            # a partition of type Microsoft Reserved
            # (sgdisk internal code 0x0C01) is recommended
            # GPT fdisk Manual (8)
            # Retype the bios partition to an MSR one
            # Not feasible if Grub is used.
#            if [ "$GPT_MODE" = "UEFI" ]; then
#                FSTYPE="$partno:0x0C01"
#            fi
        elif [ "$ptype" = "GPT" -o "$ptype" = "ee00" -o "$ptype" = "EE00" ]; then
            FSTYPE="$partno:0xEE"
        elif [ "$fstype" = "SWAP" ]; then
            FSTYPE="$partno:0x8200"
        elif [ "$ptype" = "LVM" ]; then
            FSTYPE="$partno:0x8E00"
        elif [ "$ptype" = "RAID" ]; then
            FSTYPE="$partno:0xFD00"
        else
            FSTYPE="$partno:0x$ptype"
        fi

        echo_message "L_CREATING_X_PARTITION((partition,$device))"

        sgdisk --set-alignment=$alignment \
            --new=$partno:$start_sector:$end_sector \
            --typecode=$FSTYPE $harddrive \
            1>> $TMP/sgdisk.log 2>> $TMP/sgdisk.errs

        if [ "$?" != 0 ]; then
            echo "Could not partition drive $harddrive"
            echo_failure "L_PARTITIONING_FAILURE"
            return 1
        fi

        if [ "$mtpt" = "/boot" ]; then
            # Required by syslinux to set the active partition
            sgdisk --attributes=${partno}:set:2 $harddrive \
                1>> $TMP/sgdisk.log 2>> $TMP/sgdisk.errs
        fi

        #partx --add --nr $partno $harddrive
        partno=$(( $partno + 1 ))

#        if echo "$DISK_TYPE" | grep -qF "bsd" ; then
#            if echo "$ptype" | grep -qE "^a[569]" ; then
#                partno=$(( $partno + 1 ))
#                continue
#            fi
#        fi
    done < "$OUTPUT_SCHEME"

    sync
    return 0
}

gpart_partitioning() {

    local size=0
    local line=""
    local partno=1
    local alignment=""
    local harddrive="$1"
    local factor=$(( 1024000 / 512 )) # by the logical sector size
    local max_partitions="$(wc -l "$OUTPUT_SCHEME" | cut -f1 -d' ' | crunch)"

    echo "------------ GPT PARTITION ----------------" 1>> $TMP/sgdisk.log
    echo "------------ GPT PARTITION ----------------" 2>> $TMP/sgdisk.errs

    gpart create -s gpt $harddrive

    if [ "$SECTOR_SIZE" = "4K" ]; then
        alignment="-a 4k"
    fi

    while read line; do

        device="$(echo "$line" | cut -f 1 -d ',')"
        ptype="$(echo "$line" | cut -f 2 -d ',')"
        size="$(echo "$line" | cut -f 3 -d ',')"
        fstype="$(echo "$line" | cut -f 4 -d ',')"
        mtpt="$(echo "$line" | cut -f 5 -d ',')"
        mode="$(echo "$line" | cut -f 6 -d ',')"

        echo_progress "((device,$device),(mountpoint,$mtpt),(filesystem,$fstype))"

        if test "$partno" -eq 4; then
            partno=$(( $partno + 1 ))
            continue
        fi

        if [ "$ptype" = "EFI" -o "$ptype" = "UEFI" ]; then
            FSTYPE="-t efi -l breezeos-efi"
        elif [ "$ptype" = "BBP" ]; then
            FSTYPE="$partno:0xEF02"
            # If Windows is to boot from a GPT disk,
            # a partition of type Microsoft Reserved
            # (sgdisk internal code 0x0C01) is recommended
            # GPT fdisk Manual (8)
            # Retype the bios partition to an MSR one
            # Not feasible if Grub is used.
#            if [ "$GPT_MODE" = "UEFI" ]; then
#                FSTYPE="$partno:0x0C01"
        elif [ "$ptype" = "GPT" -o "$ptype" = "ee00" -o "$ptype" = "EE00" ]; then
            FSTYPE="$partno:0xEE"
        elif [ "$fstype" = "SWAP" ]; then
            FSTYPE="-t ffs -l breezeos-swap"
        elif [ "$ptype" = "LVM" ]; then
            FSTYPE="$partno:0x8E00"
        elif [ "$ptype" = "RAID" ]; then
            FSTYPE="$partno:0xFD00"
        else
            FSTYPE="$partno:0x$ptype"
        fi

        echo_message "L_CREATING_X_PARTITION((partition,$device))"

        gpart add $alignment $FSTYPE -s $size $harddrive \
            1>> $TMP/gpart.log 2>> $TMP/gpart.errs

        if [ "$?" != 0 ]; then
            echo "Could not partition drive $harddrive"
            echo_failure "L_PARTITIONING_FAILURE"
            return 1
        fi

        partno=$(( $partno + 1 ))

    done < "$OUTPUT_SCHEME"

    sync
    return 0
}

mkfs_label() {

    local size=0
    local line=""
    local partno=1
    local harddrive="$1"
    local factor=$(( 1024000 / 512 )) # by the logical sector size
    local max_partitions="$(wc -l "$OUTPUT_SCHEME" | cut -f1 -d' ' | crunch)"

    echo "------------ GPT PARTITION ----------------" 1>> $TMP/sgdisk.log
    echo "------------ GPT PARTITION ----------------" 2>> $TMP/sgdisk.errs

    while read line; do

        if test $partno -lt 5 ; then
            partno=$(( $partno + 1 ))
            continue
        fi

        device="$(echo "$line" | cut -f 1 -d ',')"
        ptype="$(echo "$line" | cut -f 2 -d ',')"
        size="$(echo "$line" | cut -f 3 -d ',')"
        fstype="$(echo "$line" | cut -f 4 -d ',')"
        mtpt="$(echo "$line" | cut -f 5 -d ',')"
        mode="$(echo "$line" | cut -f 6 -d ',')"

        echo_progress "((device,$device),(mountpoint,$mtpt),(filesystem,$fstype))"

        if [ "$DISK_TYPE" = "openbsd" ]; then
            disklabel --add --nr $partno $harddrive
        elif [ "$DISK_TYPE" = "freebsd" ]; then
            disklabel --add --nr $partno $harddrive
        elif [ "$DISK_TYPE" = "netbsd" ]; then
            disklabel --add --nr $partno $harddrive
        fi

        partno=$(( $partno + 1 ))

    done < "$OUTPUT_SCHEME"

    return 0
}

# Main starts here ...
DEVICE="$1"

if ! is_valid_device "$DEVICE" ; then
    echo_failure "L_NO_DEVICE_SPECIFIED"
    exit 1
fi

DRIVE_ID="$(basename $1)"

SELECTED="$(cat $TMP/selected-drive 2> /dev/null)"

if [ -z "$SELECTED" -o "$SELECTED" != "$DEVICE" ]; then
    echo_failure "L_SCRIPT_MISMATCH_ON_DEVICE"
    exit 1
fi

if ! check_settings_file "scheme-${DRIVE_ID}" ; then
    echo_failure "L_MISSING_SCHEME_FILE"
    exit 1
fi

SELECTED="$(extract_value scheme-${DRIVE_ID} 'device' 2> /dev/null)"

if [ -z "$SELECTED" -o "$SELECTED" != "$DEVICE" ]; then
    echo_failure "L_SCRIPT_MISMATCH_ON_DEVICE"
    exit 1
fi

SCHEME="$(extract_value scheme-${DRIVE_ID} 'scheme' 2> /dev/null)"
SECTOR_SIZE="$(extract_value scheme-${DRIVE_ID} 'sector-size' 2> /dev/null)"
GPT_MODE="$(extract_value scheme-${DRIVE_ID} 'gpt-mode' 2> /dev/null)"
DRIVE_TOTAL="$(extract_value scheme-${DRIVE_ID} 'disk-size' 2> /dev/null)"

if [ -z "$DRIVE_TOTAL" -o -z "$SCHEME" ]; then
    echo_failure "L_MISSING_DRIVE_NAME"
    exit 1
fi

DISK_TYPE="$(extract_value scheme-${DRIVE_ID} 'disk-type')"
ENCRYPTED="$(extract_value scheme-${DRIVE_ID} 'encrypted')"

FDISK_SCHEME="$TMP/fdisk-${DRIVE_ID}-scheme"
OUTPUT_SCHEME="$TMP/partitions-${DRIVE_ID}.csv"

cp -a ${OUTPUT_SCHEME}.new $OUTPUT_SCHEME

if ! is_safemode_drive "$DEVICE" "$OUTPUT_SCHEME" ; then
    echo_error "L_SAFEMODE_DRIVE_SELECTED !"
    exit 1
fi

unmount_devices "$DEVICE" "$ENCRYPTED"

if [ "$DISK_TYPE" = "lvm" -o "$DISK_TYPE" = "lvmcrypto" ]; then
    # Scanning LVM volume groups on the selected drive, if any
    d-lvm-info.sh ${DEVICE} pv scan 1> $TMP/lvm-physical.csv 2>> $TMP/lvml.errs

    # Removing LVM volume groups on the selected drive, if any
    d-batch-lvm.sh ${DEVICE} remove pv 1>> $TMP/lvm-removal.log 2>> $TMP/lvm-del.errs
fi

SAVELOG="$TMP/sectors_${GPT_MODE}_${DRIVE_ID}.sav"

#if ! echo "$DEVICE" | grep -qF '/dev/sda' ; then
#    exit 1
#fi

if is_gpt_drive "$DEVICE" "$DISK_TYPE" ; then
    if [ "$BREEZE_PLATFORM" = "freebsd" -o "$DISK_TYPE" = "freebsd" ]; then
        gpart_removal ${DEVICE}
    elif echo "$DISK_TYPE" | grep -qF "bsd" ; then
        gpt_removal ${DEVICE}
    else
        gpt_removal ${DEVICE}
    fi
else
    mbr_removal ${DEVICE}
fi

if [ $? = 0 ]; then

    echo_message "L_ERASING_BOOT_SECTOR"

    if [ "$SECTOR_SIZE" = "4K" ]; then
        dd if=/dev/zero of=$DEVICE bs=4096 count=1 2> /dev/null
    else
        dd if=/dev/zero of=$DEVICE bs=512 count=1 2> /dev/null
    fi

    echo_message "L_PARTITIONING_DRIVE"

    if [ "$GPT_MODE" = "MBR" ]; then
        mbr_partitioning ${DEVICE}
    else
        OFFSET=$(blockdev --getsize64 $DEVICE)
        # Because of a bug in gdisk (v0.6.10), we do the following:
        dd if=/dev/zero bs=512 count=1 seek=$(( $OFFSET / 512 - 1 )) \
            of=$DEVICE 2> /dev/null

        if [ "$DISK_TYPE" = "freebsd" ]; then
            gpart_partitioning ${DEVICE}
        else
            gpt_partitioning ${DEVICE}
        fi
    fi
fi

if [ $? = 0 ]; then
    if echo "$DISK_TYPE" | grep -qF "bsd" ; then
        mkfs_label $DEVICE $OUTPUT_SCHEME
    fi
fi

if [ $? = 0 ]; then
    echo "$DEVICE" >> $TMP/drives-partitioned.lst
fi

#if [ -f "$SAVELOG" ]; then
#    sgdisk --load-backup "$SAVELOG" $DEVICE 
#fi

exit $?

# end Breeze::OS setup script
