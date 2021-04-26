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

# Load current selections
. d-selected-options.sh

get_root_fs() {

	local device="$(mount | grep -F " on $ROOTDIR/boot " | cut -f1 -d ' ')"

	if [ "$device" = "" ]; then
		device="$(mount | grep -F " on $ROOTDIR " | cut -f1 -d ' ')"
	fi

	local rootfs="$(lsblk -n -l -o 'fstype' $device)"

	echo -n "$rootfs"
	return 0
}

update_list() {

	local excludes="lightdm|desktop[-]printing"
	local excl_loaders=""

	if [ "$BOOTMGR" = "syslinux" ]; then
		excl_loaders="lilo|grub"
	elif [ "$BOOTMGR" = "grub" ]; then
		excl_loaders="lilo|syslinux"
	elif [ "$BOOTMGR" = "lilo" ]; then
		excl_loaders="grub|syslinux"
	fi

	grep -E -v "$excl_loaders" $TMP/packages.lst 1> $TMP/pkglist

#	if [ "$DISKTYPE" = "normal" ]; then
#		excludes="$excludes|mdadm_|lvm2_|dmsetup_"
#	fi

	if [ "$INTERNET" = "none" ]; then
		excludes="$excludes|wvdial|libwvstreams|postfix|dovecot|ssmtp|sendmail"
	elif [ "$INTERNET" != "dialup" ]; then
		excludes="$excludes|wvdial|libwvstreams"
	fi

	if [ "$INTERNET" != "router" ]; then
		excludes="$excludes|flash[-]player[-]plugin|webcore"
	fi

	if [ "$NIS" != "nis" -o "$NIS" = "disabled" ]; then
		excludes="$excludes|yptools"
	fi

	if [ "$MDA" != "dovecot" -o "$MDA" = "disabled" ]; then
		excludes="$excludes|dovecot"
	fi

	if [ "$MDA" != "maildrop" -o "$MDA" = "disabled" ]; then
		excludes="$excludes|maildrop"
	fi

	if [ "$MTA" != "postfix" -o "$MTA" = "disabled" ]; then
		excludes="$excludes|postfix"
	fi

	if [ "$MTA" != "ssmtp" -o "$MTA" = "disabled" ]; then
		excludes="$excludes|ssmtp"
	fi

	if [ "$TFTP" != "tftp-hpa" -o "$TFTP" = "disabled" ]; then
		excludes="$excludes|tftp[-]hpa"
	fi

	if ! grep -q -F -m1 nvidia $DRIVERS ; then
		excludes="$excludes|nvidia"
	fi

	grep -E -v "$excludes" $TMP/pkglist 1> $TMP/packages.lst
	return 0
}

check_nb_pkgs() {

	local disk_sz=""
	local nb_pkgs=""
	local desktop="$1"
	local pkglist="$BRZDIR/desktop/$desktop.lst"

	if [ "$MEDIA" = "NETWORK" -a -f "$TMP/netinstall.lst" ]; then
		pkglist="$TMP/netinstall.lst"
	fi

	if [ ! -f "$pkglist" -o ! -s "$pkglist" ]; then
		echo "INSTALLER: FAILURE L_PACKAGE_LIST_MISSING"
		return 1
	fi

	grep -F -v "Stats: " $pkglist 1> $TMP/packages.lst

	local stats="$(grep -F 'Stats: ' $pkglist | /bin/sed 's/Stats: //g')"

	disk_sz="$(echo "$stats" | cut -f 3 -d /)"

	ROOT_FS="$(get_root_fs)"

	update_list $BOOTMGR

	wc -l $TMP/packages.lst | cut -f1 -d' ' 1> $TMP/pkg-total

	echo "$disk_sz" 1> $TMP/pkg-footprint

	return 0
}

# Main starts here ...
ARCH="$(cat $TMP/selected-arch 2> /dev/null)"
MEDIA="$(cat $TMP/selected-media 2> /dev/null)"
INSTALL_MEDIA="$(cat $TMP/install-media 2> /dev/null)"

DEVICE="$(cat $TMP/selected-device 2> /dev/null)"
DESKTOP="$(cat $TMP/selected-desktop 2> /dev/null)"
GPT_MODE="$(cat $TMP/selected-gpt-mode 2> /dev/null)"
DISKTYPE="$(cat $TMP/selected-disktype 2> /dev/null)"
RELEASE="$(cat $TMP/selected-release 2> /dev/null)"
DERIVED="$(cat $TMP/selected-derivative 2> /dev/null)"
INTERNET="$(cat $TMP/selected-connection 2> /dev/null)"

MTA="$(extract_value services mta)"
TFTP="$(extract_value services tftp)"
MDA="$(extract_value services mda)"
NIS="$(extract_value services nis)"

DRIVERS="$TMP/xorg-drivers"
AMD64="$(uname -p | grep -E -i 'amd.*64')"

BOOTMGR="$(cat $TMP/selected-bootloader 2> /dev/null)"
BOOTMGR="$(echo "$BOOTMGR" | tr '[:upper:]' '[:lower:]')"

if check_nb_pkgs $DESKTOP ; then
	sed -r 's/^.*\///g' "$TMP/packages.lst" 1> "$TMP/pkg-names.lst"
	sed -r -i 's/_.*$//g' "$TMP/pkg-names.lst"
	exit 0
fi

exit 1

# end Breeze::OS setup script
