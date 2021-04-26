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

. d-format-utils.sh

MEDIA="$(cat $TMP/selected-media 2> /dev/null)"
DEVICE="$(cat $TMP/selected-target 2> /dev/null)"
MEDIA="$(echo "$MEDIA" | tr '[:lower:]' '[:upper:]')"

chmod 755 $ROOTDIR
chmod 1777 $ROOTDIR/tmp

# Cleanup $ROOTDIR/tmp
find $ROOTDIR/tmp/ -delete 2> /dev/null

# Remove any files stored under /boot/luks
find $ROOTDIR/var/tmp/brzinst/boot/ -delete 2> /dev/null

# Remove installer file, if any
rm -f $ROOTDIR/etc/installer 2> /dev/null

# Remove marker files, if any
unlink $ROOTDIR/BRZLIVE 2> /dev/null
unlink $ROOTDIR/BRZINSTALL 2> /dev/null

for name in $(ls /target/) ; do
	name="$(basename $name)"
	umount /target/$name 2> /dev/null
done

if [ -n "$DEVICE" ]; then
	unmount_devices $DEVICE
fi

if [ -n "$MOUNTUSB" ]; then
	umount $MOUNTUSB 2> /dev/null
fi

if [ -n "$MOUNTPOINT" ]; then
	umount $MOUNTPOINT 2> /dev/null
fi

umount /target 2> /dev/null
umount /mnt/livemedia 2> /dev/null
umount /mnt/instmedia 2> /dev/null

if [ "$MEDIA" = "CDROM" -o "$MEDIA" = "DVD" ]; then
	eject /dev/cdrom 2> /dev/null
fi

echo "done" 1> /tmp/reboot-now
exit 0

# end Breeze::OS setup script
