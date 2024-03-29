#!/bin/bash
#
# GNU GENERAL PUBLIC LICENSE Version 3
#
# Sylinux Installer / Updater Scripts
# Copyright (C) 2011  Matthew Gyurgyik <pyther@pyther.net>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
#-----------------
# Exit Codes:
#   1 - get_boot_device or other function failed
#   2 - install/update failed
#   3 - set_active failed
#   4 - install_mbr failed
#
shopt -s nullglob

libpath="/usr/lib/syslinux"
bootpath="/boot/syslinux"
extlinux="/sbin/extlinux"

autoupdate_file=/boot/syslinux/SYSLINUX_AUTOUPDATE
com32_files=(menu.c32 vesamenu.c32 chain.c32 hdt.c32 reboot.c32 poweroff.com)
pciids_file=/usr/share/hwdata/pci.ids

## Helper functions ##
# Taken from libui-sh
# $1 needle
# $2 set (array) haystack
check_is_in() {
    local needle="$1" element
    shift
    for element; do
        [[ $element = $needle ]] && return 0
    done
    return 1
}

# return true when blockdevice is an md raid, otherwise return a unset value
# get all devices that are part of raid device $1
device_is_raid() {
    [[ $1 && -f /proc/mdstat ]] || return 1
    local devmajor=$(stat -c %t "$1")
    (( devmajor == 9 ))
}

mdraid_all_slaves() {
    local slave slaves
    for slave in /sys/class/block/${1##*/}/slaves/*; do
        source "$slave/uevent"
        slaves="$slaves/dev/$DEVNAME "
        unset DEVNAME
    done
    echo $slaves
}

# Check /sys/block to see if device is partitioned
# If we have a partitioned block device (sda1) /sys/block/sda1/dev will not exist
# However, if we have an unpartitioned block device (sda) /sys/block/sda/dev will exist
dev_is_part() {
    # $1 - blockdevice
    local dev=$1

    # If block device uevent file should be found
    # If a partition is passed in path shouldn't exist
    if [[ $dev = *cciss* ]]; then
        [[ -f /sys/block/cciss\!${dev##*/}/dev ]] && return 1
    elif [[ $dev = *ida* ]]; then
        [[ -f /sys/block/ida\!${dev##*/}/dev ]] && return 1
    else
        [[ -f /sys/block/${dev##*/}/dev ]] && return 1
    fi

    return 0
}

# If EFI PART is present in the first 8 bytes then it must be a GPT disk
device_is_gpt() {
    local partsig=$(dd if="$1" skip=64 bs=8 count=1 2>/dev/null)
    [[ $partsig = "EFI PART" ]]
}

clear_gpt_attr2() {
    # $1 - Block Device, no partitions
    local disk=$1

    # Special Exception for cciss controllers
    if [[ $disk = *cciss* ]]; then
        for part in /dev/cciss/${disk##*/}*p*; do
            local partnum="${part##*[[:alpha:]]}"
            sgdisk "$disk" --attributes="$partnum":clear:2 &>/dev/null
        done
    # Smart 2 Controllers
    elif [[ $disk = *ida* ]]; then
        for part in /dev/ida/${disk##*/}*p*; do
            local partnum="${part##*[[:alpha:]]}"
            sgdisk "$disk" --attributes="$partnum":clear:2 &>/dev/null
        done
    else
        for part in  /sys/block/${disk##*/}/${disk##*/}*; do
            local partnum="${part##*[[:alpha:]]}"
            sgdisk "$disk" --attributes="$partnum":clear:2 &>/dev/null
        done
    fi
    return 0
}

usage() {
cat << EOF
usage: $0 options

This script will install or upgrade Syslinux

OPTIONS:
  -h    Show this message
  -i    Install Syslinux
  -u    Update Syslinux
  -a    Set Boot flag on boot partiton
  -m    Install Syslinux MBR
  -s    Updates Syslinux if /boot/syslinux/SYSLINUX_AUTOUPDATE exists

 Arguments Required:
  -c    Chroot install (ex: -c /mnt)

Example Usage: syslinux-install_update.sh -i -a -m (install, set boot flag, install mbr)
               syslinux-install_update.sh -u (update)
EOF
}

# Trys to find the partition that /boot resides on
# This will either be on /boot or / (root)
getBoot() {
    if [[ ! -d "$bootpath" ]]; then
        echo "Could not find $bootpath"
        echo "Is boot mounted? Is Syslinux installed?"
        exit 1
    fi

    syslinux_fs=(ext2 ext3 ext4 btrfs vfat)

    # Use DATA from findmnt see rc.sysint for more info
    if [[ -f /proc/self/mountinfo ]]; then
        read rootdev rootfs < <(findmnt -run -t noautofs -o SOURCE,FSTYPE "$CHROOT/")
        read bootdev bootfs < <(findmnt -run -t noautofs -o SOURCE,FSTYPE "$CHROOT/boot")
    else
        echo "Could not find /proc/self/mountinfo"
        echo "Are you running a kernel greater than 2.6.24?"
        exit 1
    fi

    if [[ $bootfs ]]; then
        if ! check_is_in "$bootfs" "${syslinux_fs[@]}"; then
            echo "/boot file system is not supported by Syslinux"
            exit 1
        fi
        boot="boot"
        bootpart="$bootdev"
    elif [[ $rootfs ]]; then
        if ! check_is_in "$rootfs" "${syslinux_fs[@]}"; then
            echo "/ (root) file system is not supported by Syslinux"
            exit 1
        fi
        boot="root"
        bootpart="$rootdev"
    else
        echo "Could not find filesystem on / (root) or /boot."
        exit 1
    fi
}

# We store the partition table type either gpt or mbr in var ptb
# In rare cases a user could have one raid disk using mbr and another using gpt
# In such cases we accept that the output may be incomplete

# Calls get_ptb() for $bootpart or for all device in RAID
declare -A bootdevs
get_boot_devices() {
    if device_is_raid "$bootpart"; then
        slaves=$(mdraid_all_slaves "$bootpart")

        for slave in ${slaves[@]}; do
            local disk="${slave%%[[:digit:]]*}"
            device_is_gpt "$disk" && local ptb="GPT" || local ptb="MBR"
            bootdevs[$slave]="$ptb"
        done
    else
        local disk="${bootpart%%[[:digit:]]*}"
        device_is_gpt "$disk" && local ptb="GPT" || local ptb="MBR"
        bootdevs[$bootpart]="$ptb"
    fi
}

# Function Assumes the boot partition should be marked as active
# All other partitions should not have the boot flag set
set_active() {
    # If any bootdev is a block device without partitions bail
    # we want to set the boot flag on partitioned disk
    for dev in "${!bootdevs[@]}"; do
        dev_is_part $dev || { echo "$dev - is a block device. Aborting set_active!"; return 1; }
    done

    # Clear BIOS Bootable Legacy Attribute for GPT drives
    # In rare cases where a RAID device has slaves on the same block device
    # Attribute 2 will be cleared for each partition multiple times
    for dev in "${!bootdevs[@]}"; do
        local ptb="${bootdevs[$dev]}"
        if [[ "$ptb" = GPT ]]; then
            local disk="${dev%%[[:digit:]]*}" #ex: /dev/sda
            clear_gpt_attr2 "$disk"
        fi
    done

    # Set the boot flag on bootdevs (generated from get_boot_devices)
    for part in "${!bootdevs[@]}"; do
        local ptb="${bootdevs[$part]}"
        local partnum="${part##*[[:alpha:]]}"
        case "$part" in
            *[[:digit:]]p[[:digit:]]*)
                local disk="${part%%p$partnum}" # get everything before p1
                ;;
            *)
                local disk="${part%%[[:digit:]]*}"
                ;;
        esac

        if [[ "$ptb" = MBR ]]; then
            if sfdisk "$disk" -A "$partnum" &>/dev/null; then
                echo "Boot Flag Set - $part"
            else
                echo "FAILED to Set the boot flag on $part"
                exit 3
            fi
        elif [[ "$ptb" = GPT ]]; then
            if sgdisk "$disk" --attributes="$partnum":set:2 &>/dev/null; then
                echo "Attribute Legacy Bios Bootable Set - $part"
            else
                echo "FAILED to set attribute Legacy BIOS Bootable on $part"
                exit 3
            fi
        fi
    done
    return 0
}

install_mbr() {
    # If any bootdev is a block device without partitions bail
    # we want to install the mbr to a partitioned disk
    for dev in "${!bootdevs[@]}"; do
        dev_is_part "$dev" || { echo "$dev - is a block device. Aborting MBR install"; return 1; }
    done

    for part in "${!bootdevs[@]}"; do
        local partnum="${part##*[[:alpha:]]}"
        case "$part" in
            *[[:digit:]]p[[:digit:]]*)
                local disk="${part%%p$partnum}" # get everything before p1
                ;;
            *)
                local disk="${part%%[[:digit:]]*}"
                ;;
        esac
        local ptb="${bootdevs[$part]}"

        # We want to install to the root of the block device
        # If the device is a partition - ABORT!
        dev_is_part "$disk" && \
        { echo "ABORT! MBR installation to partition ($disk)!"; exit 4;}

        if [[ "$ptb" = MBR ]]; then
            mbrfile="$libpath/mbr.bin"
        elif [[ "$ptb" = GPT ]]; then
            mbrfile="$libpath/gptmbr.bin"
        fi

        if dd bs=440 count=1 conv=notrunc if="$mbrfile" of="$disk" &> /dev/null; then
            echo "Installed MBR ($mbrfile) to $disk"
        else
            echo "Error Installing MBR ($mbrfile) to $disk"
            exit 4
        fi
    done
    return 0
}

_install() {
    # Copy files to /boot
    for file in "${com32_files[@]}"; do
        # Symlink files even if links exist
        if [[ "$boot" = root ]]; then
            ln -s "${libpath#$CHROOT}/$file" "$bootpath/$file" &> /dev/null
        elif [[ "$boot" = boot ]]; then
            cp "$libpath/$file" "$bootpath/$file"
        fi
    done

    # Copy / Symlink pci.ids if we copy the com32 module and if pci.ids exists in the FS
    if check_is_in "hdt.c32" "${com32_files[@]}" && [[ -f $pciids_file ]]; then 
        if [[ "$boot" = root ]]; then
            ln -s "$pciids_file" "$bootpath/pci.ids" &> /dev/null
        elif [[ "$boot" = boot ]]; then
            cp "$pciids_file" "$bootpath/pci.ids" &> /dev/null
        fi
    fi

    if device_is_raid "$bootpart"; then
        echo "Detected RAID on /boot - installing Syslinux with --raid"
        "$extlinux" --install "$bootpath" -r > /dev/null 2>&1
    else
        "$extlinux" --install "$bootpath" > /dev/null 2>&1
    fi

    if (( $? )); then
        echo "Syslinux install failed"
        exit 2
    else
        echo "Syslinux install successful"
    fi

    touch "$CHROOT/$autoupdate_file"
}

update() {
    # Update any com and c32 files in /boot
    if [[ "$boot" = boot ]]; then
        for file in "$bootpath"/*.{c32,com}; do
            file=$(basename "$file")
            cp "$libpath/$file" "$bootpath/$file" &> /dev/null
        done
        if [[ -f "$bootpath/pci.ids" ]]; then
            cp "$pciids_file" "$bootpath/pci.ids" &> /dev/null
        fi
    fi

    if device_is_raid $bootpart; then
        echo "Detected RAID on /boot - installing Syslinux with --raid"
        "$extlinux" --update "$bootpath" -r &> /dev/null
    else
        "$extlinux" --update "$bootpath" &> /dev/null
    fi

    if (($?)); then
        echo "Syslinux update failed"
        exit 2
    else
        echo "Syslinux update successful"
    fi
}

# Make sure only root can run our script
if (( $(id -u) != 0 )); then
    echo "This script must be run as root" 1>&2
    exit 1
fi

if (( $# == 0 )); then
    usage
    exit 1
fi

while getopts "c:uihmas" opt; do
    case $opt in
        c)
            CHROOT=$(readlink -e "$OPTARG")
            if [[ -z $CHROOT ]]; then
                echo "error: chroot path ``$OPTARG does not exist";
                exit 1
            fi
            ;;
        h)
            usage
            exit 0
            ;;
        i)
            INSTALL="True"
            ;;
        u)
            UPDATE="True"
            ;;
        m)
            MBR="True"
            ;;
        a)
            SET_ACTIVE="True"
            ;;
        s)
            # If AUTOUPDATE_FILE does not exist exit the script
            if [[ -f $autoupdate_file ]]; then
                UPDATE="True"
            else
                exit 0
            fi
            ;;
        *)
            usage
            exit 1
            ;;
    esac
done

# Display Usage Information if both Install and Update are passed
if [[ $INSTALL && $UPDATE ]]; then
    usage
    exit 1
fi

# If a chroot dir is path set variables to reflect chroot
if [[ "$CHROOT" ]]; then
    libpath="$CHROOT$libpath"
    bootpath="$CHROOT$bootpath"
    extlinux="$CHROOT$extlinux"
fi

# Exit if no /boot path exists
if ( f=("$bootpath"/*); (( ! ${#f[@]} )) ); then
    echo "Error: $bootpath is empty!"
    echo "Is /boot mounted?"
    exit 1
fi

# Get the boot device if any of these options are passed
if [[ $INSTALL || $UPDATE || $SET_ACTIVE || $MBR ]]; then
    getBoot
fi

# Install or Update
if [[ $INSTALL ]]; then
    _install || exit
elif [[ $UPDATE ]]; then
    update || exit
fi


# SET_ACTIVE and MBR
if [[ $SET_ACTIVE ]] || [[ $MBR ]]; then
    get_boot_devices

    if [[ $SET_ACTIVE ]]; then
        set_active || exit
    fi

    if [[ $MBR ]]; then
        install_mbr || exit
    fi
fi

exit 0

# vim: set et sw=4:
