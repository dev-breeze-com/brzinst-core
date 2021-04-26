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

. d-unpack-distro.sh

extract_archive() {

	local package="$1"
	local pkgtype="$2"
	local name="$3"
	local srcname="$4"
	local errlog="$ROOTDIR/tmp/$name.tar"

	untar_archive "$1" "$2" "$errlog"

	if [ "$?" != 0 ]; then
		if ! check_errlog "$errlog" "$pkg" ; then
			return 1
		fi
	fi

	if [ "$?" != 0 ]; then
		echo "Corrupted $package" >> $TMP/pkg-unpack.errs
		return 1
	fi

	unlink "$errlog" 2> /dev/null

	files="$(ls $ROOTDIR/*.sh 2> /dev/null)"

	if [ "$files" != "" ]; then
		for f in $files; do
			/bin/cp -f "$f" $INSTALL_DIR/scripts/
			unlink "$f" 2> /dev/null
		done
	fi

	if [ "$KEEP_ARCHIVES" = false ]; then
		if [ "$pkgtype" != "meta" -a "$pkgtype" != "download" ]; then
			unlink $ARCHIVE 2> /dev/null
		fi
	fi

	if grep -q -F -m1 "_${name}_" $BRZDIR/factory/cfgnow.lst ; then

		SCRIPTS="$INSTALL_DIR/scripts/"
		errlog="$ROOTDIR/tmp/$name.doinst.err"

		cd $ROOTDIR
		ROOT=$ROOTDIR /bin/sh $SCRIPTS/doinst.sh 2> $errlog

		if [ "$?" != 0 ]; then
			echo $pkg >> $TMP/pkg-config.errs
		fi
		cd /
		if [ ! -s "$errlog" ]; then unlink "$errlog"; fi
	fi
	return 0
}

# Main starts here ...
ARCHIVE=""
UNPACKED=0
UNPACK_MODE="$1"

KEEP_ARCHIVES=false
#KEEP_ARCHIVES="$(cat $TMP/keep-archives 2> /dev/null)"

PKGLIST="$TMP/packages.lst"
INSTALL_DIR="$ROOTDIR/var/cache/packages/"
DOWNLOAD_DIR="$ROOTDIR/var/cache/brzpkg/archives/"

DERIVED="$(cat $TMP/selected-derivative 2> /dev/null)"
DESKTOP="$(cat $TMP/selected-desktop 2> /dev/null)"
CONNECTION="$(cat $TMP/selected-connection 2> /dev/null)"

PKGMEDIA="$(cat $TMP/selected-media 2> /dev/null)"
PKGMEDIA="$(echo "$PKGMEDIA" | tr '[:upper:]' '[:lower:]')"
PKGHOST="$(cat $TMP/selected-network-source 2> /dev/null)"

mkdir -p $ROOTDIR/tmp 2> /dev/null
mkdir -p $ROOTDIR/etc/reserved/ 2> /dev/null
mkdir -p $ROOTDIR/etc/brzpkg/
mkdir -p $INSTALL_DIR 2> /dev/null
mkdir -p $DOWNLOAD_DIR 2> /dev/null

echo "INSTALLER: MESSAGE L_UNPACKING_PACKAGES"
#PKG_TOTAL=$(wc -l $PKGLIST | cut -f 1 -d' ')
unpack_distro "$PKGLIST" #$PKG_TOTAL

if [ -s "$SKIPPED_LIST" -a "$PKGMEDIA" != "network" ]; then

	LINES=$(wc -l $SKIPPED_LIST | cut -f 1 -d' ')

	if test "$LINES" -gt 4 ; then
		echo "INSTALLER: FAILURE L_UNPACKING_TOO_MANY_FAILURE"
		exit 1
	fi

	SKIPPED="$(mktemp $TMP/XXXXXX)"
	mv -f "$SKIPPED_LIST" "$SKIPPED"
	unpack_distro "$SKIPPED" $LINES
fi

if [ "$?" = 0 ]; then
	PKGLIST="$BRZDIR/factory/slackware/download-${DESKTOP}.lst"

	if [ -s "$PKGLIST" ]; then
		PKGMEDIA="network"

		if [ "$CONNECTION" != "router" ]; then
			echo "INSTALLER: MESSAGE L_SKIPPING_DOWNLOAD_PACKAGES"
			exit 0
		fi
		unpack_distro "$PKGLIST" #$PKG_TOTAL
	fi
fi

if [ "$?" = 0 ]; then
	echo "INSTALLER: SUCCESS"
	exit 0
fi

echo "INSTALLER: FAILURE"
exit 1

# end Breeze::OS setup script
