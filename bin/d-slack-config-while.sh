#!/bin/bash
#
# GNU GENERAL PUBLIC LICENSE -- Version 3
#
# Copyright 2013 Pierre Innocent, Tsert Inc. All rights reserved.
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

MODE="$1"
META_FILE=
CONFIGURED=0

ARCH="$(cat $TMP/selected-arch 2> /dev/null)"
DERIVED="$(cat $TMP/selected-derivative 2> /dev/null)"
RELEASE="$(cat $TMP/selected-release 2> /dev/null)"
INTERNET="$(cat $TMP/internet-enabled 2> /dev/null)"
NB_PKGS="$(cat $TMP/pkg-total 2> /dev/null)"

DB_UPDATES="$ROOTDIR/tmp/db-updates"
echo "BEGIN TRANSACTION;" 1> "$DB_UPDATES"

export TERM=linux-c
#export LANGUAGE=C.UTF-8
export LC_ALL=""
export LANG="C"
export LANGUAGE=""
export LC_TYPE="UTF-8"

#export TERM=linux-c
#export LANGUAGE=C.UTF-8
#export LANG=en_US
#export LC_ALL=en_US
#export LC_TYPE=en_US

config_distro() {

	local idx=1
    local pkglist="$1"
    local pkgtotal=$2

	local line=""
	local name=""
	local title=""
	local version=""
	local pkgtype=""
	local pkg_src=""
	local src_path=""
	local errlog=""

	unlink $TMP/config.err 2> /dev/null
	touch $TMP/config.err

	while read pkg; do

		line="$(grep -F -m1 "$pkg" $ROOTDIR/tmp/titles.lst)"
		if [ "$line" = "" ]; then continue; fi

		name="$(echo "$line" | cut -f 1 -d '|')"
		version="$(echo "$line" | cut -f 2 -d '|')"
		pkgtype="$(echo "$line" | cut -f 3 -d '|')"
		title="$(echo "$line" | cut -f 4 -d '|')"
		pkg_src="$(echo "$line" | cut -f 5 -d '|')"
		src_path="$(echo "$line" | cut -f 6 -d '|')"

		echo "INSTALLER: PROGRESS ((name,$name),(title,$title))"

		SCRIPTS="var/cache/packages/$name/scripts"

		if [ "$name" = "etc" -o \
			"$name" = "alsa-utils" -o \
			"$name" = "network-scripts" -o \
			"$name" = "sysvinit-functions" -o \
			"$name" = "openssl" -o "$name" = "openssl-solibs" ]; then
			echo "UPDATE packages SET status='installed' WHERE identifier = '$name';" >> "$DB_UPDATES"
			continue
		fi

		echo "UPDATE packages SET status='unpacked' WHERE identifier = '$name';" >> "$DB_UPDATES"

		if [ -f "$ROOTDIR/$SCRIPTS/doinst.sh" ]; then

			errlog="$ROOTDIR/tmp/$name.doinst.err"
			cd "$ROOTDIR"
			/bin/sh $SCRIPTS/doinst.sh -install $ROOTDIR 2> $errlog
			cd /

			if [ ! -s "$errlog" ]; then unlink "$errlog"; fi
		fi

		if [ -f "$ROOTDIR/$SCRIPTS/setup.sh" ]; then
			errlog="$ROOTDIR/tmp/$name.setup.err"
			cd "$ROOTDIR"
			/bin/sh $SCRIPTS/setup.sh -install $ROOTDIR 2> $errlog
			cd /
			if [ ! -s "$errlog" ]; then unlink "$errlog"; fi
		fi

		if [ -f "$ROOTDIR/$SCRIPTS/postinst.sh" ]; then
			errlog="$ROOTDIR/tmp/$name.postinst.err"
			cd "$ROOTDIR"
			/bin/sh $SCRIPTS/postinst.sh -install $ROOTDIR 2> $errlog
			cd /
			if [ ! -s "$errlog" ]; then unlink "$errlog"; fi
		fi

		if [ "$?" != 0 ]; then
			echo $pkg >> $TMP/config.err
			continue
		fi

		echo "UPDATE packages SET status='installed' WHERE identifier = '$name';" >> "$DB_UPDATES"

	done < "$pkglist"

	echo "END TRANSACTION;" >> "$DB_UPDATES"

	if [ ! -s "$TMP/config.err" ]; then
		return 0
	fi
	return 1
}

# Main starts here ...
echo "INSTALLER: MESSAGE L_INIT_LIBRARIES"
chroot $ROOTDIR /sbin/ldconfig

echo "INSTALLER: MESSAGE L_CONFIGURING_PACKAGES"
PACKAGE_LIST="$ROOTDIR/tmp/packages.lst"
PKG_TOTAL=$(wc -l $PACKAGE_LIST | cut -f 1 -d' ')
config_distro "$PACKAGE_LIST" $PKG_TOTAL

if [ "$?" = 0 ]; then
	echo "INSTALLER: MESSAGE L_CONFIGURING_XORG"
	cd /; /install/bin/d-set-xorg.sh xorg
fi

if [ "$?" = 0 ]; then
	echo "INSTALLER: SUCCESS"
	exit 0
fi          

echo "INSTALLER: FAILURE"
exit 1

# end Breeze::OS setup script
