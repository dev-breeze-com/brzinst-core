#!/bin/bash
#
# GNU GENERAL PUBLIC LICENSE -- Version 3
#
# Copyright 2013 Pierre Innocent, Tsert Inc., All Rights Reserved
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

DEVICE="$(cat $TMP/selected-boot-drive)"
DERIVED="$(cat $TMP/selected-derivative)"
BOOTMGR="$(cat $TMP/selected-boot-loader)"
GPT_MODE="$(extract_value scheme 'gpt-mode' 'upper')"

lsblk -p -n -o 'kname,mountpoint' $DEVICE | \
	grep -E -m1 ' /target$' | cut -f1 -d' ' 1> $TMP/root-device

ROOTDEV="$(cat $TMP/root-device 2> /dev/null)"
ROOTFS="$(lsblk -n -o fstype $ROOTDEV)"

# Boot device is always the first one
BOOTDEV=${DEVICE}1
BOOTDIR=/boot

echo "$BOOTDEV" 1> $TMP/boot-device

mounted="$(mount | grep -F -m1 "$ROOTDIR/boot ")"

if [ "$mounted" = "" ]; then
	echo "INSTALLER: MESSAGE L_MOUNTING_BOOT_FS"
	mount $BOOTDEV $ROOTDIR/boot
	sleep 1
fi

/bin/cp -a ./install/bin/d-bootcfg.sh $ROOTDIR/sbin/d-update-bootcfg.sh

KERNEL="$(find $ROOTDIR/boot | grep -F -m1 'vmlinuz-')"
KERNEL="$(basename "$KERNEL" | sed 's/vmlinuz[-]*//g')"

ROOTFS="$(lsblk -n -o fstype $ROOTDEV | crunch)"
BOOTFS="$(lsblk -n -o fstype $BOOTDEV | crunch)"

SCSI="scsi_mod:sd_mod:sr_mod" 

if [ "$GPT_MODE" = "UEFI" ]; then
	MODULES="$ROOTFS:$BOOTFS:$SCSI:ehci-hcd:uhci-hcd:usbhid:dm-mod:efivarfs"
else
	MODULES="$ROOTFS:$BOOTFS:$SCSI:ehci-hcd:uhci-hcd:usbhid:dm-mod"
fi

echo "INSTALLER: MESSAGE L_CREATING_INITRD"
chroot_setup
chroot $ROOTDIR mkinitrd -c -u -L \
	-k $KERNEL \
	-f $ROOTFS -r $ROOTDEV \
	-m "$MODULES" \
	-o /boot/initrd.img-${KERNEL}.gz
retcode=$?
chroot_cleanup

if [ "$retcode" != 0 ]; then
	echo "INSTALLER: FAILURE L_INITRD_FAILURE"
	exit 1
fi

if [ "$BOOTMGR" = "lilo" ]; then
	d-lilo.sh batch
elif [ "$BOOTMGR" = "gummiboot" ]; then
	d-gummiboot.sh batch
elif [ "$BOOTMGR" = "elilo" ]; then
	d-elilo.sh batch
elif [ "$BOOTMGR" = "syslinux" ]; then
	d-syslinux.sh batch
else
	d-grub.sh batch
fi

exit $?

# end Breeze::OS setup script
