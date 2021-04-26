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
BRZDIR=${BREEZE_ROOTDIR:-"/usr/share/brzinst"}

crunch() # remove extra whitespace
{
    local answer
    read answer
    if [ -n "$answer" ]; then
        echo "$answer" | sed -r 's/[ ][ ]*/ /g'
    fi
    return 0
}

strip_file() # remove beginning and trailing whitespace
{
    local path="$1"

    if [ -s "$path" ]; then
        sed -r -i 's/^[\t ]*//g' $path
        sed -r -i 's/[\t ]*$//g' $path
    fi
    return 0
}

crunch_file() # remove extra whitespace
{
    local path="$1"

    if [ -s "$path" ]; then
        local line=""

        cat /dev/null > $TMP/tmpfile

        while read line; do
            line="$(echo "$line" | sed 's/^[\t ]*//g')"
            line="$(echo "$line" | sed 's/[\t ][\t \*]*/ /g')"

            if [ "$2" = "all" ]; then
                line="$(echo "$line" | sed 's/[\t ]*[,]/,/g')"
                line="$(echo "$line" | sed 's/[,][\t ]*/,/g')"
            fi
            echo "$line" >> $TMP/tmpfile
        done < "$path"

        mv -f $TMP/tmpfile "$path"
    fi

    return 0
}

echo_message()
{
    [ -z "$1" ] && echo "INSTALLER: MESSAGE"
    [ -n "$1" ] && echo "INSTALLER: MESSAGE ${1}"
    sync; sleep 1
    return 0
}

echo_progress()
{
    [ -z "$1" ] && echo "INSTALLER: PROGRESS"
    [ -n "$1" ] && echo "INSTALLER: PROGRESS ${1}"
    sync; sleep 1
    return 0
}

echo_mesgicon()
{
    [ -z "$1" ] && echo "INSTALLER: MESGICON package-x-generic"
    [ -n "$1" ] && echo "INSTALLER: MESGICON ${1}"
    sync; sleep 1
    return 0
}

echo_success()
{
    [ -z "$1" ] && echo "INSTALLER: SUCCESS"
    [ -n "$1" ] && echo "INSTALLER: SUCCESS ${1}"
    sync
    return 0
}

echo_warning()
{
    [ -z "$1" ] && echo "INSTALLER: WARNING"
    [ -n "$1" ] && echo "INSTALLER: WARNING ${1}"
    sync; sleep 1
    return 0
}

echo_error()
{
    [ -z "$1" ] && echo "INSTALLER: ERROR"
    [ -n "$1" ] && echo "INSTALLER: ERROR ${1}"
    sync; sleep 1
    return 0
}

echo_failure()
{
    [ -z "$1" ] && echo "INSTALLER: FAILURE"
    [ -n "$1" ] && echo "INSTALLER: FAILURE ${1}"
    sync
    return 0
}

echo_fatal()
{
    [ -z "$1" ] && echo "INSTALLER: FAILURE"
    [ -n "$1" ] && echo "INSTALLER: FAILURE ${1}"
    sync
    return 0
}

probe_memory()
{
    local arg="$1"
    local platform="$2"
    local memsize=""

    if [ "$platform" = "freebsd" -o "$platform" = "netbsd" ]; then
        vmstat="$(sysctl hw.realmem | crunch)"
        memsize="$(echo $memsize | sed -e 's/MemTotal:[ ]*//g')"
    elif [ "$arg" = "free" ]; then
        memsize="$(cat /proc/meminfo | grep -m1 -F MemFree)"
        memsize="$(echo $memsize | sed -e 's/MemFree:[ ]*//g')"
    elif [ "$arg" = "used" ]; then
        memsize="$(cat /proc/meminfo | grep -m1 -F MemUsed)"
        memsize="$(echo $memsize | sed -e 's/MemUsed:[ ]*//g')"
    else
        memsize="$(cat /proc/meminfo | grep -m1 -F MemTotal)"
        memsize="$(echo $memsize | sed -e 's/MemTotal:[ ]*//g')"
    fi

    memsize="$(echo $memsize | sed -e 's/[Kk][Bb].*$//g' | crunch)"
    memsize=$(( $memsize / 1000 ))

    echo "$memsize"
    return 0
}

enough_real_memory()
{
    local memreal="$(probe_memory real ${1})"

    if test $memreal -lt 768 ; then
        return 1
    fi

    local memfree="$(probe_memory free ${1})"

    if test $memfree -lt 256; then
        return 1
    fi

    return 0
}

custom_fdisk_in_use()
{
    if /sbin/fdisk -v | grep -qE '2[.]2[1-3][.][0-9]' ; then
        echo "yes"
        return 0
    fi
    echo "no"
    return 1
}

live_or_install_media()
{
    #local media="$(cat $TMP/livemedia-marker 2> /dev/null)"

    if [ -e /BRZLIVE -o -e /BRZINSTALL ]; then
        return 0
    fi
    return 1
}

is_safemode_drive()
{
    local device="$1"
    local scheme="$2"

    if [ ! -e $TMP/drives-on-atboot.lst ]; then
        return 1
    fi

    if grep -qF "$device" $TMP/drives-on-atboot.lst ; then
        return 1
    fi

    if [ -n "$scheme" ]; then
        if ! grep -qF "$device" $scheme ; then
            echo "INSTALLER: ERROR L_SELECTED_DRIVE_NOT_FOUND_IN_SCHEME !"
            return 1
        fi
    fi

    return 0
}

is_valid_device()
{
    local device="$1"

    [ -z "$device" ] && return 1
    [ "$device" = "/dev/" ] && return 1
    [ "$device" = "unknown" ] && return 1

    if [ -e "$device" ]; then
        if echo "$device" | egrep -q '^/dev/' ; then
            return 0
        fi
    fi

    return 1
}

is_drive_usb()
{
    local dtype="$(lsblk -dnlo TYPE $1 | crunch)"
    local model="$(lsblk -dnlo MODEL $1 | crunch)"
    local vendor="$(lsblk -dnlo VENDOR $1 | crunch)"
    local serial="$(lsblk -dnlo SERIAL $1 | crunch)"
    local usbrm="$(lsblk -dnlo RM $1 | crunch)"

    if [ "$dtype" != "disk" ]; then return 1; fi
    if [ "$usbrm" != "1" ]; then return 1; fi

    cat /proc/scsi/usb-storage/* > $TMP/usb-storage

    if [ -n "$model" ]; then
        if cat $TMP/usb-storage | grep -iqF "$model" ; then
            return 1
        fi
    fi

    if [ -n "$vendor" ]; then
        if cat $TMP/usb-storage/* | grep -iqF "$vendor" ; then
            return 1
        fi
    fi

    if [ -n "$serial" ]; then
        if cat $TMP/usb-storage/* | grep -iqF "$serial" ; then
            return 1
        fi
    fi
    return 0
}

is_drive_ssd()
{
    local devid="$(basename "$1")"
    local rota="$(lsblk -dno rota ${1} | crunch)"

    if [ "$rota" = "0" ]; then
        echo "yes"
        return 0
    fi

    rota="$(cat /sys/block/$devid/queue/rotational)"

    if [ "$rota" = "0" ]; then
        echo "yes"
        return 0
    fi
    echo "no"
    return 1
}

get_sector_size()
{
    local dev="$(basename $1)"

    if /sbin/fdisk -l $1 | egrep -q 'Sector size.*4096' ; then
        echo "4K"
    elif cat /var/log/dmesg | egrep -q "${dev}.*4096-byte physical blocks" ; then
        echo "4K"
    else
        echo "512"
    fi
    return 0
}

get_drive_size() {

    local device="$1"
    local disksz="$(/sbin/fdisk -s $device 2> /dev/null)"
#    local sz=$(( $disksz / 1000 * 1024 / 1000 ))
#    if test $sz -ge 750000 ; then # Probably a 4K drive
#        sz=$(( $disksz / 1024 * 1000 / 1024 ))
#    fi
    if [ -n "$disksz" ]; then
        disksz=$(( $disksz / 1024 * 1000 / 1024 ))
        echo "$disksz"
    fi
    return 0
}

is_gpt_drive() {

    local device="$1"
    local disktype="$2"
    local diskinfo=""

    if echo "$disktype" | grep -qF 'bsd' ; then
        diskinfo="$(fdisk -v $device)"
    else
        diskinfo="$(fdisk -l $device)"
    fi

    if echo "$diskinfo" | grep -iqF 'Disk label type: gpt' ; then
        return 0
    fi

    if echo "$diskinfo" | grep -iqF 'type: gpt' ; then
        return 0
    fi

    if echo "$diskinfo" | grep -iqF '#: type ' ; then
        return 0
    fi

    return 1
}

get_device_counter() {

    local device="$1"
    local idx="1"

    if [ -f $TMP/drives-selected.lst ]; then
        idx="$(grep -F "$1" $TMP/drives-selected.lst | tail -n1 | cut -f2 -d'=')"

        if [ -z "$idx" ]; then
            idx="$(wc -l $TMP/drives-selected.lst | cut -f1 -d' ')"
        fi
    fi

    if [ -z "$idx" ]; then
        idx="1"
    else
        idx=$(( $idx + 1 ))
    fi

    echo "$idx"
    return 0
}

was_lvm_partitioned()
{
    local device="$1"
    local devid="$(basename $1)"

    if [ -n "$device" ]; then

        if grep -qF "$device" $TMP/drives-partitioned.lst ; then
            return 0
        fi

        if fdisk -l $device | grep -qE "/dev/${devid}5.*Linux LVM" ; then
            return 0
        fi

        local logfile="$(mktemp $TMP/logfile.XXXXXX)"

        lsblk -fnpl $device 1> $logfile

        if ! grep -qE "/dev/${devid}3[ ]*LVM2_member" $logfile ; then
            unlink $logfile
            return 1
        fi

        if ! grep -qE "/dev/${devid}5[ ]*LVM2_member" $logfile ; then
            unlink $logfile
            return 1
        fi

        if ! grep -qE "/dev/${devid}[5-9]" $logfile ; then
            unlink $logfile
            return 0
        fi

        unlink $logfile
    fi

    return 1
}

get_vgroup_id()
{
    local vgname="$1"

    if ! grep -qF "${vgname}" $TMP/drives-on-atboot.lst ; then
        echo "${vgname}"
        return 0
    fi

    for id in 1 2 3 4 5 6 7 8 9 ; do
        if ! grep -qF "${vgname}_${id}" $TMP/drives-on-atboot.lst ; then
            echo "${vgname}_${id}"
            return 0
        fi
    done
    return 1
}

has_lvm_partition()
{
    local device="$1"

    if blkid | grep -qE "${device}.*LVM2" ; then
        return 0
    fi

    if lsblk -f $device | grep -qF "LVM2" ; then
        return 0
    fi

    if fdisk -l $device | grep -qE "/dev/${devid}5.*Linux LVM" ; then
        return 0
    fi

    if sgdisk -p $device | grep -iqE "[\t ]+8E00" ; then
        return 0
    fi

    #pvdisplay 1> $TMP/lvm.scan.log 2>&1
    #if grep -qE "PV Name[\t ]${device}" $TMP/lvm.scan.log ; then

    if pvdisplay 2> /dev/null | grep -qE "PV Name[\t ]+${device}" ; then
        return 0
    fi

    return 1
}

set_drive_mode()
{
        local device="$1"
        local expertise="$(cat $TMP/selected-expertise 2> /dev/null)"

        if [ "$expertise" = "beginner" ]; then
            cp $BRZDIR/fields/schemes.seq.beginner $BRZDIR/fields/schemes.seq
        else
            cp $BRZDIR/fields/schemes.seq.default $BRZDIR/fields/schemes.seq
        fi
        return 0
}

keep_home_partition()
{
    local device="$1"
    local driveid="$(basename $1)"
    local kept="$(cat $TMP/${driveid}-kepthome 2> /dev/null)"

    if [ -n "$kept" -a "$kept" = "yes" ]; then
        return 0
    fi
    return 1
}

keep_partitions()
{
    local device="$1"
    local disktype="$2"
    local driveid="$(basename $device)"

    if ! grep -qF "${device}=MBR" $TMP/gpt-mbr-drives ; then
        return 1
    fi

    if [ -n "$disktype" -a "$disktype" = "usbboot" ]; then
        return 1
    fi

    if [ -f "$TMP/kept-partitions.csv" ]; then
        RETVAL="$(grep -F -m1 keep $TMP/kept-partitions.csv)"

        if [ "$?" = 0 -a -n "$RETVAL" ]; then
            return 0
        fi
    fi
    return 1
}

test_mount()
{
    local device="$1"

    mount -r $device $KEEPDIR
    sync; sleep 1

    if [ "$?" != 0 ]; then
        echo_failure "L_KEEP_HOME_MOUNT_FAILURE"
        return 1
    fi

    umount $device
    sync; sleep 1

    return 0
}

check_settings_file()
{
    if [ -f "$TMP/${1}.map" ]; then
        return 0
    fi
    return 1
}

extract_value()
{
    local data="$1"
    local key="$2"
    local value=""

    if [ -f "$TMP/${data}.map" ]; then
        value="$(grep -E "^$key=" $TMP/${data}.map)"
    fi

    if [ -z "$value" -a -f "$BRZDIR/data/${data}.map" ]; then
        value="$(grep -E "^$key=" $BRZDIR/data/${data}.map)"
    fi

    if [ -n "$value" ]; then
        value="$(echo "$value" | cut -f2 -d=)"

        if [ "$3" = "upper" ]; then
            value="$(echo "$value" | tr '[:lower:]' '[:upper:]')"
        elif [ "$3" = "lower" ]; then
            value="$(echo "$value" | tr '[:upper:]' '[:lower:]')"
        elif [ -z "$value" -a -n "$3" ]; then
            value="$3"
        fi
    fi

    if [ -n "$value" ]; then
        if [ "$4" = "boolean" ]; then
            if [ "$value" = "0" ]; then
                value="no"
            else
                value="yes"
            fi
        fi
        echo "$value"
        return 0
    fi
    return 1
}

getfile()
{
    local host="$1"
    local src="$2"
    local target="$3"

    mkdir -p "$(dirname $target)"

    if [ -z "$PKGMEDIA" ]; then
        PKGMEDIA="$(cat $TMP/selected-media 2> /dev/null)"
    fi

    if [ -z "$ARCH" ]; then
        ARCH="$(cat $TMP/selected-arch 2> /dev/null)"
    fi

    if [ -z "$VERSION" ]; then
        VERSION="$(cat $TMP/selected-version 2> /dev/null)"
    fi

    if [ -z "$DERIVED" ]; then
        DERIVED="$(cat $TMP/selected-derivative 2> /dev/null)"
    fi

    if [ "$PKGMEDIA" = "network" -o "$PKGMEDIA" = "NETWORK" ]; then

        if [ "$host" != "web" ]; then
            #tftp -4 -m binary $host -c "get $src $target"
            tftp -b 16384 -g -r $src -l $target $host 2> /dev/null
        else
            local path="$src"

            src="$(basename $path)"

            if echo "$path" | grep -qF distfiles ; then
                src="/distfiles/$DERIVED/$ARCH/$VERSION/$src"
            else
                src="/archives/$DERIVED/$ARCH/All/$src"
            fi
            wget -q -O $target http://www.breezeos.com/$src 2> /dev/null
        fi
        return $?
    fi

    if [ -f $MOUNTPOINT/$src ]; then
        cp -f $MOUNTPOINT/$src $target
        return $?
    fi
    return 1
}

trap - PIPE

TMP=/var/tmp/brzinst
TMPDIR=/var/tmp/brzinst

ROOTDIR=/target
KEEPDIR=/var/mnt/keep
MOUNTUSB=/var/mnt/usb
MOUNTPOINT=/mnt/livemedia

CRYPTODIR=$TMP/keys
BOOT_CRYPTODIR=$TMP/etc/keys
MNT_CRYPTODIR=/mnt/cryptokeys
TMP_FSTAB=$TMP/fstab

mkdir -p $TMP/

mkdir -p $ROOTDIR/
mkdir -p $KEEPDIR/
mkdir -p $MOUNTUSB/
mkdir -p $MOUNTPOINT/

mkdir -p $CRYPTODIR/
mkdir -p $BOOT_CRYPTODIR/
mkdir -p $MNT_CRYPTODIR/

if [ ! -e /mnt/root ]; then
    ln -s /target /mnt/root
fi

# end Breeze::OS script
