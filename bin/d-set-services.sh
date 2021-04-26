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

DEVICE="$1"

TARGET="$(cat $TMP/selected-target 2> /dev/null)"

if ! is_valid_device "$DEVICE" ; then
	echo_failure "L_NO_DEVICE_SPECIFIED"
	exit 1
fi

if ! is_safemode_drive "$DEVICE" ; then
	echo_error "L_SAFEMODE_DRIVE_SELECTED !"
	exit 1
fi

if [ "$TARGET" != "$DEVICE" ]; then
    echo_failure "L_TARGET_DRIVE_UNSPECIFIED"
    exit 1
fi

mkdir -p $ROOTDIR/etc/config/uefi
mkdir -p $ROOTDIR/etc/config/network
mkdir -p $ROOTDIR/etc/config/settings
mkdir -p $ROOTDIR/etc/config/services

chmod 0750 $ROOTDIR/etc/config/uefi
chmod 0755 $ROOTDIR/etc/config/network
chmod 0755 $ROOTDIR/etc/config/settings
chmod 0755 $ROOTDIR/etc/config/services

metadata="xdm lan hwnet xorg hostcfg nis workgroup dialup adsl cable wireless internet firewall openssl zram vpn indexer ssmtp rngd ddclient pppoe monitoring services displaymgr"

for meta in $metadata ; do
    if [ -f $TMP/${meta}.map ]; then
        cp -f $TMP/${meta}.map $ROOTDIR/etc/config/settings/${meta}
        chmod 0640 $ROOTDIR/etc/config/settings/${meta}
    elif [ -f $TMP/selected-${meta} ]; then
        cp $TMP/selected-$meta $ROOTDIR/etc/config/settings/${meta}
        chmod 0640 $ROOTDIR/etc/config/settings/${meta}
    fi
done

sync
exit 0

# end Breeze::OS setup script
