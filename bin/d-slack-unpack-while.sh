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

untar_archive() {

	local package="$1"
	local pkgtype="$2"
	local tries="$3"
	local errlog="$4"

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

	untar_archive "$1" "$2" "1" "$errlog"

#	if [ "$?" != 0 ]; then
#		untar_archive "$1" "$2" "2" "$errlog"
#	fi

	if [ "$?" != 0 ]; then
		if grep -F -q -v 'short read' ; then
			echo "Corrupted $package" >> $TMP/pkg-failed.lst
			return 1
		fi
		unlink "$errlog"
	fi

	if [ "$?" = 0 ]; then

		if [ -e "$errlog" ]; then
			if [ ! -s "$errlog" ]; then
				unlink "$errlog"
			elif ! grep -F -q -v 'short read' ; then
				unlink "$errlog"
			fi
		fi

		files="$(ls $ROOTDIR/install/*.sh 2> /dev/null)"

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

		#if grep -q -F -m1 "_${name}_" $TMP/cfgnow.lst ; then
		if [ "$name" = "etc" -o \
			"$name" = "alsa-utils" -o \
			"$name" = "network-scripts" -o \
			"$name" = "sysvinit-functions" -o \
			"$name" = "openssl" -o "$name" = "openssl-solibs" ]; then

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
			cp -f /install/factory/slackware/scripts/$name \
				$INSTALL_DIR/scripts/doinst.sh
		fi
		return 0
	fi
	echo "Corrupted $package" >> $TMP/pkg-failed.lst
	return 1
}

unpack_distro() {

	local idx=1
	local pkglist="$1"
	local pkgtotal=$2

	local url=""
	local line=""
	local name=""
	local title=""
	local errlog=""
	local version=""
	local pkgtype=""
	local pkgname=""
	local pkg_src=""
	local src_path=""
	local url="http://breeze.tsert.com/archives/slackware/i486/stable"

	SKIPPED_LIST="$(mktemp $TMP/XXXXXX)"
	touch $SKIPPED_LIST 2> /dev/null

	unlink $ROOTDIR/tmp/processed.lst 2> /dev/null
	touch $ROOTDIR/tmp/processed.lst 2> /dev/null

#	while test $idx -le $pkgtotal; do
#		cd /
#		pkg="$(head -n $idx $pkglist | tail -n1)"
#		idx=$(( $idx + 1 ))

	while read pkg; do

		cd /
		idx=$(( $idx + 1 ))

		line="$(grep -F -m1 "$pkg" $ROOTDIR/tmp/titles.lst)"
		if [ "$line" = "" ]; then continue; fi

		name="$(echo "$line" | cut -f 1 -d '|')"
		version="$(echo "$line" | cut -f 2 -d '|')"
		pkgtype="$(echo "$line" | cut -f 3 -d '|')"
		title="$(echo "$line" | cut -f 4 -d '|')"
		pkg_src="$(echo "$line" | cut -f 5 -d '|')"
		src_path="$(echo "$line" | cut -f 6 -d '|')"

		echo "INSTALLER: PROGRESS ((name,$name),(title,$title))"
		echo "INSTALLER: PROGRESS ((($idx),(pkg,$pkg),(name,$name),(title,$title))" >> $ROOTDIR/tmp/processed.lst
		INSTALL_DIR="$ROOTDIR/var/cache/packages/$name/"

		mkdir -p "$INSTALL_DIR/scripts/"
		package="$MOUNTPOINT/$src_path"

		if [ -f "$INSTALL_DIR/meta.xml" ]; then # Package already unpacked ...
			continue
		fi

		if [ "$SOURCE_MEDIA" = "NETWORK" ]; then

			package="$DOWNLOAD_DIR/$(basename $src_path)"
			ftpget master.localdomain $package /archives/$src_path

			if [ "$?" != 0 ]; then
				echo $pkg >> $SKIPPED_LIST
				continue
			fi
		elif [ "$SOURCE_MEDIA" = "WEB" ]; then

			package="$DOWNLOAD_DIR/$(basename $src_path)"
			wget -q -O $package "$url/$src_path"

			if [ "$?" != 0 ]; then
				echo $pkg >> $SKIPPED_LIST
				continue
			fi
		fi

		errlog="$ROOTDIR/tmp/${name}.unzip"
		/bin/unzip -d $INSTALL_DIR -oqq $package 2> "$errlog"

		if [ "$?" != 0 ]; then
			echo $pkg >> $SKIPPED_LIST
			continue
		fi

		if [ ! -s "$errlog" ]; then unlink "$errlog"; fi

		extract_archive "$package" "$pkgtype" "$name" "$src_path"

		if [ "$?" != 0 ]; then
			echo $pkg >> $SKIPPED_LIST
		fi

		if [ "$KEEP_ARCHIVES" = false ]; then
			if [ "$SOURCE_MEDIA" = "NETWORK" -o "$SOURCE_MEDIA" = "WEB" ]; then
				unlink "$package" 2> /dev/null
			fi
		fi
	done < "$pkglist"

	return 0
}

# Main starts here ...
ARCHIVE=""
UNPACKED=0
UNPACK_MODE="$1"
KEEP_ARCHIVES=false

PACKAGE_LIST="$ROOTDIR/tmp/packages.lst"
INSTALL_DIR="$ROOTDIR/var/cache/packages/"
DOWNLOAD_DIR="$ROOTDIR/var/cache/packages/archives/"

ARCH="$(cat $TMP/selected-arch 2> /dev/null)"
DESKTOP="$(cat $TMP/selected-desktop 2> /dev/null)"
CONNECTION="$(cat $TMP/selected-connection 2> /dev/null)"
SOURCE_MEDIA="$(cat $TMP/selected-media 2> /dev/null)"
#KEEP_ARCHIVES="$(cat $TMP/keep-archives 2> /dev/null)"

mkdir -p $ROOTDIR/tmp 2> /dev/null
mkdir -p $ROOTDIR/etc/reserved/ 2> /dev/null
mkdir -p $ROOTDIR/etc/packager/
mkdir -p $INSTALL_DIR 2> /dev/null
mkdir -p $DOWNLOAD_DIR 2> /dev/null

if [ "$UNPACK_MODE" = "complete" ]; then

	SOURCE_MEDIA="WEB"
	PACKAGE_LIST="/install/factory/slackware/download-${DESKTOP}.lst"

	if [ "$CONNECTION" != "router" ]; then
		echo "INSTALLER: MESSAGE L_CANNOT_DOWNLOAD_PACKAGES"
		exit 0
	fi

	if [ ! -s "$PACKAGE_LIST" ]; then
		echo "INSTALLER: MESSAGE L_NO_DOWNLOAD_PACKAGES"
		exit 0
	fi
fi

echo "INSTALLER: MESSAGE L_UNPACKING_PACKAGES"
PKG_TOTAL=$(wc -l $PACKAGE_LIST | cut -f 1 -d' ')
unpack_distro "$PACKAGE_LIST" $PKG_TOTAL

if [ -s "$SKIPPED_LIST" -a "$SOURCE_MEDIA" != "WEB" ]; then

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

	cd /
	cp -f /etc/ld.so.conf $ROOTDIR/etc/

	d-retr-file.sh /lsb-release $ROOTDIR/etc/lsb-release
	d-retr-file.sh /os-release $ROOTDIR/etc/os-release
	cp $ROOTDIR/etc/os-release $ROOTDIR/etc/packager/os-release

	echo "INSTALLER: SUCCESS"
	exit 0
fi

echo "INSTALLER: FAILURE"
exit 1

# end Breeze::OS setup script
