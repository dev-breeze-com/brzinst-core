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

if [ -f "$TMP/initcfg.log" ]; then
	rsync -av $TMP/* $ROOTDIR/tmp/
	exit 0
fi

if [ ! -d $ROOTDIR/sys ]; then
	mkdir -p $ROOTDIR/sys
	chown root.root $ROOTDIR/sys
fi

# Make sure /etc/dhcpc is present
mkdir -p $ROOTDIR/etc/dhcpc
chmod 0755 $ROOTDIR/etc/dhcpc

# Make sure /etc/network is present
mkdir -p $ROOTDIR/etc/network
chmod 0755 $ROOTDIR/etc/network

# Make sure /boot is readable by all
mkdir -p $ROOTDIR/boot
chmod 0755 $ROOTDIR/
chmod 0755 $ROOTDIR/boot

# Make sure /tmp is readable by all
mkdir -p $ROOTDIR/tmp
chmod 1777 $ROOTDIR/tmp

# Copy temporary files ...
rsync -av $TMP/* $ROOTDIR/tmp/

# For X11 to work properly
mkdir -p $ROOTDIR/var
chmod 0755 $ROOTDIR/var

mkdir -p $ROOTDIR/var/tmp
chmod 1777 $ROOTDIR/var/tmp

# For X11 to work properly
mkdir -p $ROOTDIR/var/lock
chmod 1777 $ROOTDIR/var/lock

if [ ! -d $ROOTDIR/proc ]; then
	mkdir -p $ROOTDIR/proc
	chown root.root $ROOTDIR/proc
fi

#if [ ! -d $ROOTDIR/var/spool/mail ]; then
#	mkdir -p $ROOTDIR/var/spool/mail
#	chmod 0755 $ROOTDIR/var/spool
#	chown root.mail $ROOTDIR/var/spool/mail
#	chmod 1777 $ROOTDIR/var/spool/mail
#fi

# Make sure that /var/run/dbus exists ...
mkdir -p $ROOTDIR/var/run/dbus

# Copy openssl settings to root device
if [ -f $TMP/openssl.cnf ]; then
	cp -f $TMP/openssl.cnf $ROOTDIR/etc/ssl/
fi

# Copy ddclient configuration ...
if [ -f $TMP/ddclient.conf ]; then
	cp -f $TMP/ddclient.conf $ROOTDIR/etc/
fi

if [ -r /etc/lvmtab -o -d /etc/lvm/backup ]; then
	echo "on" 1> $ROOTDIR/tmp/lvm-enabled
fi

# Make folder for config scripts
mkdir -p $ROOTDIR/var/log/scripts/
mkdir -p $ROOTDIR/var/log/packages/
mkdir -p $ROOTDIR/var/log/setup/

# Simplified Mandatory Access Control
mkdir -p "$ROOTDIR/smack"
mkdir -p "$ROOTDIR/etc/smack"

# Copy dhcp files to root device
cp -a /etc/dhcpc $ROOTDIR/etc/
cp -f /etc/resolv.conf $ROOTDIR/etc/

# Copy the device information in the mtab
grep -v rootfs /proc/mounts 1> $ROOTDIR/etc/mtab

#if [ ! -d $ROOTDIR/sys/block ]; then
#	cp -rfPdp /sys/ $ROOTDIR/ 2> /dev/null
#fi

# Mirror /dev on mount location
#mount --bind /dev $ROOTDIR/dev

# Mirror /proc on mount location
#mount --bind /proc $ROOTDIR/proc

# Mirror /sys on mount location
#mount --bind /sys $ROOTDIR/sys

# Mirror /devpts on mount location
#mount -t devpts none $ROOTDIR/dev/pts

touch $TMP/initcfg.log

exit 0
