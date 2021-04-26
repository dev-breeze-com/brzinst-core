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

check_errlog() {

	local errlog="$1"
	local package="$2"

	if grep -F -q -v 'short read' "$errlog" ; then
		echo "Corrupted $package" >> $TMP/pkg-failed.lst
		return 1
	fi
	unlink "$errlog"
	return 0
}

untar_archive() {

	local package="$1"
	local pkgtype="$2"
	local errlog="$3"

	if [ -f "$INSTALL_DIR/archive.txz" ]; then
		ARCHIVE="$INSTALL_DIR/archive.txz"
		unxz -c $ARCHIVE | tar -C $ROOTDIR -xf - 2> $errlog
		#tar -C $ROOTDIR -Jxf $ARCHIVE 2> $errlog

	elif [ -f "$INSTALL_DIR/archive.tgz" ]; then
		ARCHIVE="$INSTALL_DIR/archive.tgz"
		tar -C $ROOTDIR -zxf $ARCHIVE 2> $errlog
		#gunzip $ARCHIVE | tar -C $ROOTDIR -xf - 2> $errlog

	elif [ -f "$INSTALL_DIR/archive.tbz" ]; then
		ARCHIVE="$INSTALL_DIR/archive.tbz"
		tar -C $ROOTDIR -jxf $ARCHIVE 2> $errlog
		#bunzip2 $ARCHIVE | tar -C $ROOTDIR -xf - 2> $errlog

	elif [ "$pkgtype" != "meta" -a "$pkgtype" != "download" ]; then
		return 0

		if echo "$package" | grep -E -q '[.]txz$' ; then
			ARCHIVE="$package"
			unxz -c $ARCHIVE | tar -C $ROOTDIR -xf - 2> $errlog

		elif echo "$package" | grep -E -q '[.]tgz$' ; then
			ARCHIVE="$package"
			tar -C $ROOTDIR -zxf $ARCHIVE 2> $errlog

		elif echo "$package" | grep -E -q '[.]tbz$' ; then
			ARCHIVE="$package"
			tar -C $ROOTDIR -jxf $ARCHIVE 2> $errlog
		else
			echo "Corrupted $package" >> $TMP/pkg-failed.lst
			return 1
		fi
	fi
	return $?
}

extract_archive() {

	local package="$1"
	local pkgtype="$2"
	local name="$3"
	local srcname="$4"
	local errlog="$ROOTDIR/tmp/$name.tar"

	untar_archive "$1" "$2" "$errlog"

	if [ "$?" != 0 ]; then
		if ! check_errlog "$errlog" "$package" ; then
			return 1
		fi
	fi

	if [ "$?" = 0 ]; then

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

		if grep -q -F -m1 "_${name}_" $TMP/cfgnow.lst ; then

			SCRIPTS="$INSTALL_DIR/scripts/"
			errlog="$ROOTDIR/tmp/$name.doinst.err"

			cd $ROOTDIR
			/bin/sh $SCRIPTS/doinst.sh -install 2> $errlog

			if [ "$?" != 0 ]; then
				echo $pkg >> $TMP/pkg-failed.lst
			fi

			cd /
			if [ ! -s "$errlog" ]; then unlink "$errlog"; fi

		elif [ "$name" = "glibc" -o "$name" = "glibc-solibs" ]; then
			mv -f $ROOTDIR/lib/incoming $ROOTDIR/lib/$name-incoming 
			cp -f $BRZDIR/factory/slackware/scripts/$name \
				$INSTALL_DIR/scripts/doinst.sh
		fi
		return 0
	fi
	echo "Corrupted $package" >> $TMP/pkg-failed.lst
	return 1
}

unpack_pkg() {

	local errlog=""
	local name="$1"
	local version="$2"
	local pkgtype="$3"
	local pkg_src="$4"
	local src_path="$5"
	local url="http://breeze.tsert.com/archives/slackware/$ARCH/stable"

	INSTALL_DIR="$ROOTDIR/var/cache/packages/$name/"

	mkdir -p "$INSTALL_DIR/scripts/"
	package="$MOUNTPOINT/$src_path"

	if [ -f "$INSTALL_DIR/meta.xml" ]; then # Package already unpacked ...
		return 0
	fi

	if [ "$SOURCE_MEDIA" = "NETWORK" ]; then

		package="$DOWNLOAD_DIR/$(basename $src_path)"
		ftpget master.localdomain $package /archives/$src_path

		if [ "$?" != 0 ]; then
			echo $pkg >> $SKIPPED_LIST
			return 1
		fi
	elif [ "$SOURCE_MEDIA" = "WEB" ]; then

		package="$DOWNLOAD_DIR/$(basename $src_path)"
		wget -q -O $package "$url/$src_path"

		if [ "$?" != 0 ]; then
			echo $pkg >> $SKIPPED_LIST
			return 1
		fi
	fi

	errlog="$ROOTDIR/tmp/${name}.unzip"
	/bin/unzip -d $INSTALL_DIR -oqq $package 2> "$errlog"

	if [ "$?" != 0 ]; then
		if ! check_errlog "$errlog" "$package" ; then
			echo $pkg >> $SKIPPED_LIST
			return 1
		fi
	fi

	unlink "$errlog" 2> /dev/null

	extract_archive "$package" "$pkgtype" "$name" "$src_path"

	if [ "$?" != 0 ]; then
		echo $pkg >> $SKIPPED_LIST
		return 1
	fi

	if [ "$KEEP_ARCHIVES" = false ]; then
		if [ "$SOURCE_MEDIA" = "NETWORK" -o "$SOURCE_MEDIA" = "WEB" ]; then
			unlink "$package" 2> /dev/null
		fi
	fi
	return 0
}

# Main starts here ...
KEEP_ARCHIVES=false
INSTALL_DIR="$ROOTDIR/var/cache/packages/"
DOWNLOAD_DIR="$ROOTDIR/var/cache/packages/archives/"

ARCH="$(cat $TMP/selected-arch 2> /dev/null)"
SOURCE_MEDIA="$(cat $TMP/selected-media 2> /dev/null)"
#KEEP_ARCHIVES="$(cat $TMP/keep-archives 2> /dev/null)"

unpack_pkg "$1" "$2" "$3" "$4" "$5"
exit $?

# end Breeze::OS setup script
