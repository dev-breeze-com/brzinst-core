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

DEVICE="$1"
cmd="$2"
argument="$3"
hdd="$4"

if ! is_valid_device "$DEVICE" ; then
    echo_failure "L_NO_DEVICE_SPECIFIED"
    exit 1
fi

DRIVE_ID="$(basename $DEVICE)"

SELECTED="$(extract_value scheme-${DRIVE_ID} 'device')"

if [ -z "$SELECTED" -o "$SELECTED" != "$DEVICE" ]; then
    echo_failure "L_SCRIPT_MISMATCH_ON_DEVICE"
    exit 1
fi

if ! is_safemode_drive $DEVICE ; then
    echo_failure "L_INVALID_DEVICE_SPECIFIED"
    exit 1
fi

DISK_TYPE="$(extract_value scheme-${DRIVE_ID} 'disk-type')"
ENCRYPTED="$(extract_value scheme-${DRIVE_ID} 'encrypted')"
CRYPTO_TYPE="$(extract_value crypto-${DRIVE_ID} 'type')"

if [ "$DISK_TYPE" != "lvm" ]; then
    echo "INVALID TEST DRIVE $DEVICE !"
    echo_failure "L_INVALID_TEST_DRIVE_SELECTED !"
    exit 1
fi

LVM_DRIVES="$(cat $TMP/lvm-target-drives | cut -f2 -d'=' | tr -s '\n' ' ')"

if [ -z "$LVM_DRIVES" ]; then
    echo "INVALID TEST DRIVE $LVM_DRIVES !"
    echo_failure "L_INVALID_TEST_DRIVE_SELECTED !"
    exit 1
fi

VGSWAP="$(get_vgroup_id vgswap)"
VGSTORE="$(get_vgroup_id vgstore)"

# Create LVM physical volumes...
NB_MIRRORS="$(wc -l $TMP/lvm-target-drives | cut -f1 -d' ')"

if [ "$cmd" = "create" -a "$argument" = "pv" ] || \
   [ "$cmd" = "remove" -a "$argument" = "pv" ]; then

    # Remove any existing LVM logical volumes...
    vgroups="$VGSTORE $VGSWAP"

    unmount_devices "$DEVICE" "$ENCRYPTED"

    vgchange -an 2>> $TMP/lvm.errs ; sync

    for vg in $vgroups ; do
        lvremove --force $vg 1>> $TMP/lvm-logical.log 2>> $TMP/lvm-logical.errs

        if [ $? != 0 ]; then
            if ! grep -qF "not found" $TMP/lvm-logical.errs ; then
                echo_failure "L_LVM_LOGICAL_REMOVAL_FAILURE"
                exit 1
            fi
        fi
    done

    if [ "$cmd" = "remove" -a "$argument" = "pv" ]; then
        for vg in $vgroups ; do
            vgremove --force $vg \
                1>> $TMP/lvm-vgroup.log 2>> $TMP/lvm-vgroup.errs

            if [ $? != 0 ]; then
                if ! grep -qF "not found" $TMP/lvm-vgroup.errs ; then
                    echo_failure "L_LVM_GROUP_REMOVAL_FAILURE"
                    exit 1
                fi
            fi
        done

        for dev in $LVM_DRIVES ; do
            if ! is_safemode_drive $dev ; then
                echo_warning "L_INVALID_DEVICE_SPECIFIED"
                echo_failure "L_LVM_REMOVAL_FAILURE"
                exit 1
            fi

            devices="${dev}3 ${dev}5"

            for pv in $devices ; do
                pvremove --force $pv \
                    1>> $TMP/lvm-physical.log 2>> $TMP/lvm-physical.errs

                if [ $? != 0 ]; then
                    if ! grep -qF "not found" $TMP/lvm-physical.errs ; then
                        echo_failure "L_LVM_PHYSICAL_REMOVAL_FAILURE"
                        exit 1
                    fi
                fi
            done
        done

        exit 0
    fi
fi

if [ "$cmd" = "create" -a "$argument" = "pv" ]; then

    unlink $TMP/lvm-selected-drives 2> /dev/null
    touch $TMP/lvm-selected-drives 2> /dev/null

    # Create LVM physical volumes...
    for device in $LVM_DRIVES ; do
        if ! is_safemode_drive $device ; then
            echo_warning "L_INVALID_DEVICE_SPECIFIED"
            echo_failure "L_LVM_PHYSICAL_FAILURE"
            exit 1
        fi

        echo -n "$device " >> $TMP/lvm-selected-drives
        sync

        pvcreate -ff --zero y --yes -M2 ${device}3 ${device}5 2>> $TMP/lvm.errs

        if [ $? != 0 ]; then
            echo_failure "L_LVM_PHYSICAL_FAILURE"
            exit 1
        fi

        vgswap_devs="$vgswap_devs ${device}3"
        vgstore_devs="$vgstore_devs ${device}5"
    done

    echo "--------------" 1>> $TMP/lvm-group.log
    sync

    echo "y" | \
    vgcreate --zero y --yes --force --clustered n $VGSWAP \
        $vgswap_devs 1>> $TMP/lvm-group.log 2>> $TMP/lvm-group.errs

    if [ $? != 0 ]; then
        echo_failure "L_LVM_VGSWAP_CREATION_FAILURE"
        exit 1
    fi

    echo "--------------" 1>> $TMP/lvm-group.log
    sync

    echo "y" | \
    vgcreate --zero y --yes --force --clustered n $VGSTORE \
        $vgstore_devs 1>> $TMP/lvm-group.log 2>> $TMP/lvm-group.errs

    if [ $? != 0 ]; then
        echo_failure "L_LVM_VGSTORE_CREATION_FAILURE"
        exit 1
    fi

    lvmcmd="vgs --noheadings --nosuffix --units m -o vg_size"

    sz="$($lvmcmd $VGSTORE 2>> $TMP/lvm.errs | crunch | cut -f1 -d'.')"
    echo "$sz" 1> $TMP/lvm-footprint

    sz="$($lvmcmd $VGSWAP 2>> $TMP/lvm.errs | crunch | cut -f1 -d'.')"
    echo "$sz" 1> $TMP/lvm-swap-size

    exit 0
fi

if [ "$cmd" = "create" -a "$argument" = "lv" ]; then

    echo "INSTALLER: MESSAGE L_ACTIVATING_LVM_PARTITIONS"
    vgchange -ay 2>> $TMP/lvm.errs ; sync

    NBIDX=0
    COUNT=$(cat $TMP/nb-logical-volumes)

    for device in $LVM_DRIVES ; do
        if ! is_safemode_drive $device ; then
            echo_failure "L_LVM_LOGICAL_FAILURE"
            exit 1
        fi
        vgswap_devs="$vgswap_devs ${device}3"
        vgstore_devs="$vgstore_devs ${device}5"
    done

    # Create LVM logical volumes
    while read line; do

        NBIDX=$(( $NBIDX + 1 ))

        volume="$(echo "$line" | cut -f1 -d ',')"
        ltype="$(echo "$line" | cut -f2 -d ',')" # linear|mirror|striped
        vgroup="$(echo "$line" | cut -f3 -d ',')"
        size="$(echo "$line" | cut -f4 -d ',')"
        mode="$(echo "$line" | cut -f7 -d ',')"

        echo "INSTALLER: MESSAGE TIP_CREATING_X_LVM_LOGICAL_PARTITION((volume,$volume),(vgroup,$vgroup),(size,$size))"
        sync; sleep 1

        if [ "$mode" != "create" ]; then
            continue
        fi

        if [ "$volume" = "swap" ]; then
            devices="$vgswap_devs"
        else
            devices="$vgstore_devs"
        fi

        if test $NB_MIRRORS -lt 2 ; then
            ltype="linear"
            devices=""
        fi

        if [ "$ltype" = "mirror" -o "$ltype" = "mirrored" ]; then

            factor=$(( 97 / $NB_MIRRORS ))
            size=$(( $size * $factor / 100 ))
            nb_mirrors=$(( $NB_MIRRORS - 1 ))

            echo "y" | lvcreate --zero y --available y --nosync \
                --mirrors $nb_mirrors --size ${size}m \
                --name $volume $vgroup $devices \
                1>> $TMP/lvm-lvcreate.log 2>> $TMP/lvm-lvcreate.errs

#        if [ "$ltype" = "striped" ]; then
#            physvol="$(ls "$TMP/schemes-" | wc -l | cut -f1 -d' ' | crunch)"
#
#            if [ -z "$physvol" ]; then physvol="2"; fi
#
#            lvcreate --zero y --available y \
#                -i$physvol --size ${size}m --name $volume $vgroup
#
#        elif [ "$ltype" = "snapshot" ]; then
#            lvcreate --zero y --available y --type snapshot \
#                --size ${size}m --name ${volume}_snapshot $vgroup
#
        else
            echo "y" | lvcreate --zero y --available y \
                --size ${size}m --name $volume \
                $vgroup $devices 1>> $TMP/lvm-lvcreate.log \
                2>> $TMP/lvm-lvcreate.errs
        fi

#        rc=$?
#
#        if egrep 'already exist' $TMP/lvm.errs ; then
#            rc=0
#        fi

        if [ $? != 0 ]; then
            echo_failure "L_LVM_LOGICAL_FAILURE"
            exit 1
        fi

        echo_progress "((volume,$volume),(vgroup,$vgroup),(size,$size))"

    done < $TMP/lvm-logical.csv

    if test $NBIDX -lt $COUNT ; then
        echo_failure "L_LVM_LOGICAL_FAILURE"
        exit 1
    fi

    exit 0
fi

echo_failure "L_INVALID_ARGUMENT"
exit 1

# end Breeze::OS setup script
