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
check_errlog() {

	local errlog="$1"
	local package="$2"

	if grep -qF -v 'short read' "$errlog" ; then
		echo "Corrupted $package -- unzip short read" >> $TMP/pkg-unpack.errs
#	else
#		unlink "$errlog" 2> /dev/null
	fi
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

		if echo "$package" | grep -E -q '[.]txz$' ; then
			ARCHIVE="$package"
			unxz -c $ARCHIVE | tar -C $ROOTDIR -xf - 2> $errlog

		elif echo "$package" | grep -E -q '[.]tgz$' ; then
			ARCHIVE="$package"
			tar -C $ROOTDIR -zxf $ARCHIVE 2> $errlog

		elif echo "$package" | grep -E -q '[.]tbz$' ; then
			ARCHIVE="$package"
			tar -C $ROOTDIR -jxf $ARCHIVE 2> $errlog

		elif [ "$DERIVED" != "slackware" ]; then
			echo "Corrupted $package -- unknown format" >> $TMP/pkg-unpack.errs
			return 1
		fi
	fi

	local retcode=$?

	if [ ! -s "$errlog" ]; then unlink "$errlog"; fi

	return $retcode
}

unpack_distro() {

	local pkglist="$1"
	local line=""
	local name=""
	local title=""
	local errlog=""
	local device=""
	local version=""
	local pkgtype=""
	local pkgname=""
	local pkg_src=""
	local src_path=""

	SKIPPED_LIST="$(mktemp $TMP/XXXXXX)"
	touch $SKIPPED_LIST

	while read pkg; do

		cd /

		line="$(grep -F -m1 "$pkg" $ROOTDIR/tmp/titles.lst)"

		if [ -z "$line" ]; then continue; fi

		line="$(echo "$line" | cut -f 2 -d '=')"
		name="$(echo "$line" | cut -f 1 -d '|')"
		version="$(echo "$line" | cut -f 2 -d '|')"
		revision="$(echo "$line" | cut -f 3 -d '|')"
		pkgtype="$(echo "$line" | cut -f 4 -d '|')"
		title="$(echo "$line" | cut -f 5 -d '|')"
		pkg_src="$(echo "$line" | cut -f 6 -d '|')"
		src_path="$pkg" #"$(echo "$line" | cut -f 7 -d '|')"

		echo "INSTALLER: PROGRESS ((name,$name),(title,$title))"
		INSTALL_DIR="$ROOTDIR/var/cache/packages/$name"

		mkdir -p "$INSTALL_DIR/scripts/"
		package="$MOUNTPOINT/$src_path"

		if [ "$PKGMEDIA" = "network" ]; then

			SHA1SUM="$(echo "$line" | cut -f9 -d '|')"

			package="$DOWNLOAD_DIR/$(basename $src_path)"
			getfile $PKGHOST $src_path $package

			if [ "$?" != 0 ]; then
				echo "$pkg" >> $SKIPPED_LIST
				continue
			fi
		fi

		if [ ! -e $package ]; then

			if [ "$PKGMEDIA" = "network" ]; then
				echo "$pkg" >> $SKIPPED_LIST
				continue
			fi

			# For glitchy USB devices ...
			#
			if lsblk -lpdno 'mountpoint' | fgrep -q "${MOUNTPOINT}" ; then
				echo "$pkg" >> $SKIPPED_LIST
				continue
			fi

			umount $MOUNPOINT
			sleep 1
			sync

			device="$(lsblk -lpdno 'kname,label' | fgrep -m1 'INSTALL_MEDIA')"
			device="$(echo "$device" | cut -f1 -d' ')"

			mount $device $MOUNPOINT &> /dev/null

			if [ "$?" != 0 ]; then
				echo "$pkg" >> $SKIPPED_LIST
				continue
			fi
			sleep 1
			sync
		fi

		errlog="$ROOTDIR/tmp/${name}.unzip"

		unzip -d $INSTALL_DIR -oqq $package 2> "$errlog"

		if [ "$?" = 0 ]; then
			if [ ! -s "$errlog" ]; then
				unlink "$errlog"
			fi
		else
			check_errlog "$errlog" "$pkg"
		fi

		extract_archive "$package" "$pkgtype" "$name" "$src_path" "$version" "$revision"

		if [ "$?" = 0 ]; then
			echo -e "REPLACE INTO activity ( identifier, version, revision, \"build-nb\", status, rootdir ) VALUES ( '$name', '$version', '$revision', '$buildnb', 'installed', '$rootdir' );\n" >> $TMP/db-activity
		else
			echo "$pkg" >> $SKIPPED_LIST
		fi

		if [ "$KEEP_ARCHIVES" = false -a "$PKGMEDIA" = "network" ]; then
			unlink "$package" 2> /dev/null
		fi
	done < $pkglist

	return 0
}

exec_script() {

	local name="$1"
	local script="$2"
	local errlog="$ROOTDIR/tmp/${name}.${script}.err"

	if grep -qF -m1 "_${name}_" $BRZDIR/factory/chroot.lst ; then
		SCRIPTS="/var/cache/packages/$name/scripts"
		touch $ROOTDIR/var/tmp/chrooted
		chroot $ROOTDIR /bin/bash $SCRIPTS/${script}.sh
		retcode="$?"
		unlink $ROOTDIR/var/tmp/chrooted
		return $retcode
	fi

	cd "$ROOTDIR"

	ROOT=$ROOTDIR /bin/sh $SCRIPTS/${script}.sh 2> $errlog

	if [ "$?" != 0 -a -s "$errlog" ]; then
		cd /
		return 1
	fi

	if [ ! -s "$errlog" ]; then unlink "$errlog"; fi

	cd /
	return 0
}

config_pkg() {

	local name="$1"
	local version="$2"

	SCRIPTS="$INSTALL_DIR/scripts"

	if [ -f "$SCRIPTS/doinst.sh" ]; then
		if ! exec_script $name doinst ; then
			return 1
		fi
	fi

	if [ -f "$SCRIPTS/setup.sh" ]; then
		if ! exec_script $name setup ; then
			return 1
		fi
	fi

	if [ -f "$SCRIPTS/postinst.sh" ]; then
		if ! exec_script $name postinst ; then
			return 1
		fi
	fi

	echo "UPDATE packages SET status='installed' WHERE identifier = '$name' AND version = '$version';" >> "$DB_UPDATES"
	return 0
}

# end Breeze::OS setup script
