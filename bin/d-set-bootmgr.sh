#!/bin/bash
#
# GNU GENERAL PUBLIC LICENSE Version 3
#
# Copyright 2015 Pierre Innocent, Tsert Inc., All Rights Reserved
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

. d-chroot-setup.sh

find_platform() {
    local platform="$(cat $TMP/selected-platform 2> /dev/null)"
    local osrelease="$ROOTDIR/etc/brzpkg/os-release"

    if [ -z "$platform" ] || echo "$platform" | grep -qF '@' ; then
        if [ -e $osrelease ]; then
            if grep -qE "SOURCE_DISTRO=netbsd" $osrelease ; then
                platform="netbsd"
            elif grep -qE "SOURCE_DISTRO=openbsd" $osrelease ; then
                platform="openbsd"
            else
                platform="linux"
            fi
        fi
    fi

    echo "$platform"
    return 0
}

find_kernel() {
    local kernel="$(cat $TMP/selected-kernel-version 2> /dev/null)"
    local osrelease="$ROOTDIR/etc/brzpkg/os-release"

    if [ -z "$kernel" ] || echo "$kernel" | grep -qF '@' ; then
		if [ -e $osrelease ]; then
			kernel="$(grep -F "KERNEL_RELEASE=" $osrelease | cut -f2 -d=)"
		fi

		if [ -z "$kernel" -o ! -e "$ROOTDIR/lib/modules/$kernel" ]; then
			kernel="$(ls /lib/modules/ | tr '\n' ' ' | cut -f1 -d' ')"
			kernel="$(echo "$kernel" | tr -d '/')"
		fi
	fi

    echo "$kernel"
    return 0
}

DEVICE="$(cat $TMP/selected-boot-drive 2> /dev/null)"
GPTMODE="$(cat $TMP/selected-gpt-mode 2> /dev/null)"
BOOTMGR="$(cat $TMP/selected-bootloader 2> /dev/null)"
SRCDEV="$(cat $TMP/selected-source 2> /dev/null)"

LINUXES="$(extract_value bootloader 'linuxes')"
WINDOWS="$(extract_value bootloader 'windows')"

ROOTDEV="$(cat $TMP/root-device 2> /dev/null)"
BOOTDEV="$(cat $TMP/boot-device 2> /dev/null)"

BOOT_UUID="$(blkid -o value -s UUID $BOOTDEV)"
ROOT_UUID="$(blkid -o value -s UUID $ROOTDEV)"

LUKS_DEVICES="$(cat $TMP/luks-devices 2> /dev/null)"

EFI=false
KERNEL="$(find_kernel)"
PLATFORM="$(find_platform)"

# Partition number is always 1
# Points to the /boot partition
PART_NO="1"
OPTIONS="-y"

echo "no" 1> $TMP/boot-configured

GPTMODE="$(echo $GPTMODE | tr '[:upper:]' '[:lower:]')"

[ "$LINUXES" = "yes" ] && OPTIONS="$OPTIONS -x"
[ "$WINDOWS" = "yes" ] && OPTIONS="$OPTIONS -w"

if [ -n "$LUKS_DEVICES" ]; then
    LUKS_DEVICES="$(echo "$LUKS_DEVICES" | tr -s ';' ',')"
    OPTIONS="$OPTIONS -luks $LUKS_DEVICES"
fi

if echo "$PLATFORM" | grep -qF 'bsd' ; then
    EFILABEL="Breeze::OS BSD/Unix ($KERNEL)"
else
    EFILABEL="Breeze::OS Linux ($KERNEL)"
fi

if [ -e /sys/firmware/efi ]; then
    if [ "$GPTMODE" = "uefi" -o "$GPTMODE" = "s-uefi" ]; then
        EFI=true
    fi
fi

if [ -n "$BOOTDEV" -a "$BOOTDEV" != "$ROOTDEV" ]; then
    # First unmount /boot -- let d-update-bootcfg.sh remount it.
    umount "$BOOTDEV" 2> /dev/null
    sync; sleep 1
fi

chroot_setup

# GRUB is used only for UEFI booting; otherwise,
# syslinux bootloader is used.
#
if [ "$EFI" = true -a "$BOOTMGR" = "grub" ]; then
    chroot $ROOTDIR /bin/env -i /sbin/d-update-bootcfg.sh $OPTIONS \
        -k $KERNEL -t grub -g $GPTMODE -dev $DEVICE \
        -b /boot -B $BOOTDEV -U "$BOOT_UUID" \
        -R $ROOTDEV -u "$ROOT_UUID" -p $PART_NO \
        -E "$EFILABEL" -srcdev "$SRCDEV"

    if [ $? = 0 ]; then
        chroot $ROOTDIR /bin/env -i /sbin/d-update-bootcfg.sh $OPTIONS \
            -k $KERNEL -t syslinux -g gpt -dev $DEVICE \
            -b /boot -B $BOOTDEV -U "$BOOT_UUID" \
            -R $ROOTDEV -u "$ROOT_UUID" -p $PART_NO
    fi
else
    chroot $ROOTDIR /bin/env -i /sbin/d-update-bootcfg.sh $OPTIONS \
        -k $KERNEL -t syslinux -g $GPTMODE -dev $DEVICE \
        -b /boot -B $BOOTDEV -U "$BOOT_UUID" \
        -R $ROOTDEV -u "$ROOT_UUID" -p $PART_NO \
        -E "$EFILABEL"
fi

retcode=$?
chroot_cleanup

if [ "$retcode" = 0 ]; then
    echo -n "yes" 1> $TMP/boot-configured
fi

if [ "$retcode" != 0 ]; then
    exit 1
fi

exit 0

# end Breeze::OS setup script
