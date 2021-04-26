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

retr_distro() {

	local pkglist="$1"
	local line=""
	local name=""
	local title=""
	local retcode=0

	cd /

	unlink $TMP/retr-failures.lst 2> /dev/null
	touch $TMP/retr-failures.lst 2> /dev/null

	if [ "$SOURCE_MEDIA" = "CDROM" ]; then

		sort $pkglist 1> ${pkglist}.collated

		while read pkg; do

			line="$(grep -F -m1 "$pkg" $ROOTDIR/tmp/titles.lst)"

			if [ "$line" = "" ]; then continue; fi

			line="$(echo "$line" | cut -f 2 -d '=')"
			name="$(echo "$line" | cut -f 1 -d '|')"
			title="$(echo "$line" | cut -f 4 -d '|')"

			echo "INSTALLER: PROGRESS ((name,$name),(title,$title))"

			cp -a $MOUNTPOINT/$pkg $DOWNLOAD_DIR/

			if [ "$?" != 0 ]; then
				cp -a $MOUNTPOINT/$pkg $DOWNLOAD_DIR/
			fi

			if [ "$?" != 0 ]; then
				echo >> $TMP/retr-failures.lst 
				retcode=1
			fi
		done < ${pkglist}.collated
	fi

	return $retcode
}

# Main starts here ...
PACKAGE_LIST="$ROOTDIR/tmp/packages.lst"
INSTALL_DIR="$ROOTDIR/var/cache/packages/"
DOWNLOAD_DIR="$ROOTDIR/var/cache/brzpkg/archives/"

SOURCE_MEDIA="$(cat $TMP/selected-media 2> /dev/null)"
SOURCE_MEDIA="$(echo "$SOURCE_MEDIA" | tr '[:lower:]' '[:upper:]')"

DEVICE="$(cat $TMP/selected-target 2> /dev/null)"
DISK_SIZE="$(sfdisk -s $DEVICE 2> /dev/null)"
DISK_SIZE=$(( $DISK_SIZE * 1024 / 1000000 ))

if ! test "$DISK_SIZE" -gt 10000; then
	echo "INSTALLER: FAILURE L_NOT_ENOUGH_DISK_SPACE"
	exit 1
fi

mkdir -p $ROOTDIR/tmp
mkdir -p $ROOTDIR/etc/reserved
mkdir -p $ROOTDIR/etc/brzpkg
mkdir -p $INSTALL_DIR
mkdir -p $DOWNLOAD_DIR

echo "INSTALLER: MESSAGE L_RETRIEVING_PACKAGES"
retr_distro "$PACKAGE_LIST"

if [ "$?" != 0 ]; then
	echo "INSTALLER: FAILURE L_RETR_FAILURE"
	exit 1
fi

exit 0
# end Breeze::OS setup script
