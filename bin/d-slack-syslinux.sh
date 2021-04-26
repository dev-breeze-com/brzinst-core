#!/bin/bash
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

d-select-boot.sh syslinux

if [ "$?" != 0 ]; then
	exit 1
fi

DERIVED="$(cat $TMP/selected-derivative 2> /dev/null)"
DEVICE="$(cat $TMP/boot-drive 2> /dev/null)"
DRIVE_NAME="$(cat $TMP/boot-drive-name 2> /dev/null)"
ROOT_DEVICE="$(mount | grep -F " on $ROOTDIR " | cut -f1 -d ' ')"
BOOT_PARTITION="$(cat $TMP/boot-partition 2> /dev/null)"

echo "no" 1> $TMP/boot-configured

mkdir -p $ROOTDIR/boot/extlinux/

if [ "$PROMPT" != "gui" ]; then

	d-info-prompt.sh bootcfg

	if [ "$?" != 0 ]; then
		exit 1
	fi
fi

cp -f ./install/factory/syslinux.cfg $ROOTDIR/boot/extlinux/
cp -f ./install/factory/syslinux-prompt.cfg $ROOTDIR/boot/extlinux/prompt.cfg
cp -f $MOUNTPOINT/isolinux/f*.txt $ROOTDIR/boot/extlinux/
cp -f $MOUNTPOINT/isolinux/splash.jpg $ROOTDIR/boot/extlinux/breeze.jpg

# First unmount /boot to let d-update-boot-loader.sh script remount it.
BOOTDEV="$(mount | grep -F '/boot ' | cut -f1 -d ' ')"
BOOTDIR="$(cat $TMP/boot-selected | cut -f2 -d '|')"
PART_NO="$(echo "$BOOT_PARTITION" | sed -r 's/[^0-9]*//g')"
UUID="$(lsblk -n -l -o 'uuid' $ROOT_DEVICE)"

if [ "$BOOTDEV" = "" ]; then
	chroot $ROOTDIR /sbin/d-update-boot-loader.sh \
		-m -t syslinux -d $DEVICE \
		-b "/" -B $ROOT_DEVICE \
		-R $ROOT_DEVICE -p $PART_NO 
		#-u "$UUID"
else
	umount "$BOOTDEV"
	sleep 1

	chroot $ROOTDIR /sbin/d-update-boot-loader.sh \
		-m -t syslinux -d $DEVICE \
		-b $BOOTDIR -B $BOOTDEV \
		-R $ROOT_DEVICE -p $PART_NO 
		#-u "$UUID"
	fi
fi

if [ "$?" = 0 ]; then
	echo -n "yes" 1> $TMP/boot-configured
fi

exit $?

# end Breeze::OS setup script
