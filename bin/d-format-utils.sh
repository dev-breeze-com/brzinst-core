#!/bin/bash
#
# GNU GENERAL PUBLIC LICENSE Version 3
#
# GNU GENERAL PUBLIC LICENSE Version 3
#
# Copyright 2015, Pierre Innocent, Tsert Inc. All Rights Reserved
#
# Initialize folder paths
#. d-dirpaths.sh

activate_swap()
{
    local device="$1"
    local devid="$2"

    if [ -e "$TMP/swap-${devid}-activated" ]; then
        return 0
    fi

    d-swapon.sh "$device"

    if [ "$?" = 0 ]; then
        touch $TMP/swap-${devid}-activated
        return 0
    fi
    return 1
}

sleep_one_second() { # somehow sleep in the popen child blocks parent process

    sync
#    while true; do
#        count=$(( $count + 1 ))
#        if [ "$count" -gt 100 ]; then
#            break
#        fi
#        usleep 10000
#    done
    return 0
}

detect_disk_type() {

    local device="$1"
    local disk_type="normal"

    vgs -v &> $TMP/LVM-CHECK.log

    if ! grep -qi 'No volume groups found' $TMP/LVM-CHECK.log ; then
        if ! grep -qi "$device" $TMP/LVM-CHECK.log ; then
            disk_type="lvm"
        fi
    fi
    echo "$disk_type"
    return 0
}

show_settings() {

    local device="$1"
    #local fstype="$2"
    #local mtpt="$3"
    #local size="$(lsblk -n -o 'size' $device | crunch)"
    #echo -e "device=$device\nsize=$size\nfilesystem=$fstype\nmountpoint=$mtpt"

    if is_safemode_drive $dev ; then
        umount $device 2> /dev/null
        sleep_one_second
    fi

    return 0
}

get_mapper_device() {

    local device="$1"

    if echo "$device" | grep -qE '/dev/vg(swap|store)/' ; then
        local path="$(dirname ${1})"
        local devid="$(basename ${1})"
        local vgroup="$(basename $path)"
        device="/dev/mapper/${vgroup}-${devid}"
    fi
    echo "$device"
    return 0
}

get_device_uuid() {

    local device="$1"
    local uuid="$(blkid -s UUID -o value $device)"

    if [ -z "$uuid" ]; then

        echo "No UUID found for DEVICE=$device" >> $TMP/mt.errs

        device="$(get_mapper_device $device)"
        uuid="$(blkid -s UUID -o value $device)"

        if [ -z "$uuid" ]; then
            echo "No UUID found for DEVICE=$device" >> $TMP/mt.errs
            return 1
        fi
    fi

    echo "UUID=$uuid DEVICE=$device" >> $TMP/mt.errs
    echo "$uuid"

    return 0
}

# write_crypttab( dev, mtpt, keyfile type)
write_crypto_conf()
{
    local drive="$1"
    local device="$2"
    local partition="$3"
    local mtpt="$4"
    local crypto="$5"

    local cryptoname="$(basename $partition)"
    local rawuuid="$(get_device_uuid $device)"
    local cryptodevices="$(cat $TMP/crypto-devices 2> /dev/null)"
    local cryptolabel="$(cat $TMP/crypto-$mtpt 2> /dev/null)"

    echo "# $device was mounted on $mtpt during installation" >> $TMP/dmcrypt
    echo "# $device was mounted on $mtpt during installation" >> $TMP/crypttab

    if echo "$cryptoname" | grep -qF '${crypto}swap' ; then

        printf "target=%s\nsource=UUID=\"%s\"\nswap=%s\noptions='%s'\n" \
            "$cryptoname" "$rawuuid" "$cryptoname" \
            "--offset 2048 -c aes-xts-plain64 -s 512 -d /dev/urandom" >> $TMP/dmcrypt

        if [ -z "$cryptolabel" ]; then
            printf "%-20s UUID=%s %-16s swap\n" \
                "$cryptoname" "$rawuuid" "/dev/urandom" >> $TMP/crypttab
        else
            printf "%-20s LABEL=%-20s %-16s swap,offset=2048,cipher=aes-xts-plain64,size=512\n" \
                "$cryptoname" "$cryptolabel" "/dev/urandom" >> $TMP/crypttab
        fi
    else
        local keyfile="$(get_keyfile_path "bootpath" "$drive" "$device")"

        if [ -z "$cryptodevices" ]; then
            cryptodevices="${device}:${cryptoname}"
        else
            cryptodevices="$cryptodevices,${device}:${cryptoname}"
        fi

        echo "$cryptodevices" 1> $TMP/crypto-devices

        printf "target=%s\nsource=UUID=\"%s\"\nkey=%s\n" \
            "$cryptoname" "$rawuuid" "$keyfile" >> $TMP/dmcrypt

        printf "%-20s UUID=%s %s luks\n" \
            "$cryptoname" "$rawuuid" "$keyfile" >> $TMP/crypttab
    fi

    echo "" >> $TMP/dmcrypt
    echo "" >> $TMP/crypttab

    return 0
}

# write_fstab( dev, mtpt, fstype, fsdump_order )
write_fstab()
{
    local device="$1"
    local mtpt="$2"
    local fstype="$3"
    local order="$4"
    local ssd="$5"
    local options="defaults"
    local devid="$(basename $1)"
    local uuid="$(get_device_uuid $device)"

    echo "$device" >> $TMP/formatted-partitions 

    # Add elevator=noop to kernel boot options
    # if only drive is SSD
    local ssdopts="noatime,nodiratime,discard"

    if [ "$fstype" = "vfat" -o "$fstype" = "dos" ]; then
        if [ "$ssd" = "yes" ]; then
            options="uni_xlate,defaults,$ssdopts"
        else
            options="uni_xlate,defaults"
        fi
    elif [ "$fstype" = "f2fs" -o "$fstype" = "nilfs2" ]; then
        options="defaults,$ssdopts"

    elif [ "$fstype" = "reiserfs" ]; then
        if [ "$ssd" = "yes" ]; then
            options="notail,barrier=flush,$ssdopts"
        else
            options="notail,barrier=flush,noatime"
        fi
    elif [ "$fstype" = "reiser4" ]; then
        if [ "$ssd" = "yes" ]; then
            options="notail,barrier=flush,noatime,node=node41,txmod=wa,$ssdopts"
        else
            options="notail,barrier=flush,noatime,node=node41,txmod=journal"
        fi
    elif [ "$fstype" = "ext4" ]; then
        if [ "$ssd" = "yes" ]; then
            options="defaults,$ssdopts"
        else
            options="defaults,noatime,nodiratime"
        fi
    elif [ "$fstype" = "jfs" -o "$fstype" = "xfs" ]; then
        if [ "$ssd" = "yes" ]; then
            options="defaults,$ssdopts"
        else
            options="defaults,noatime"
        fi
    fi

    if [ "$mtpt" = "/boot" ]; then
        options="$options,nodev,nosuid,noexec"
    fi

    echo "# $device was mounted on $mtpt during installation" >> $TMP/fstab
    printf "UUID=%-36s %-16s %-10s %-16s %s %s\n" \
        "$uuid" "$mtpt" "$fstype" "$options" "1" "$order" >> $TMP/fstab
    echo "" >> $TMP/fstab

    return 0
}

strip_ptype() {
    read ptype
    ptype="$(echo "$ptype" | sed -r 's/^.//g')"
    ptype="$(echo "$ptype" | sed -r 's/.$//g')"
    echo "$ptype"
}

get_lvm_master_drive()
{
    local device="$1"
    local master="$(head -n1 $TMP/lvm-target-drives | cut -f2 -d'=')"

    if grep -qF "$device" $TMP/lvm-target-drives ; then
        echo "$master"
        return 0
    fi
    echo "$device"
    return 1
}

track_mountpoint()
{
    printf "%s,%s,%s,%s,%s,%s,%s\n" "$2" "$3" "$4" "$5" "$6" "$7" "$8" \
        >> $TMP/mountpoints-${1}.csv
    return 0
}

set_mountpoint() {

    local device="$1"
    local mtpt="$2"
    local fstype="$3"
    local ptype="$4"
    local ssd="$5"
	local tgtmtpt="$(echo "$ROOTDIR/$mtpt" | tr -s '/')"

    if [ "$ptype" = "8200" -o "$ptype" = "82" -o "$fstype" = "swap" ]; then
        write_fstab $device "swap" "swap" "0" "$ssd"
        return 0
    fi

    mkdir -p $tgtmtpt 2> /dev/null

    if [ "$mtpt" = "/boot" -o "$mtpt" = "/efi" -o "$mtpt" = "/boot/efi" ]; then
        if ! echo "$mtpt" | grep -qF '/mnt/hd' ; then
            if [ ! -f $TMP/boot-selected ]; then 
                echo "$device,$mtpt" 1> $TMP/boot-selected
            fi
        fi
    fi

    for fs in $fstype $FILESYSTEMS ; do
        mount -t $fs $device $tgtmtpt 1> /dev/null 2>&1
    
        if [ "$?" = 0 ]; then
            FS_TYPE="$fs"
            sleep_one_second
            break
        fi
        sleep_one_second
    done

    sync

    # Using /boot for mounting for Gummiboot or Refind
    if [ "$mtpt" = "/boot" -a "$ptype" = "EF00" ]; then
        mkdir -p $ROOTDIR/boot/efi 2> /dev/null
    fi

    FS_TYPE="$(mount | grep -m1 -E "^$device on " | cut -f5 -d ' ')"
    write_fstab $device $mtpt $FS_TYPE "2" "$ssd"

    return 0
}

reorder_rootfs()
{
    local src="$1"
    local order="$2"
    local target="$3"

    grep -F ',/,' "$src" 1> $TMP/root.csv
    grep -v -F ',/,' "$src" 1> $TMP/rest.csv

    if [ -z "$target" ]; then target="$src"; fi

    if [ "$order" = "last" ]; then
        cat $TMP/rest.csv 1> "$target"
        cat $TMP/root.csv >> "$target"
    else
        cat $TMP/root.csv 1> "$target"
        cat $TMP/rest.csv >> "$target"
    fi

    return 0
}

devtmpfs_enabled()
{
    local target="$1"
	local kernel="$(cat $TMP/selected-kernel-version 2> /dev/null)"

    if grep -qF 'CONFIG_DEVTMPFS=y' $target/boot/config*${kernel}* ; then
        return 0
    fi

    return 1
}

add_fstab_cdrom()
{
    local drive_id="$(basename $1)"
    local gptmode="$(extract_value "scheme-${drive_id}" 'gpt-mode')"

    d-list-drives.sh cdroms 1> /dev/null 2> /dev/null

    while read line; do

        local device="$(echo "$line" | cut -f1 -d ' ')"
        local mtpt="$(echo "$line" | cut -f2 -d ' ')"

        echo "# $device was mounted on $mtpt during installation" >> $TMP/fstab
        printf "%-12s %-20s %-12s %-28s %s %s\n" "$device" "$mtpt" \
            "udf,iso9660" "ro,user,noauto,unhide,utf8" "0" "0" >> $TMP/fstab
        echo "" >> $TMP/fstab

    done < $TMP/detected-cdroms

    echo "# /dev/cdrom mounted on /media/cdrom0" >> $TMP/fstab
    printf "%-12s %-20s %-12s %-28s %s %s\n" "/dev/cdrom" "/media/cdrom0" \
        "auto" "ro,owner,noauto,unhide,utf8,comment=x-gvfs-show" "0" "0" >> $TMP/fstab
    echo "" >> $TMP/fstab

    echo "# /dev/fd0 mounted on /media/floppy0" >> $TMP/fstab
    printf "%-12s %-20s %-12s %-28s %s %s\n" "/dev/fd0" "/media/floppy0" \
        "auto" "rw,user,noauto" "0" "0" >> $TMP/fstab
    echo "" >> $TMP/fstab

    if [ "$gptmode" = "UEFI" -o "$gptmode" = "S_UEFI" ]; then
        echo "# efivars mounted on /sys/firmware/efi/efivars" >> $TMP/fstab
        printf "%-10s %-30 %-12s %-28s %s %s\n" "efivars" \
            "/sys/firmware/efi/efivars" "efivars" "defaults" "0" "0" >> $TMP/fstab
        echo "" >> $TMP/fstab
    fi
    return 0
}

list_lvm_partitions()
{
    local lvmdev=""
    local output="$1"
    #local argument="$2"
    local lvm_drives="$(cat $TMP/lvm-target-drives | cut -f2 -d'=')"

    unlink $output 2> /dev/null
    touch $output 2> /dev/null

    for lvmdev in $lvm_drives ; do
        local devid="$(basename $lvmdev)"
        grep -i -E '/bios|,EF01,|,EF02|/boot' \
            $TMP/partitions-${devid}.csv >> $output
    done
    return 0
}

unmount_devices() {

    local dev=""
    local mtpt=""
    local hdd="$1"
    local crypted="$2"
    local devid="$(basename $1)"

    local missed=""
    local value=""
    local vgroup=""
    local devices=""

    local luksmtpts="$(lsblk -l | grep -i luks | cut -f1 -d' ' | tr -s '\n' ' ')"

    local lvmmtpts="$(pvdisplay -C --noheadings | grep -F "$hdd" | tr -s '  ' ' ' | cut -f3 -d' ' | tr -s '\n' ' ' | crunch | tr -s ' ' '|')"

    local lvmdevices="$(lvdisplay | egrep "/$lvmmtpts/" | tr -s '  ' ' ' | cut -f4 -d' ')"

    touch $TMP/umount.errs 2> /dev/null

    cat $TMP/partitions-*.csv | cut -f1 -d, 1> $TMP/all-partitions

    echo_message "L_DEACTIVATING_EXISTING_LVM_PARTITIONS"

    pvs --noheadings --separator ',' 1> $TMP/pv.lst 2>> $TMP/lvm.errs

    strip_file "$TMP/pv.lst"

    if [ -s $TMP/pv.lst ]; then

        while read line; do
            dev="$(echo "$line" | cut -f1 -d',')"
            dev="$(echo "$dev" | sed -e 's/[0-9]*$//g')"
            vgroup="$(echo "$line" | cut -f2 -d',')"

            if [ "$dev" = "$hdd" -a -n "$vgroup" ]; then
                vgchange -an $vgroup 2>> $TMP/lvm.errs
            fi
        done < $TMP/pv.lst
    fi

    echo_message "L_UNMOUNTING_EXISTING_LVM_PARTITIONS"

    if [ -n "$lvmdevices" ]; then
        for dev in $lvmdevices ; do
            if is_safemode_drive $dev ; then
                if echo "$dev" | grep "swap" ; then
                    swapoff "$dev" 1> /dev/null 2>> $TMP/umount.errs
                    sync
                fi

                umount "$dev" 2>> $TMP/umount.errs
                sync
            fi
        done
    fi

    echo_message "L_UNMOUNTING_EXISTING_LUKS_PARTITIONS"

    if [ -n "$luksmtpts" ]; then
        for dev in $luksmtpts ; do
            if is_safemode_drive $dev ; then
                umount "/dev/mapper/$dev" 2>> $TMP/umount.errs
                sync
            fi
        done
    fi

    echo_message "L_UNMOUNTING_EXISTING_PARTITIONS"

    lsblk -nplo kname,fstype,mountpoint $hdd 1> $TMP/devices-lsblk.lst

    crunch_file $TMP/devices-lsblk.lst

    cat $TMP/devices-lsblk.lst | while read line; do

        dev="$(echo "$line" | cut -f1 -d' ')"
        fstype="$(echo "$line" | cut -f2 -d' ')"
        mtpt="$(echo "$line" | cut -f3 -d' ')"

        if [ "$dev" = "$hdd" ]; then continue; fi

        if is_safemode_drive $dev ; then
            if [ "$fstype" = "swap" ]; then
                swapoff "$dev" 1> /dev/null 2>> $TMP/umount.errs
            elif [ -n "$mtpt" -a "$mtpt" != "/none" ]; then
                umount "$dev" 2>> $TMP/umount.errs

                if [ "$?" != 0 ]; then
                    missed="$missed $dev"
                fi
            fi
            sync
        fi
    done

    sync; sleep 1

    cat /proc/mounts | grep -F "$hdd" | cut -f1 -d' ' 1> $TMP/devices.lst

    cat $TMP/devices.lst | while read dev; do
        if is_safemode_drive $dev ; then
            umount "$dev" 2>> $TMP/umount.errs
            sync
        fi
    done

    if [ -n "$missed" ]; then
        for dev in $missed /target ; do
            if is_safemode_drive $dev ; then
                umount "$dev" 2>> $TMP/umount.errs
                sync
            fi
        done
    fi

    echo_message "L_CLOSING_EXISTING_LUKS_PARTITIONS"

    if [ -n "$luksmtpts" ]; then
        for dev in $luksmtpts ; do
            if is_safemode_drive $dev ; then
                close_crypto_device "$dev" "$hdd" "$lvmmtpts"
            fi
        done
    fi

    return 0
}

# end Breeze::OS script
