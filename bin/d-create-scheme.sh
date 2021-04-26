#!/bin/bash
#
# GNU GENERAL PUBLIC LICENSE Version 3
#
# Copyright 2016 Pierre Innocent, Tsert Inc., All Rights Reserved
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

get_percentage()
{
    local mtpt="$2"
    local partition="$3"
    local path="$BRZDIR/data/scheme-${1}.csv"
    local nb_part=$(( $MAX_PARTITIONS - $MIN_PARTITIONS ))
    local value=""

    if [ -z "$partition" ]; then
        partition="$(basename $mtpt)"
    fi

    local percent=$(grep -F ",$partition" $path | cut -f2 -d',' | crunch)

    if [ -z "$percent" -o "$percent" = "0" ]; then
        percent=100
        if test "$nb_part" -gt 0 ; then
            percent=$(( 100 / $nb_part ))
        fi
    fi

#    if [ "$DRIVE_SIZE" != "$EXTENDED_SIZE" ]; then
#        nb_part=$(( $MAX_PARTITIONS - $MIN_PARTITIONS_PLUS1 ))
#        percent=$(( 100 / $nb_part ))
    if [ "$mtpt" = "/home" ]; then
        percent=$PERCENT_TOTAL
    fi
    echo "$percent"
    return 0
}

set_partition_names()
{
    local scheme="$1"
    local partition=""
    local path="$BRZDIR/data/scheme-${1}.csv"
    local idx="0"

    eval PARTITIONS${idx}="boot"

    idx=$(( $idx + 1 ))
    eval PARTITIONS${idx}="boot"

    idx=$(( $idx + 1 ))
    eval PARTITIONS${idx}="bios"

    if [ "$DISK_TYPE" = "lvm" ]; then
        idx=$(( $idx + 1 ))
        eval PARTITIONS${idx}="dummy"
    elif echo "$DISK_TYPE" | grep -qF "bsd" ; then
        idx=$(( $idx + 1 ))
        eval PARTITIONS${idx}="dummy"
    else
        idx=$(( $idx + 1 ))
        eval PARTITIONS${idx}="swap"
    fi

    idx=$(( $idx + 1 ))

    if echo "$DISK_TYPE" | grep -qF "bsd" ; then
        eval PARTITIONS${idx}="$DISK_TYPE"
    else
        eval PARTITIONS${idx}="extended"
    fi

    #idx=$(( $idx + 1 ))
    #eval PARTITIONS${idx}="root"

    while read line ; do
        partition="$(echo $line | cut -f3 -d,)"

        if test $idx -eq 4 ; then
            if [ "$partition" != "root" ]; then
                echo "INSTALLER: FAILURE L_ROOT_MUST_BE_DECLARED_FIRST"
                exit 1
            fi
        fi

        idx=$(( $idx + 1 ))
        eval PARTITIONS${idx}="$partition"

        if test $idx -eq 5 ; then
            if echo "$DISK_TYPE" | grep -qF "bsd" ; then
                idx=$(( $idx + 1 ))
                eval PARTITIONS${idx}="swap"
            fi
        fi
    done < $path

    MAX_PARTITIONS=${idx}

#    if [ "$DISK_TYPE" != "lvm" -a "$partition" != "home" ]; then
#        echo "INSTALLER: FAILURE L_HOME_MUST_BE_DECLARED_LAST"
#        exit 1
#    fi

    MIN_PARTITIONS=4
    MIN_PARTITIONS_PLUS1=5
    MAX_PARTITIONS=${idx}

    return 0
}

sizeup_partition_boot()
{
    local IDX="$1"
    local SIZE="$2"
    local FS_TYPE="$4"

    if [ "$ARG" != "modify" ]; then
        SIZE=$BOOT_SIZE
        FS_TYPE="$FSTYPE"
    fi

    SECTORS=$(( $SIZE * $FACTOR ))

    if [ "$SCHEME" = "usb-backup" ]; then
        SECTORS=$(( $DISK_SIZE * $FACTOR ))
        echo "$START,+,0B," >> $FDISK_SCHEME
        if [ "$ARG" != "modify" ]; then
            echo "/dev/${DRIVE_ID}${IDX},EF00,$DISK_SIZE,vfat,/,format" >> $OUTPUT_SCHEME
        fi
    elif [ "$GPT_MODE" = "UEFI" -o "$SCHEME" = "usb-install" ]; then
        echo "$START,$SECTORS,EF,*" >> $FDISK_SCHEME
        if [ "$ARG" != "modify" ]; then
            echo "/dev/${DRIVE_ID}${IDX},EF00,$SIZE,vfat,/boot,format" >> $OUTPUT_SCHEME
        fi
    elif [ "$GPT_MODE" = "GPT" ]; then
        echo "$START,$SECTORS,EE,*" >> $FDISK_SCHEME
        if [ "$ARG" != "modify" ]; then
            echo "/dev/${DRIVE_ID}${IDX},EE00,$SIZE,$FS_TYPE,/boot,format" >> $OUTPUT_SCHEME
        fi
    else
        echo "$START,$SECTORS,L,*" >> $FDISK_SCHEME
        if [ "$ARG" != "modify" ]; then
            echo "/dev/${DRIVE_ID}${IDX},EF01,$SIZE,$FS_TYPE,/boot,format" >> $OUTPUT_SCHEME
        fi
    fi
    return 0
}

sizeup_partition_dummy()
{
    local IDX="$1"
    local SIZE="$2"

    START=$(( $START + $SECTORS ))
    START=$(( $START / 8 * 8 + $OFFSET ))

    if [ -z "$SIZE" ]; then SIZE=$DUMMY_SIZE; fi

    if [ "$ARG" != "modify" ]; then

        if echo "$DISK_TYPE" | grep -qF "bsd" ; then
            echo "/dev/${DRIVE_ID}${IDX},0c01,$SIZE,none,/none,ignore" >> $OUTPUT_SCHEME
        else
            echo "/dev/${DRIVE_ID}${IDX},8300,$SIZE,none,/none,ignore" >> $OUTPUT_SCHEME
        fi
    fi

    SECTORS=$(( $SIZE * $FACTOR ))
    echo "$START,$SECTORS,L" >> $FDISK_SCHEME

    return 0
}

sizeup_partition_bios()
{
    local IDX="$1"
    local SIZE="$2"

    START=$(( $START + $SECTORS ))
    START=$(( $START / 8 * 8 + $OFFSET ))

    if [ -z "$SIZE" ]; then
        SIZE=$BIOS_SIZE
        SECTORS=$(( $SIZE * $FACTOR ))
    fi

    if [ "$ARG" != "modify" ]; then
        if [ "$SCHEME" = "usb-install" ]; then
            echo "/dev/${DRIVE_ID}${IDX},EF02,$SIZE,msdos,/none,format" >> $OUTPUT_SCHEME
            echo "$START,$SECTORS,EF" >> $FDISK_SCHEME
        else
            echo "/dev/${DRIVE_ID}${IDX},EF02,$SIZE,none,/none,ignore" >> $OUTPUT_SCHEME
            echo "$START,$SECTORS,L" >> $FDISK_SCHEME
        fi
    else
        echo "$START,$SECTORS,L" >> $FDISK_SCHEME
    fi

    SECTORS=$(( $SIZE * $FACTOR ))
    return 0
}

sizeup_partition_swap()
{
    local IDX="$1"
    local SIZE="$2"

    START=$(( $START + $SECTORS ))
    START=$(( $START / 8 * 8 + $OFFSET ))

    if [ -z "$SIZE" ]; then SIZE=$SWAP_SIZE; fi

    if [ "$ARG" != "modify" ]; then
        if [ "$DISK_TYPE" = "freebsd" ]; then
            echo "/dev/${DRIVE_ID}${IDX},a502,$SIZE,swap,/swap,format" >> $OUTPUT_SCHEME
        elif [ "$DISK_TYPE" = "netbsd" ]; then
            echo "/dev/${DRIVE_ID}${IDX},a901,$SIZE,swap,/swap,format" >> $OUTPUT_SCHEME
        elif [ "$DISK_TYPE" = "openbsd" ]; then
            echo "/dev/${DRIVE_ID}${IDX},a6,$SIZE,swap,/swap,format" >> $OUTPUT_SCHEME
        else
            echo "/dev/${DRIVE_ID}${IDX},8200,$SIZE,swap,/swap,format" >> $OUTPUT_SCHEME
        fi
    fi

    SECTORS=$(( $SIZE * $FACTOR ))
    echo "$START,$SECTORS,S" >> $FDISK_SCHEME

    return 0
}

sizeup_partition_extended()
{
    local IDX="$1"
    local SIZE="$2"

    START=$(( $START + $SECTORS ))
    START=$(( $START / 8 * 8 + $OFFSET ))

    if [ "$ARG" != "modify" ]; then
        SIZE=$(( $EXTENDED_SIZE / 8 * 8 ))
        echo "/dev/${DRIVE_ID}${IDX},8500,$SIZE,extended,/none,ignore" >> $OUTPUT_SCHEME
    fi
    echo "$START,+,E" >> $FDISK_SCHEME
    return 0
}

sizeup_partition_netbsd()
{
    local IDX="$1"
    local SIZE="$2"

    START=$(( $START + $SECTORS ))
    START=$(( $START / 8 * 8 + $OFFSET ))

    if [ "$ARG" != "modify" ]; then
        SIZE=$(( $EXTENDED_SIZE / 8 * 8 ))
        echo "/dev/${DRIVE_ID}${IDX},a9,$SIZE,netbsd,/none,ignore" >> $OUTPUT_SCHEME
    fi
    echo "$START,+,a9" >> $FDISK_SCHEME
    return 0
}

sizeup_partition_freebsd()
{
    local IDX="$1"
    local SIZE="$2"

    START=$(( $START + $SECTORS ))
    START=$(( $START / 8 * 8 + $OFFSET ))

    if [ "$ARG" != "modify" ]; then
        SIZE=$(( $EXTENDED_SIZE / 8 * 8 ))
        echo "/dev/${DRIVE_ID}${IDX},a5,$SIZE,freebsd,/none,ignore" >> $OUTPUT_SCHEME
    fi
    echo "$START,+,a5" >> $FDISK_SCHEME
    return 0
}

sizeup_partition_openbsd()
{
    local IDX="$1"
    local SIZE="$2"

    START=$(( $START + $SECTORS ))
    START=$(( $START / 8 * 8 + $OFFSET ))

    if [ "$ARG" != "modify" ]; then
        SIZE=$(( $EXTENDED_SIZE / 8 * 8 ))
        echo "/dev/${DRIVE_ID}${IDX},a6,$SIZE,openbsd,/none,ignore" >> $OUTPUT_SCHEME
    fi
    echo "$START,+,a6" >> $FDISK_SCHEME
    return 0
}

sizeup_partition_root()
{
    local IDX="$1"
    local SIZE="$2"
    local FS_MTPT="$3"
    local FS_TYPE="$4"
    local PERCENT=20

    if [ -z "$SIZE" ]; then SIZE=$DRIVE_SIZE; fi

    if [ -z "$FS_MTPT" ]; then FS_MTPT="/"; fi

    if [ "$SCHEME" = "root" -o "$SCHEME" = "usb-install" ]; then

        if [ "$ARG" != "modify" ]; then
            FS_TYPE="$FSTYPE"
            SIZE=$(( $DRIVE_SIZE / 8 * 8 ))
            echo "/dev/${DRIVE_ID}${IDX},$PART_TYPE,$SIZE,$FS_TYPE,/,format" >> $OUTPUT_SCHEME
        fi

        if ! echo "$DISK_TYPE" | grep -qF "bsd" ; then
            echo ",+,$PT_TYPE" >> $FDISK_SCHEME
        fi

        return 0
    fi

    if [ "$ARG" = "modify" ]; then
        SECTORS=$(( $SIZE * $FACTOR - 2048 ))
    else
        FS_TYPE="$FSTYPE"
        PERCENT=$(get_percentage "$SCHEME" $FS_MTPT root)
        PERCENT_TOTAL=$(( $PERCENT_TOTAL - $PERCENT ))

        SECTORS=$(( $DRIVE_SIZE * $PERCENT / 100 * $FACTOR / 8 * 8 - 2048 ))
        SIZE=$(( $DRIVE_SIZE * $PERCENT / 100 / 8 * 8 ))
        echo "/dev/${DRIVE_ID}${IDX},$PART_TYPE,$SIZE,$FS_TYPE,/,format" >> $OUTPUT_SCHEME
    fi

    if ! echo "$DISK_TYPE" | grep -qF "bsd" ; then
        echo ",$SECTORS,$PT_TYPE" >> $FDISK_SCHEME
    fi

    return 0
}

sizeup_partition_home()
{
    local IDX="$1"
    local SIZE="$2"
    local FS_MTPT="$3"
    local FS_TYPE="$4"
    local PERCENT=20

    if [ -z "$SIZE" ]; then SIZE=$DRIVE_SIZE; fi

    if [ "$ARG" = "modify" ]; then
        SECTORS=$(( $SIZE * $FACTOR - 2048 ))
    else
        FS_MTPT="/home"
        FS_TYPE="$FSTYPE"
        PERCENT=$(get_percentage "$SCHEME" $FS_MTPT)
        PERCENT_TOTAL=$(( $PERCENT_TOTAL - $PERCENT ))

        SECTORS=$(( $DRIVE_SIZE * $PERCENT / 100 * $FACTOR / 8 * 8 - 2048 ))
        SIZE=$(( $DRIVE_SIZE * $PERCENT / 100 / 8 * 8 ))
        echo "/dev/${DRIVE_ID}${IDX},$PART_TYPE,$SIZE,$FS_TYPE,$FS_MTPT,format" >> $OUTPUT_SCHEME
    fi

    if ! echo "$DISK_TYPE" | grep -qF "bsd" ; then
        echo ",+,$PT_TYPE" >> $FDISK_SCHEME
    fi

    return 0
}

sizeup_partition_X()
{
    local IDX="$1"
    local SIZE="$2"
    local FS_MTPT="$3"
    local FS_TYPE="$4"
    local PERCENT=20

    if [ -z "$FS_TYPE" ]; then FS_TYPE="$FSTYPE"; fi

    if [ -z "$SIZE" ]; then SIZE=$DRIVE_SIZE; fi

    if [ "$ARG" = "modify" ]; then
        SECTORS=$(( $SIZE * $FACTOR - 2048 ))
    else
        PERCENT=$(get_percentage "$SCHEME" $FS_MTPT)
        PERCENT_TOTAL=$(( $PERCENT_TOTAL - $PERCENT ))

        SECTORS=$(( $SIZE * $PERCENT / 100 * $FACTOR / 8 * 8 - 2048 ))
        SIZE=$(( $SIZE * $PERCENT / 100 / 8 * 8 ))
        echo "/dev/${DRIVE_ID}${IDX},$PART_TYPE,$SIZE,$FS_TYPE,$FS_MTPT,format" >> $OUTPUT_SCHEME
    fi

    if ! echo "$DISK_TYPE" | grep -qF "bsd" ; then
        echo ",$SECTORS,$PT_TYPE" >> $FDISK_SCHEME
    fi

    return 0
}

modify_scheme()
{
    local IDX=1
    local line=""
    local size=""
    local fstype=""
    local scheme="$1"
    local funcname=""

    if [ "$DISK_TYPE" = "raid" ]; then
        PART_TYPE=FD00
        PT_TYPE=FD
    elif [ "$DISK_TYPE" = "lvm" ]; then
        PART_TYPE=8E00
        PT_TYPE=8E
    elif [ "$DISK_TYPE" = "openbsd" ]; then
        PART_TYPE=a600
        PT_TYPE=a6
    elif [ "$DISK_TYPE" = "freebsd" ]; then
        PART_TYPE=a500
        PT_TYPE=a5
    elif [ "$DISK_TYPE" = "netbsd" ]; then
        PART_TYPE=a900
        PT_TYPE=a9
    else
        PART_TYPE=8300
        PT_TYPE=83
    fi

    while read line ; do

        size="$(echo "$line" | cut -f3 -d',')"
        fstype="$(echo "$line" | cut -f4 -d',')"
        fsmtpt="$(echo "$line" | cut -f5 -d',')"

        eval PART=\$PARTITIONS$IDX
        funcname="sizeup_partition_$PART"

        if declare -F $funcname 1> /dev/null 2>&1 ; then
            sizeup_partition_$PART "$IDX" "$size" "$fsmtpt" "$fstype"
        else
            sizeup_partition_X "$IDX" "$size" "$fsmtpt" "$fstype"
        fi
        IDX=$(( $IDX + 1 ))

    done < "$scheme"
    return 0
}

sizeup_partitions()
{
    local IDX=1
    local PART=""
    local funcname=""

    if [ "$DISK_TYPE" = "raid" ]; then
        PART_TYPE=FD00
        PT_TYPE=FD
    elif [ "$DISK_TYPE" = "lvm" ]; then
        PART_TYPE=8E00
        PT_TYPE=8E
    elif [ "$DISK_TYPE" = "openbsd" ]; then
        PART_TYPE=a600
        PT_TYPE=a6
    elif [ "$DISK_TYPE" = "freebsd" ]; then
        PART_TYPE=a500
        PT_TYPE=a5
    elif [ "$DISK_TYPE" = "netbsd" ]; then
        PART_TYPE=a900
        PT_TYPE=a9
    else
        PART_TYPE=8300
        PT_TYPE=83
    fi

    while test $IDX -le $MAX_PARTITIONS ; do
        eval PART=\$PARTITIONS$IDX
        funcname="sizeup_partition_$PART"

        if declare -F $funcname 1> /dev/null 2>&1 ; then
            sizeup_partition_$PART $IDX
        else
            sizeup_partition_X "$IDX" "$DRIVE_SIZE" "/$PART"
        fi
        IDX=$(( $IDX + 1 ))
    done

    return 0
}

# Main starts here ...
DEVICE="$1"
ARG="$2"

OFFSET=0
START=2048
SECTORS=0
PERCENT_TOTAL=100
START_SECTORS=512000
FACTOR=$(( 1024000 / 512 )) # by the logical sector size

BIOS_SIZE=2 # 2 Megabytes
DUMMY_SIZE=16
MAX_PARTITIONS=0

if ! is_valid_device "$DEVICE" ; then
    echo "INSTALLER: FAILURE L_NO_DEVICE_SPECIFIED"
    exit 1
fi

DRIVE_ID="$(basename $DEVICE)"

cat $TMP/scheme.map 1> $TMP/scheme-${DRIVE_ID}.map

SELECTED="$(extract_value scheme-${DRIVE_ID} 'device')"

if [ -z "$SELECTED" -o "$SELECTED" != "$DEVICE" ]; then
    echo "INSTALLER: FAILURE L_SCRIPT_MISMATCH_ON_DEVICE"
    exit 1
fi

SCHEME="$(extract_value scheme-${DRIVE_ID} 'scheme')"
DISK_TYPE="$(extract_value scheme-${DRIVE_ID} 'disk-type')"
ENCRYPTED="$(extract_value scheme-${DRIVE_ID} 'encrypted')"
FSTYPE="$(extract_value scheme-${DRIVE_ID} 'fstype')"
GPT_MODE="$(extract_value scheme-${DRIVE_ID} 'gpt-mode' 'upper')"
BOOT_SIZE="$(extract_value scheme-${DRIVE_ID} 'boot-size')"
SWAP_SIZE="$(extract_value scheme-${DRIVE_ID} 'swap-size')"
SECTOR_SIZE="$(extract_value scheme-${DRIVE_ID} 'sector-size')"

if [ "$DISK_TYPE" != "lvm" ]; then
    if [ "$SCHEME" = "lvm-10" -o "$SCHEME" = "lvm-12" ]; then
        echo "INSTALLER: FAILURE L_MISMATCH_SCHEME_DISK_TYPE"
        exit 1
    fi
fi

FDISK_SCHEME="$TMP/fdisk-${DRIVE_ID}-scheme"
OUTPUT_SCHEME=$TMP/partitions-${DRIVE_ID}.csv
OUTPUT_SECTORS=$TMP/sectors-${DRIVE_ID}.csv
#NEW_OUTPUT_SCHEME="$TMP/partitions-${DRIVE_ID}-new.csv"

unlink "$OUTPUT_SCHEME" 2> /dev/null
touch "$OUTPUT_SCHEME" 2> /dev/null

unlink "$FDISK_SCHEME" 2> /dev/null
touch "$FDISK_SCHEME" 2> /dev/null

DISK_SIZE="$(get_drive_size $DEVICE)"
RESERVED=$(( $BOOT_SIZE + $BIOS_SIZE + $SWAP_SIZE ))

if [ "$DISK_TYPE" = "lvm" ]; then

    DUMMY_SIZE="$SWAP_SIZE"

    # Replace swap primary partition by dummy one
    # Swap partition is to be part of the LVM store;
    # if an LVM drive is being prepared.
    RESERVED=$(( $BOOT_SIZE + $BIOS_SIZE + $DUMMY_SIZE ))

    cp -f $TMP/scheme.map $TMP/scheme-lvm.map

    # Force all LVM partitioning to the root scheme.
    # Use user specified scheme for logical volumes.
    SCHEME="root"
fi

#if [ "$ARG" = "modify" ]; then
#    if set_partition_names "$SCHEME" ; then
#        modify_scheme "$OUTPUT_SCHEME"
#    fi
#    exit $?
#fi

DEVIDX="$(get_device_counter $DEVICE)"

echo "${DEVICE}=${DEVIDX}" >> $TMP/drives-selected.lst

#if keep_home_partition "$DEVICE" ; then
#    wc -l "$OUTPUT_SCHEME" | cut -f1 -d' ' 1> $TMP/nb-${DRIVE_ID}-partitions
#    echo "INSTALLER: SUCCESS"
#    exit 0
#fi

DRIVE_SIZE=$(( $DISK_SIZE - $RESERVED ))
EXTENDED_SIZE=$DRIVE_SIZE

if set_partition_names "$SCHEME" ; then

    if sizeup_partitions "$SCHEME" "$DEVICE" "$DISK_TYPE" ; then
        wc -l "$OUTPUT_SCHEME" | cut -f1 -d' ' 1> $TMP/nb-${DRIVE_ID}-partitions
        echo "INSTALLER: SUCCESS"
        exit 0
    fi
fi

echo "INSTALLER: FAILURE"
exit 1

# end Breeze::OS setup script
