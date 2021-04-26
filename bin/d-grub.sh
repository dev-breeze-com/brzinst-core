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

DEVICE="$(cat $TMP/selected-boot-drive 2> /dev/null)"
GPTMODE="$(cat $TMP/selected-gpt-mode 2> /dev/null)"
SRCDEV="$(cat $TMP/selected-source 2> /dev/null)"
ROOTDEV="$(cat $TMP/root-device 2> /dev/null)"
BOOTDEV="$(cat $TMP/boot-device 2> /dev/null)"
BOOTMGR="$(cat $TMP/selected-bootloader 2> /dev/null)"

echo "no" 1> $TMP/boot-configured

UUID="$(lsblk -n -l -o 'uuid' $ROOTDEV)"
#uuid="$(lsblk -n -l -o 'uuid' $BOOTDEV)"

if [ "$BOOTDEV" != "$ROOTDEV" ]; then
	# First unmount /boot to let d-bootcfg.sh remount it.
	umount "$BOOTDEV"
	sleep 1
fi

# Partition number is always 1
# Points to the /boot partition
PART_NO="1"

ALL_OSES="$(extract_value bootloader 'all-oses')"

if [ "$ALL_OSES" = "yes" ]; then ALL="-a"; fi

chroot_setup
chroot $ROOTDIR /sbin/d-update-bootcfg.sh $ALL \
	-k $KERNEL \
	-t $BOOTMGR -g $GPTMODE -d $DEVICE \
	-b /boot -B $BOOTDEV \
	-R $ROOTDEV -p $PART_NO \
	-u "$UUID" -S "$SRCDEV"
retcode=$?
chroot_cleanup

if [ "$retcode" = 0 ]; then
	echo -n "yes" 1> $TMP/boot-configured
fi

exit $retcode

# end Breeze::OS setup script
