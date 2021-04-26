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
# Initialize folder paths
. d-dirpaths.sh

. d-chroot-setup.sh

touch $TMP/config-init

if grep -iqE '^done$' $TMP/config-init ; then
	exit 0
fi

echo "INSTALLER: MESSAGE L_COPYING_TMP_FILES"
sync; sleep 1
cp -af $TMP/* $ROOTDIR/tmp/

d-etc.sh

if [ -r /etc/lvmtab -o -d /etc/lvm/backup ]; then
	echo "on" 1> $ROOTDIR/tmp/lvm-enabled
fi

echo "INSTALLER: MESSAGE L_INIT_LIBRARIES"
sync; sleep 1

chroot_setup
chroot $ROOTDIR /sbin/ldconfig
chroot_cleanup

sync; sleep 1
echo -n "done" 1> $TMP/config-init

exit 0

# end Breeze::OS setup script
