#!/bin/bash
#
# GNU GENERAL PUBLIC LICENSE Version 3
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

add_lvm() {

    local lv="$1"
    local mtpt="/$1"
    local vg="$2"
    local percent="$3"
    local mbytes="$4"
    local fstype="$5"
    local size=$(( $mbytes * $percent / 100 / 4 * 4 ))

    if [ "$lv" = "root" ]; then mtpt="/"; fi

    if [ "$lv" = "swap" ]; then size=$mbytes; fi

    echo "$lv,mirror,$vg,$size,$fstype,$mtpt,create" >> $TMP/lvscan.lst

    return 0
}

output_stats() {

    local lvmcmd="vgs --noheadings --nosuffix --units m -o vg_size"

    local sz="$($lvmcmd $VGSTORE 2>> $TMP/lvm.errs | crunch | cut -f1 -d'.')"
    echo "$sz" 1> $TMP/lvm-footprint

    sz="$($lvmcmd $VGSWAP 2>> $TMP/lvm.errs | crunch | cut -f1 -d'.')"
    echo "$sz" 1> $TMP/lvm-swap-size

    return 0
}

output_results() {

    local cmd="$1"
    local outfile="$2"

    output_stats

    if [ -s $outfile ]; then 
        # Output the CSV list
        cat $outfile
        sync; sleep 1
        return 0
    fi

    if [ "$cmd" != "scan" ]; then
        echo_failure "L_NO_PV_FOUND"
        return 1
    fi
    return 0
}

# Main starts here ...
IDX=0
DEVICE="$1"
argument="$2"
argcmd="$3"

if [ -n "$argument" ]; then
    argument="$(echo "$2" | tr '[:upper:]' '[:lower:]')"
fi

if [ -n "$argcmd" ]; then
    argcmd="$(echo "$3" | tr '[:upper:]' '[:lower:]')"
fi

if [ "$argcmd" = "format" -a "$argument" = "lv" ]; then
    DEVICE="$(get_lvm_master_drive $DEVICE)"
fi

if ! is_valid_device "$DEVICE" ; then
    echo_failure "L_NO_DEVICE_SPECIFIED"
    exit 1
fi

DRIVE_ID="$(basename $DEVICE)"

SELECTED="$(cat $TMP/selected-drive 2> /dev/null)"

if [ -z "$SELECTED" -o "$SELECTED" != "$DEVICE" ]; then
        echo_failure "L_NO_DEVICE_SPECIFIED"
        exit 1
fi

if ! is_safemode_drive "$DEVICE" ; then
        exit 1
fi

if ! check_settings_file "scheme-${DRIVE_ID}" ; then
    echo_failure "L_MISSING_SCHEME_FILE"
    exit 1
fi

SCHEME="$(extract_value scheme-${DRIVE_ID} 'scheme')"
FSTYPE="$(extract_value scheme-${DRIVE_ID} 'fstype')"
LVMTYPE="$(extract_value scheme-${DRIVE_ID} 'lvm-type')"
SELECTED="$(extract_value scheme-${DRIVE_ID} 'device')"
ENCRYPTED="$(extract_value scheme-${DRIVE_ID} 'encrypted')"
CRYPTO_TYPE="$(extract_value crypto-${DRIVE_ID} 'type')"

if [ -z "$SELECTED" -o "$SELECTED" != "$DEVICE" ]; then
    echo_failure "L_SCRIPT_MISMATCH_ON_DEVICE"
    exit 1
fi

VGSWAP="$(get_vgroup_id vgswap)"
VGSTORE="$(get_vgroup_id vgstore)"

#LVMMODE="$(extract_value scheme-${DRIVE_ID} 'lvm-mode')"
#MIRRORS="$(extract_value scheme-${DRIVE_ID} 'nb-mirrors')"

if [ "$argcmd" = "format" -a "$argument" = "lv" ]; then

    list_lvm_partitions $TMP/tmplvm.csv

    unlink $TMP/lvm.csv 2> /dev/null
    touch $TMP/lvm.csv

    bootmtpt="boot"

    while read line; do
        if echo "$line" | grep -qE ",[a-z0-9]+,/boot" ; then
            if test $IDX -gt 0 ; then
                bootmtpt="boot${IDX}"
            fi

            IDX=$(( $IDX + 1 ))

            echo "$line" | \
                sed -r "s/,\/boot,.*$/,\/${bootmtpt},format/g" \
                >> $TMP/lvm.csv
        else
            echo "$line" >> $TMP/lvm.csv
        fi
    done < $TMP/tmplvm.csv

    while read line; do

        LV="$(echo "$line" | cut -f 1 -d',')"
        VG="$(echo "$line" | cut -f 3 -d',')"
        SIZE="$(echo "$line" | cut -f 4 -d',')"
        FSTYPE="$(echo "$line" | cut -f 5 -d',')"

        MTPT="$(echo "$line" | cut -f 6 -d',')"
        MTPT="$(echo "$MTPT" | sed -r 's/^\/target//g')"

        MODE="$(echo "$line" | cut -f 7 -d',')"

        if echo "$MTPT" | grep -qF '/boot' ; then
            MODE="format"
        elif [ "$MODE" = "create" ]; then
            if [ "$ENCRYPTED" != "yes" ]; then
                MODE="format"
            elif [ "$CRYPTO_TYPE" = "luks" ]; then
                MODE="crypt"
            #elif [ "$FSTYPE" = "swap" ]; then
            #    MODE="skip"
            elif echo "$DEVICE" | grep -qE 'home' ; then
                MODE="crypt"
            fi
        fi

        echo "/dev/$VG/$LV,8E00,$SIZE,$FSTYPE,$MTPT,$MODE" >> $TMP/lvm.csv

    done < $TMP/lvm-logical.csv

#    sed -ri "s/unknown,\/boot/$FSTYPE,\/boot/g" $TMP/lvm.csv

    cp $TMP/lvm.csv $TMP/lvm-${DRIVE_ID}.csv
    wc -l $TMP/lvm.csv | cut -f1 -d' ' 1> $TMP/nb-lvm-partitions

    cat $TMP/lvm.csv
    sync; sleep 1

    exit 0
fi

if [ "$argument" = "pv" ]; then # Physical Volumes

    idx=0
    drives="$(cat $TMP/lvm-target-drives | cut -f2 -d'=')"

    unlink $TMP/lvm-partitions.lst 2> /dev/null
    touch $TMP/lvm-partitions.lst 2> /dev/null

    for harddrive in $drives; do

        sgdisk -p $harddrive 1> $TMP/sgdisk.log 2> /dev/null

        grep -E '^[ ]+[0-9]+[ ]' $TMP/sgdisk.log 1> $TMP/sgdisk1.log

        if [ -s $TMP/sgdisk1.log ]; then
            harddrive="$(basename $harddrive)"
            sed -r -i "s/^[ ][ ]*/\/dev\/$harddrive/g" $TMP/sgdisk1.log
            cat $TMP/sgdisk1.log >> $TMP/lvm-partitions.lst
        fi
    done

    crunch_file $TMP/lvm-partitions.lst all

    if [ "$argcmd" = "scan" ]; then # Physical Volumes

        unlink $TMP/pvscan.lst 2> /dev/null
        touch $TMP/pvscan.lst

        pvs --noheadings --segments --nosuffix \
            --units 'm' --separator ',' 2>> $TMP/lvm.errs | \
            grep rimage_0 1> $TMP/pv.lst

        if [ ! -s "$TMP/pv.lst" ]; then
            pvs --noheadings --segments --nosuffix \
                --units 'm' --separator ',' 1> $TMP/pv.lst 2>> $TMP/lvm.errs
        fi

        if [ -s "$TMP/pv.lst" ]; then

            strip_file "$TMP/pv.lst"

            while read line; do

                if ! $(echo "$line" | grep -q -m1 -E '^/') ; then
                    continue
                fi

                device="$(echo "$line" | cut -f 1 -d',')"
                vgroup="$(echo "$line" | cut -f 2 -d',')"

                volume="$(echo "$line" | cut -f 9 -d',')"
                volume="$(echo "$volume" | sed 's/_.*//g')"
                volume="$(echo "$volume" | cut -f2 -d'[')"

                size="$(echo "$line" | cut -f 5 -d',')"
                size="$(echo "$size" | cut -f 1 -d'.')"

                vsize="$(echo "$line" | cut -f 8 -d',')"

#                end="$(echo "$line" | cut -f 8 -d',')"
#                begin="$(echo "$line" | cut -f 9 -d',')"
#
#                if [ -z "$end" -o -z "$begin" ]; then
#                    vsize=0
#                else
#                    vsize=$(( $end - $begin ))
#                    vsize=$(( $vsize * 4 ))
#                fi

                if test "$vsize" -eq 0 ; then
                    vsize="$size"
                fi

                idx=$(( $idx + 1 ))

                echo "no,$device,$vgroup,$volume,$size,$vsize" >> $TMP/pvscan.lst
            done < $TMP/pv.lst
        fi

#        echo "$idx" 1> $TMP/nb-volumes
        output_results scan $TMP/pvscan.lst
        exit $?
    fi

    if [ "$argcmd" != "create" ]; then # Physical Volumes
        echo_failure "L_INVALID_ARGUMENT"
        exit 1
    fi

    unlink $TMP/lvm-physical.csv 2> /dev/null
    touch $TMP/lvm-physical.csv 2> /dev/null

    pvs --noheadings --segments --nosuffix --verbose \
        --units 'm' --separator ',' 1> $TMP/pv.lst 2>> $TMP/lvm.errs

    while read line; do

        pline=""
        mode="create"
        device="$(echo "$line" | cut -f 1 -d' ')"
        begin="$(echo "$line" | cut -f 2 -d' ')"
        end="$(echo "$line" | cut -f 3 -d' ')"
        ptype="$(echo "$line" | cut -f 6 -d' ' | tr '[:upper:]' '[:lower:]')"

        size=$(( $end - $begin ))
        size=$(( $size * 512 / 1024 / 1024 ))

        if test "$size" -le "5" ; then
            continue
        fi

        if [ "$ptype" = "ef00" -o \
            "$ptype" = "ef01" -o "$ptype" = "ef02" ]; then
            continue
        fi

        devname="$(basename "$device" | sed 's/[0-9]*//g')"

        if [ -f "$TMP/partitions-${devname}.csv" ]; then
            pline="$(grep -m1 -F "$device" $TMP/partitions-${devname}.csv)"
        fi

        pptype="$(echo "$pline" | cut -f2 -d, | tr '[:upper:]' '[:lower:]')"

        if [ "$pptype" != "8e00" -a "$pptype" != "8200" ]; then
            continue
        fi

        if grep -q -m1 -F "$device" $TMP/pv.lst ; then
            mode="keep"
        fi

        idx=$(( $idx + 1 ))

        if [ "$ptype" = "8200" -o "$pptype" = "8200" ]; then
            if [ -z "$pline" ]; then
                echo "$device,$VGSWAP,,$size,ignore" >> $TMP/lvm-physical.csv
            else
                echo "$device,$VGSWAP,,$size,$mode" >> $TMP/lvm-physical.csv
            fi
        else
            echo "$device,$VGSTORE,,$size,$mode" >> $TMP/lvm-physical.csv
        fi
    done < $TMP/lvm-partitions.lst

    #echo "$idx" 1> $TMP/nb-volumes
    cp $TMP/lvm-physical.csv $TMP/lvm-physical-${DRIVE_ID}.csv
    #output_results create $TMP/lvm-physical.csv
    output_stats

    exit $?
fi

if [ "$argument" = "lv" ]; then # Logical Volumes

    lvs --unquoted --noheadings --segments --nosuffix \
        --units 'm' --separator ',' 1> $TMP/lv.lst 2>> $TMP/lvm-lvs.errs

    unlink $TMP/lvscan.lst 2> /dev/null
    touch $TMP/lvscan.lst

    if [ -s "$TMP/lv.lst" ]; then

        strip_file "$TMP/lv.lst"

        while read line; do

            volume="$(echo "$line" | cut -f1 -d',')"
            vgroup="$(echo "$line" | cut -f2 -d',')"
            dtype="$(echo "$line" | cut -f5 -d',')"
            size="$(echo "$line" | cut -f6 -d',')"

            device="/dev/${vgroup}/${volume}"

            fstype="$(lsblk -n -l -o 'fstype' $device)"
            if [ -z "$fstype" ]; then fstype="ext4"; fi

            mtpt="$(lsblk -n -l -o 'mountpoint' $device)"

            if [ "$volume" = "root" ]; then
                mtpt="/"
            elif [ -z "$mtpt" ]; then
                mtpt="/$volume"
            else
                mtpt="$(echo "$mtpt" | sed -r 's/^\/target//g')"
            fi

            echo "$volume,$dtype,$vgroup,$size,$fstype,$mtpt,keep" >> $TMP/lvscan.lst
        done < $TMP/lv.lst
    fi

    if [ ! -s "$TMP/lvscan.lst" ]; then

        if [ -s $TMP/lvm-swap-size ]; then
            LVM_SWAP_SIZE="$(cat $TMP/lvm-swap-size 2> /dev/null)"
        else
            LVM_SWAP_SIZE="$(extract_value scheme-${DRIVE_ID} 'swap-size')"
        fi

        add_lvm swap $VGSWAP 100 $LVM_SWAP_SIZE swap

        LVM_STORE_SIZE="$(cat $TMP/lvm-footprint 2> /dev/null)"

        while read line; do
            percent="$(echo "$line" | cut -f2 -d',')"
            ptname="$(echo "$line" | cut -f3 -d',')"
            add_lvm $ptname $VGSTORE $percent $LVM_STORE_SIZE $FSTYPE
        done < $BRZDIR/data/scheme-${SCHEME}.csv
    fi

    if [ ! -s $TMP/lvscan.lst ]; then
        echo_failure "L_NO_PV_FOUND"
        exit 1
    fi

    cp -f $TMP/lvscan.lst $TMP/lvm-logical.csv

    wc -l $TMP/lvscan.lst | cut -f1 -d' ' 1> $TMP/nb-logical-volumes

    # Output the CSV list
    cat $TMP/lvscan.lst
    sync; sleep 1

    exit 0
fi

echo_failure "L_INVALID_ARGUMENT"
exit 1

# end Breeze::OS setup script
