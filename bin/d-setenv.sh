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
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR IMPLIED
# WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF 
# MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO
# EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, 
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
# PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
# OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, 
# WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR 
# OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF 
# ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
# ALL OTHER INSTALL SCRIPTS under install/bin HAVE THE SAME COPYRIGHT.
#
chmod a+rw /dev/null

test_mouse() {

	local count="$1"

	local log="/var/log/Xorg.0.log"
	local mouse="$(egrep -m1 'Mouse [(]/dev/input/event[0-9]+[)]' $log)"

	mouse="$(echo "$mouse" | sed -r 's/^.*Mouse [(]//g')"
	mouse="$(echo "$mouse" | sed -r 's/[()]//g')"

	if [ -n "$mouse" ]; then
		echo "INSTALLER: MESSAGE L_PLEASE_MOVE_YOUR_MOUSE"
		cat $mouse | read -n$count answer
	fi
	return 0
}

# The available uses for your hard drive are:
# - normal: use hard drive with normal partitions. 
# - lvm:     use LVM to partition the disk
# - raid:    use RAID drive partitioning method
# - crypto:  use LVM within an encrypted partition
DISKTYPE="normal"
DOMAIN="localdomain"

VPN=${BREEZE_VPN:-"no"}
REPO=${BREEZE_REPO:-"stable"}

ARCH=${BREEZE_ARCH:-"@BREEZE_ARCH@"}
VERSION=${BREEZE_VERSION:-"@BREEZE_VERSION@"}
DERIVED=${BREEZE_DERIVED:-"@BREEZE_DERIVED@"}
RELEASE=${BREEZE_RELEASE:-"@BREEZE_RELEASE@"}
PLATFORM=${BREEZE_PLATFORM:-"@BREEZE_PLATFORM@"}

KERNEL_NAME=${KERNEL_NAME:-"@KERNEL_NAME@"}
KERNEL_VERSION=${KERNEL_VERSION:-"@KERNEL_VERSION@"}

PRESEED=${BREEZE_PRESEED:-""}
INSTALL=${BREEZE_INSTALL:-"media"}
PKGTYPE=${BREEZE_PKGTYPE:-"squashfs"}
BRZMARK=${BREEZE_MARKER:-"BRZINSTALL"}

# Initialize folder paths
. d-dirpaths.sh

OSRELEASE=/etc/brzpkg/os-release

if [ -f $MOUNTPOINT/distfiles/os-release ]; then
	OSRELEASE=$MOUNTPOINT/distfiles/os-release
fi

if [ -z "$ARCH" ]; then
	ARCH="$(grep -E '^ARCH' $OSRELEASE | cut -f2 -d=)"
	[ -z "$ARCH" ] && ARCH="amd64"
fi

if [ -z "$VERSION" ]; then
	VERSION="$(grep -E '^VERSION' $OSRELEASE | cut -f2 -d=)"
	[ -z "$VERSION" ] && VERSION="stable"
fi

if [ -z "$DERIVED" ]; then
	DERIVED="$(grep -E '^SOURCE_DISTRO' $OSRELEASE | cut -f2 -d=)"
	[ -z "$DERIVED" ] && DERIVED="slackware"
fi

if [ -z "$PLATFORM" ]; then
	PLATFORM="$(grep -E '^PLATFORM' $OSRELEASE | cut -f2 -d=)"
	[ -z "$PLATFORM" ] && PLATFORM="linux"
fi

if [ -z "$TMP" -o "$TMP" = "/" ]; then
	mkdir -p /var/tmp/brzinst
	TMP="/var/tmp/brzinst"
fi

rm -f $TMP/do-restore 2> /dev/null
rm -f $TMP/config-init 2> /dev/null

find $TMP/ -name 'selected-*' -delete 2> /dev/null
find $TMP/ -name '*.csv' -delete 2> /dev/null
find $TMP/ -name '*.map' -delete 2> /dev/null
find $TMP/ -name '*.info' -delete 2> /dev/null
find $TMP/ -name '*.log' -delete 2> /dev/null
find $TMP/ -name '*.errs' -delete 2> /dev/null
find $TMP/ -name '*.err' -delete 2> /dev/null
find $TMP/ -name '*.lst' -delete 2> /dev/null

echo -n "$VPN" 1> $TMP/selected-vpn
echo -n "$ARCH" 1> $TMP/selected-arch
echo -n "$REPO" 1> $TMP/selected-repo
echo -n "$DOMAIN" 1> $TMP/selected-domain
echo -n "$VERSION" 1> $TMP/selected-version
echo -n "$ROOTDIR" 1> $TMP/selected-rootdir
echo -n "$RELEASE" 1> $TMP/selected-release
echo -n "$PRESEED" 1> $TMP/selected-preseed
echo -n "$DERIVED" 1> $TMP/selected-distro
echo -n "$DERIVED" 1> $TMP/selected-derivative
echo -n "$DISKTYPE" 1> $TMP/selected-disktype
echo -n "$INSTALL" 1> $TMP/selected-install-mode
echo -n "$PKGTYPE" 1> $TMP/selected-pkgtype
echo -n "$BRZMARK" 1> $TMP/livemedia-marker
echo -n "$PLATFORM" 1> $TMP/selected-platform

echo -n "1000" 1> $TMP/current.uid
echo -e "root\nsecadmin\n" 1> $TMP/users.lst
echo -n "L_INACTIVE" 1> $TMP/sysadmin-activated
echo -n "L_INACTIVE" 1> $TMP/secadmin-activated
echo -n "no" 1> $TMP/sysadmin
echo -n "no" 1> $TMP/secadmin

echo -n "US" 1> $TMP/selected-timezone-area
echo -n "US/Eastern" 1> $TMP/selected-timezone
echo -n "pc105" 1> $TMP/selected-keyboard
echo -n "us" 1> $TMP/selected-country
echo -n "en_US" 1> $TMP/selected-locale
echo -n "default" 1> $TMP/selected-kbd-layout
echo -n "qwerty" 1> $TMP/selected-keymap
echo -n "brzdm" 1> $TMP/selected-xdm
echo -n "xfce" 1> $TMP/selected-flavor
echo -n "xfce" 1> $TMP/selected-desktop
echo -n "192.168.2.1" 1> $TMP/selected-gateway
echo -n "syslinux" 1> $TMP/selected-bootloader
echo -n "standalone" 1> $TMP/selected-workgroup
echo -n "beginner" 1> $TMP/selected-expertise
echo -n "root-home" 1> $TMP/default-scheme
echo -n "openrc" 1> $TMP/default-initrc
echo -n "local" 1> $TMP/selected-network-source
echo -n "none" 1> $TMP/selected-acl

echo -n "$KERNEL_NAME" 1> $TMP/selected-kernel
echo -n "$KERNEL_VERSION" 1> $TMP/selected-kernel-version

cat /dev/null > $TMP/gpt-mbr-drives
cat /dev/null > $TMP/selected-users

cat /dev/null > $TMP/drives-selected.lst
cat /dev/null > $TMP/drives-formatted.lst
cat /dev/null > $TMP/drives-partitioned.lst

echo "device|mountpoint|fstype|options|freq|passno" 1> $TMP/fsmounts.csv
cat /proc/mounts | sed 's/[ ][ ]*/|/g' >> $TMP/fsmounts.csv
cat /proc/mounts | cut -f1 -d' ' 1> $TMP/drives-on-atboot.lst

echo "INSTALLER: MESSAGE L_PROBING_DEVICES"
sync; blkid 1> $TMP/blkid-uuid.log

mkfs.ext4 -V 2>&1 1> $TMP/mkfs.version

d-set-usernames.sh root quiet

d-set-usernames.sh secadmin quiet

#test_mouse 10

exit 0

# end Breeze::OS setup script
