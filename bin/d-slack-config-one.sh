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

ARCH="$(cat $TMP/selected-arch 2> /dev/null)"
DB_UPDATES="$ROOTDIR/tmp/db-updates"

export TERM=linux-c
#export LANGUAGE=C.UTF-8
export LC_ALL=""
export LANG="C"
export LANGUAGE=""
export LC_TYPE="UTF-8"

config_pkg() {

	local errlog=""
	local name="$1"
	local version="$2"
	local pkgtype="$3"
	local pkg_src="$4"
	local src_path="$5"

	SCRIPTS="var/cache/packages/$name/scripts"

	if [ "$name" = "etc" -o \
		"$name" = "alsa-utils" -o \
		"$name" = "network-scripts" -o \
		"$name" = "sysvinit-functions" -o \
		"$name" = "openssl" -o "$name" = "openssl-solibs" ]; then
		echo "UPDATE packages SET status='installed' WHERE identifier = '$name';" >> "$DB_UPDATES"
		return 0
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
		return 1
	fi
	echo "UPDATE packages SET status='installed' WHERE identifier = '$name';" >> "$DB_UPDATES"
	return 0
}

config_pkg "$1" "$2" "$3" "$4" "$5"
exit $?

# end Breeze::OS setup script
