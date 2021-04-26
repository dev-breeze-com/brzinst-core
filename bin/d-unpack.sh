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

display_metadata() {

	local name="$1"
	local version="$2"
	local title="$3"
	local MEMORY="`cat /proc/meminfo | grep -F 'MemFree' | sed -r 's/.*MemFree[: ]*//g'`"

	UNPACKED=$(( $UNPACKED + 1 ))

	dialog --colors \
		--backtitle "Breeze::OS $RELEASE Installer" \
		--title "Breeze::OS Setup -- Unpacking" \
		--infobox "\n\Z1Name\Zn    = $name\n\
\Z1title\Zn   = $title\n\
\Z1version\Zn = $version\n\
\Z1FreeMem\Zn = $MEMORY\n\
\Z1Date\Zn    = $(date)\n\n\
$UNPACKED PACKAGES OUT OF $NB_PACKAGES UNPACKED !" 12 75

	return 0
}

extract_archive() {

	local package="$1"
	local pkgtype="$2"
	local name="$3"
	local srcname="$4"

	if [ -f "$INSTALL_DIR/archive.txz" ]; then
		ARCHIVE="$INSTALL_DIR/archive.txz"
		#xz -d -c -f $ARCHIVE | tar -C $ROOTDIR -xUpf -
		tar -C $ROOTDIR -Jxf $ARCHIVE

	elif [ -f "$INSTALL_DIR/archive.tbz" ]; then
		ARCHIVE="$INSTALL_DIR/archive.tbz"
		tar -C $ROOTDIR -jxf $ARCHIVE

	elif [ -f "$INSTALL_DIR/archive.tgz" ]; then
		ARCHIVE="$INSTALL_DIR/archive.tgz"
		tar -C $ROOTDIR -zxf $ARCHIVE

	elif [ "$pkgtype" != "meta" -a "$pkgtype" != "download" ]; then
		echo $package >> $TMP/corrupted-packages.lst
		return 1
	fi

	if [ $? = 0 ]; then

		files="`ls $ROOTDIR/*.sh 2> /dev/null`"

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

		if [ "$name" = "etc" -o "$name" = "network-scripts" -o \
			"$name" = "openssl" -o "$name" = "openssl-solibs" ]; then

			SCRIPTS="$INSTALL_DIR/scripts/"
			ERRLOG="$ROOTDIR/tmp/$name.doinst.err"

			cd $ROOTDIR
			/bin/sh ./$SCRIPTS/doinst.sh -install 2> $ERRLOG

			if [ $? != 0 ]; then
				echo $pkg >> $TMP/pkg-failed.lst
			fi
			cd /

			if [ ! -e "$ERRLOG" ]; then echo "PWD $(cwd) ..."; fi
			if [ ! -s "$ERRLOG" ]; then unlink "$ERRLOG"; fi

		elif [ "$name" = "glibc" -o "$name" = "glibc-solibs" ]; then
			mv -f $ROOTDIR/lib/incoming $ROOTDIR/lib/$name-incoming 
			cp -f $BRZDIR/factory/slackware/scripts/$name \
				$INSTALL_DIR/scripts/doinst.sh
		fi
		return 0
	fi

	echo $package >> $TMP/corrupted-packages.lst

	return 1
}

unpack_distro() {

	local line=""
	local name=""
	local title=""
	local version=""
	local pkgtype=""
	local pkgname=""
	local src_path=""
	local package_list="$1"

	SKIPPED_LIST="`mktemp $TMP/XXXXXX`"
	touch $SKIPPED_LIST

	while read pkg; do

		cd /

		if echo "$pkg" | grep -qE '\.tkg$'` ; then
			continue
		fi

		line="`grep -F -m1 "$pkg" $ROOTDIR/tmp/titles.lst`"
		name="`echo "$line" | cut -f 1 -d '|'`"
		version="`echo "$line" | cut -f 2 -d '|'`"
		pkgtype="`echo "$line" | cut -f 3 -d '|'`"
		title="`echo "$line" | cut -f 4 -d '|'`"
		src_path="`echo "$line" | cut -f 5 -d '|'`"

		echo "INSTALLER: PROGRESS ((name,$name),(title,$title))"

#		if [ "$MODE" = "dialog" ]; then
#			display_metadata "$name" "$version" "$title"
#		fi

		INSTALL_DIR="$ROOTDIR/var/cache/packages/$name/"

		mkdir -p "$INSTALL_DIR/scripts/"

		package="$MOUNTPOINT/$src_path"

		if [ "$SOURCE_MEDIA" = "NET" ]; then
			archive="/breeze/$ARCH/stable/$src_path"
			package="$DOWNLOAD_DIR/`basename $src_path`"
			tftp -4 -m binary master.localdomain -c "get $archive $package"
		fi

		if [ $? != 0 ]; then
			echo $pkg >> $SKIPPED_LIST
			continue
		fi

		ERRLOG="$ROOTDIR/tmp/${name}.unzip"

		unzip -d $INSTALL_DIR -oqq $package 2> "$ERRLOG"

		if [ $? != 0 ]; then
			echo $pkg >> $SKIPPED_LIST
			continue
		fi

		extract_archive "$package" "$pkgtype" "$name" "$src_path"

		if [ $? != 0 ]; then
			echo $pkg >> $SKIPPED_LIST
		fi

		if [ ! -s "$ERRLOG" ]; then unlink "$ERRLOG"; fi

		if [ "$SOURCE_MEDIA" = "NET" -a "$KEEP_ARCHIVES" = false ]; then
			unlink "$package" 2> /dev/null
		fi
	done < "$package_list"

	return 0
}

# Main starts here ...
MODE="$1"
ARCHIVE=""
UNPACKED=0
KEEP_ARCHIVES=false

PACKAGE_LIST="$TMP/packages.lst"
INSTALL_DIR="$ROOTDIR/var/cache/packages/"
DOWNLOAD_DIR="$ROOTDIR/var/cache/packages/archives/"
NB_PACKAGES="`cat $TMP/pkg-total 2> /dev/null`"

ARCH="`cat $TMP/selected-arch 2> /dev/null`"
DERIVED="`cat $TMP/selected-derivative 2> /dev/null`"
PRESEED="`cat $TMP/preseed-enabled 2> /dev/null`"
CONNECTION="`cat $TMP/selected-connection 2> /dev/null`"
RELEASE="`cat $TMP/selected-release 2> /dev/null`"
SOURCE_MEDIA="`cat $TMP/selected-media 2> /dev/null`"

mkdir -p $ROOTDIR/tmp 2> /dev/null
mkdir -p $ROOTDIR/etc 2> /dev/null
mkdir -p $ROOTDIR/etc/reserved/ 2> /dev/null
mkdir -p $ROOTDIR/etc/brzpkg/
mkdir -p $INSTALL_DIR 2> /dev/null

#if [ "$MODE" = "dialog" ]; then
#
#	#dialog --colors \
#	#	--backtitle "Breeze::OS $RELEASE Installer" \
#	#	--title "Breeze::OS Setup -- Unpacking" --defaultno \
#	#	--yesno "\nKeep package archives on installation drive (y/n) ?\n" 7 65
#	#
#	#if [ $? != 0 ]; then
#	#	KEEP_ARCHIVES=false
#	#fi
#
#	dialog --colors \
#		--backtitle "Breeze::OS $RELEASE Installer" \
#		--title "Breeze::OS Setup -- Unpacking" \
#		--infobox "\nPlease wait, unpacking databases ...\n" 5 45
#fi

d-initdb.sh

unpack_distro "$PACKAGE_LIST"

if [ -s "$SKIPPED_LIST" ]; then

	LINES="`wc -l $SKIPPED_LIST | cut -f 1 -d' '`"

	if test "$LINES" -gt 4 ; then
		echo "INSTALLER: FAILURE L_UNPACKING_FAILURE"
		exit 1
	fi

	SKIPPED="`mktemp $TMP/XXXXXX`"
	mv -f "$SKIPPED_LIST" "$SKIPPED"
	unpack_distro "$SKIPPED"
fi

if [ $? = 0 ]; then

	cd /

	getfile local metadata/lsb-release $ROOTDIR/etc/lsb-release
	getfile local metadata/os-release $ROOTDIR/etc/os-release

	cp -f /etc/ld.so.conf $ROOTDIR/etc/
	cp $ROOTDIR/etc/os-release $ROOTDIR/etc/brzpkg/os-release

	exit 0
fi

exit 1

# end Breeze::OS setup script
