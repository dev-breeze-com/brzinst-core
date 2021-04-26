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
#. d-selected-options.sh

finalize_list() {

    local pkgtype="$1"

    wc -l $TMP/packages.lst | cut -f1 -d' ' 1> $TMP/pkg-total

    sed -r -e 's/^.*\///g' "$TMP/packages.lst" 1> $TMP/pkg-names.lst

    if [ "$pkgtype" = "squashfs" ]; then
        sed -r -i 's/[0-9]+[-]breezeos[-]//g' $TMP/pkg-names.lst
        sed -r -i 's/[-][0-9][.][0-9].*$//g' $TMP/pkg-names.lst
    else
        sed -r -i 's/_.*$//g' $TMP/pkg-names.lst
    fi

    return 0
}

get_root_fs() {

    local device="$(mount | grep -F " on $ROOTDIR/boot " | cut -f1 -d ' ')"

    if [ -z "$device" ]; then
        device="$(mount | grep -F " on $ROOTDIR " | cut -f1 -d ' ')"
    fi

    local rootfs="$(lsblk -n -l -o 'fstype' $device)"
    echo -n "$rootfs"

    return 0
}

update_list() {

    local excludes="desktop[-]printing"
    local excl_loaders="lilo"

    local mta="$(extract_value services mta)"
    local mda="$(extract_value services mda)"
    local nis="$(extract_value services nis)"

    grep -E -v "$excl_loaders" $TMP/packages.lst 1> $TMP/pkglist

    if [ "$INTERNET" = "none" ]; then
        excludes="$excludes|wvdial|libwvstreams|postfix|dovecot|ssmtp|sendmail"
    elif [ "$INTERNET" != "dialup" ]; then
        excludes="$excludes|wvdial|libwvstreams"
    fi

    excludes="$excludes|flash[-]player[-]plugin|webcore"

    if [ "$nis" != "nis" -o "$niS" = "disabled" ]; then
        excludes="$excludes|yptools"
    fi

    if [ "$mda" != "dovecot" -o "$mda" = "disabled" ]; then
        excludes="$excludes|dovecot"
    fi

    if [ "$mda" != "maildrop" -o "$mda" = "disabled" ]; then
        excludes="$excludes|maildrop"
    fi

    if [ "$mta" != "postfix" -o "$mta" = "disabled" ]; then
        excludes="$excludes|postfix"
    fi

    if ! grep -q -F -m1 nvidia $DRIVERS ; then
        excludes="$excludes|nvidia"
    fi

    excludes="$excludes|kernel[-](modules|huge|generic)"

    grep -E -v "$excludes" $TMP/pkglist 1> $TMP/packages.lst
    return 0
}

check_squashfs_archives() {

    local footprint=0
    local desktop="$1"
    local pattern="(lxde|mate|kde"
    local pkglist="$TMP/squashfs-$desktop.lst"

    if [ -z "$MOUNTPOINT" -o ! -d "$MOUNTPOINT" ]; then
        echo_failure "L_PACKAGE_LIST_MISSING"
        return 1
    fi

    if [ "$desktop" = "lxde" ]; then
        pattern="(xfce|mate|kde"
    elif [ "$desktop" = "kde" ]; then
        pattern="(xfce|mate|lxde"
    elif [ "$desktop" = "mate" ]; then
        pattern="(xfce|kde|lxde"
    fi

    if echo "$desktop" | grep -qE "^core" ; then
        pattern="$pattern|libreoffice|openoffice)[.]org"
    else
        pattern="${pattern})[.]org"
    fi

    find $MOUNTPOINT -name '*.sxz' | \
        grep -vE "$pattern" | sort -k5 -t/ > $pkglist 

    if [ ! -f "$pkglist" -o ! -s "$pkglist" ]; then
        echo_failure "L_PACKAGE_LIST_MISSING"
        return 1
    fi

    cat /dev/null 1> $TMP/packages.lst

    while read pkg ; do
        pkgsz="$(ls -s ${pkg} | crunch | cut -f1 -d' ')"
        footprint=$(( $footprint + $pkgsz ))
    done < ${pkglist}

    footprint=$(( $footprint / 1000 ))
    footprint=$(( $footprint * 150 / 100 ))
    echo "$footprint" 1> $TMP/pkg-footprint

    cp -f ${pkglist} $TMP/packages.lst
    return 0
}

check_nb_pkgs() {

    local nb_pkgs=""
    local desktop="$1"
    local disk_sz="undefined"
    local pkglist="$BRZDIR/desktop/$desktop.lst"
    local media="$(cat $TMP/selected-source-media 2> /dev/null)"

    if [ "$media" = "NETWORK" ]; then
        pkglist="$ROOTDIR/etc/brzpkg/desktops/${DESKTOP}.lst"
    fi

    if [ ! -f "$pkglist" -o ! -s "$pkglist" ]; then
        echo_failure "L_PACKAGE_LIST_MISSING"
        return 1
    fi

    grep -F -v "Stats: " $pkglist 1> $TMP/packages.lst

    local stats="$(grep -F 'Stats: ' $pkglist | sed -e 's/Stats: //g')"

    if [ -n "$stats" ]; then
        disk_sz="$(echo "$stats" | cut -f 3 -d /)"
    fi

    ROOT_FS="$(get_root_fs)"

    update_list

    echo "$disk_sz" 1> $TMP/pkg-footprint
    return 0
}

DEVICE="$1"

if ! is_valid_device "$DEVICE" ; then
    echo_failure "L_NO_DEVICE_SPECIFIED"
    exit 1
fi

if ! is_safemode_drive "$DEVICE" ; then
    echo_failure "L_INVALID_DEVICE_SPECIFIED"
    exit 1
fi

DESKTOP="$(cat $TMP/selected-desktop 2> /dev/null)"
GPT_MODE="$(cat $TMP/selected-gpt-mode 2> /dev/null)"
DISKTYPE="$(cat $TMP/selected-disktype 2> /dev/null)"
RELEASE="$(cat $TMP/selected-release 2> /dev/null)"
DERIVED="$(cat $TMP/selected-derivative 2> /dev/null)"
PKGTYPE="$(cat $TMP/selected-pkgtype 2> /dev/null)"
INTERNET="$(cat $TMP/selected-connection 2> /dev/null)"

if d-bootloaders.sh $DEVICE ; then

	DRIVERS="$TMP/xorg-drivers"
	AMD64="$(uname -p | grep -E -i 'amd.*64')"

	BOOTMGR="$(cat $TMP/selected-bootloader 2> /dev/null)"
	BOOTMGR="$(echo "$BOOTMGR" | tr '[:upper:]' '[:lower:]')"

	if [ "$PKGTYPE" = "squashfs" ]; then
		if check_squashfs_archives "$DESKTOP" ; then
			finalize_list "$PKGTYPE"
			exec d-initdb.sh
		fi
	else
		if check_nb_pkgs "$DESKTOP" ; then
			finalize_list "$PKGTYPE"
			exec d-initdb.sh
		fi
	fi
fi

exit 1

# end Breeze::OS setup script
