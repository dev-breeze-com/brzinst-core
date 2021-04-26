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
#
. d-dirpaths.sh

. d-unpack-distro.sh

#export LANGUAGE=C.UTF-8
export TERM=linux-c
export LANG="C"
export LANGUAGE=""
export LC_ALL=""
export LC_TYPE="UTF-8"

unpack_squashfs() {

	local rc=0
	local rootdir="$1"
	local pkglist="$2"
	local memsize="$(probe_memory $PLATFORM)"
	local logfile="$rootdir/tmp/squashfs.log"

	#echo "10000" > /proc/sys/fs/file-max
	ulimit -n 128000

	mkdir -p $rootdir/tmp
	chmod 1777 $rootdir/tmp

	while read path ; do

		local title="$(basename ${path} '.sxz')"
		local pkg="$(echo ${title} | sed -r 's/^[0-9]*[-]breezeos[-]//g')"

		if [ -e "$path" ]; then

			pkg="$(echo ${pkg} | sed -r 's/[-][0-9].*$//g')"

			if [ -z "$title" ]; then
				title="$(basename ${path} '.sxz')"
			fi

			echo "INSTALLER: PROGRESS ((name,$pkg),(title,$title))"
			sync; usleep 100000

			echo "INSTALLER: MESGICON $pkg"
			sync

			local memfree="$(probe_memory $PLATFORM free)"

			if test $memsize -lt 768 || test $memfree -lt 128; then
				if echo "$path" | grep -qE 'breezeos[-](core|kde.org)[-]' ; then
					echo "INSTALLER: MESSAGE L_DEFAULTING_TO_RSYNC"
					unsquashfs -l $path | \
						sed -e 's/^squashfs[-]root//g' 1> ${logfile}.new
					tail -n +3 ${logfile}.new 1> $logfile
					rsync --files-from $logfile -au / $rootdir/ \
						2>> $rootdir/tmp/rsync.log
					rc=0
				else
					unsquashfs -n -f -dest $rootdir $path
					rc=$?
				fi
			else
				unsquashfs -n -f -dest $rootdir $path
				rc=$?
			fi

			if [ $rc != 0 ]; then
				return 1
			fi
		fi
	done < ${pkglist}

	return 0
}

extract_archive() {

	local package="$1"
	local pkgtype="$2"
	local name="$3"
	local srcname="$4"
	local version="$5"
	local revision="$6"
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

	if [ "$PKGMEDIA" = "network" ]; then
		local sig="$(sha1sum $ARCHIVE | cut -f1 -d' ')"

		if [ "$sig" != "$SHA1SUM" ]; then
			echo "Corrupted $package" >> $TMP/pkg-sha1sum.errs
			return 1
		fi
	fi

	files="$(ls $ROOTDIR/*.sh 2> /dev/null)"

	if [ ! -z "$files" ]; then
		for f in $files; do
			cp -f "$f" $INSTALL_DIR/scripts/
			unlink "$f" 2> /dev/null
		done
	fi

	if [ "$KEEP_ARCHIVES" = false ]; then
		if [ "$pkgtype" != "meta" -a "$pkgtype" != "download" ]; then
			unlink $ARCHIVE 2> /dev/null
		fi
	fi

	echo "UPDATE packages SET status='unpacked' WHERE identifier = '$name' AND version = '$version';" >> "$DB_UPDATES"

	if config_pkg $name ; then

		echo -e "UPDATE activity SET version='$version', identfier='$name', revision='$revision', \"build-nb\" = '$buildnb' status='installed', rootdir='$ROOTDIR' WHERE identifier = '$name';" >> "$DB_ACTIVITY"

		if [ "$name" = "sysvinit-scripts" ]; then
			d-set-misc-files.sh
		fi
	else
		echo $pkg >> $TMP/pkg-config.errs
	fi
	return 0
}

# Main starts here ...
SCRIPTS=""
SHA1SUM=""
ARCHIVE=""
UNPACKED=0
UNPACK_MODE="$1"
KEEP_ARCHIVES=false
PKGLIST="$TMP/packages.lst"

INSTALL_DIR="$ROOTDIR/var/cache/brzpkg/packages/"
DOWNLOAD_DIR="$ROOTDIR/var/cache/brzpkg/archives/"

PKGTYPE="$(cat $TMP/selected-pkgtype 2> /dev/null)"
SRCMEDIA="$(cat $TMP/selected-source-media 2> /dev/null)"
PKGMEDIA="$(echo "$SRCMEDIA" | tr '[:upper:]' '[:lower:]')"

mkdir -p $ROOTDIR/tmp
mkdir -p $ROOTDIR/etc/brzpkg/
mkdir -p $ROOTDIR/etc/reserved
mkdir -p $INSTALL_DIR
mkdir -p $DOWNLOAD_DIR

touch $TMP/pkg-config.errs
touch $TMP/pkg-unpack.errs
touch $TMP/pkg-sha1sum.errs
touch $TMP/pkg-failed.errs

UPDATE="$(cat $TMP/update-mode 2> /dev/null)"
PKGSRC="$(cat $TMP/selected-pkgsrc 2> /dev/null)"
PKGHOST="$(cat $TMP/selected-source 2> /dev/null)"
IGNOPTIONS="-Xarchive -Xdepends -Xupgrade"

if [ "$SRCMEDIA" = "NETWORK" ]; then

	if [ "$UPDATE" != "yes" ]; then
		IGNOPTIONS="$IGNOPTIONS -Xremoval"
	fi

	echo "INSTALLER: MESSAGE L_INSTALLING_PACKAGES"
	sync; sleep 1

	if [ "$PKGSRC" = "WEB" ]; then
		brzpkg --yes -q -q -f \
			$IGNOPTIONS -T $ROOTDIR -I $DESKTOP

	elif [ -n "$PKGHOST" ]; then
		brzpkg --yes -q -q -f \
			$IGNOPTIONS -T $ROOTDIR -L $PKGHOST -I $DESKTOP
	fi

	if [ $? != 0 ]; then
		echo "INSTALLER: FAILURE L_INSTALLING_PACKAGES_FAILED"
		exit 1
	fi
elif [ "$PKGTYPE" = "squashfs" ]; then

	echo "INSTALLER: MESSAGE L_UNPACKING_SQUASHFS_MODULES"
	sync; sleep 1

	if ! unpack_squashfs "$ROOTDIR" "$PKGLIST" ; then
		echo "INSTALLER: FAILURE L_UNPACKING_SQUASHFS_MODULES_FAILED"
		exit 1
	fi
elif [ "$PKGTYPE" = "package" ]; then
	echo "INSTALLER: MESSAGE L_INSTALLING_PACKAGES"
	sync; sleep 1

	if [ -n "$PKGHOST" ]; then
		brzpkg --yes -q -q -f \
			$IGNOPTIONS -T $ROOTDIR -L $PKGHOST -I $DESKTOP
	else
		brzpkg --yes -q -q -f \
			$IGNOPTIONS -T $ROOTDIR -I $DESKTOP
	fi

	if [ $? != 0 ]; then
		echo "INSTALLER: FAILURE L_INSTALLING_PACKAGES_FAILED"
		exit 1
	fi
else
	DB_ACTIVITY="$ROOTDIR/tmp/db-activity"
	DB_UPDATES="$ROOTDIR/tmp/db-updates"

	echo "BEGIN TRANSACTION;" 1> "$DB_ACTIVITY"
	echo "BEGIN TRANSACTION;" 1> "$DB_UPDATES"

	echo "INSTALLER: MESSAGE L_INSTALLING_PACKAGES"
	unpack_distro "$PKGLIST"

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

	echo "END TRANSACTION;" >> "$DB_UPDATES"
	echo "END TRANSACTION;" >> "$DB_ACTIVITY"

	if [ -e $ROOTDIR/bin/bash -a ! -h $ROOTDIR/bin/sh ]; then
		cd $ROOTDIR/bin
		ln -sf bash sh
	fi
fi

if [ "$?" = 0 ]; then
	echo "INSTALLER: SUCCESS"
	exit 0
fi

echo "INSTALLER: FAILURE"
exit 1

# end Breeze::OS setup script
