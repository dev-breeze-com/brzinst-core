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

SMACK="$(extract_value services 'smack')"
PKGTYPE="$(cat $TMP/selected-pkgtype 2> /dev/null)"
DERIVED="$(cat $TMP/selected-derivative 2> /dev/null)"

INSTALL_DIR="$ROOTDIR/var/cache/brzpkg/packages/"
DOWNLOAD_DIR="$ROOTDIR/var/cache/brzpkg/archives/"

echo "INSTALLER: MESSAGE L_INIT_FOLDERS"
sync; sleep 1

mkdir -p $ROOTDIR/tmp
mkdir -p $ROOTDIR/boot
mkdir -p $ROOTDIR/sys
mkdir -p $ROOTDIR/proc
mkdir -p $ROOTDIR/var
mkdir -p $ROOTDIR/var/tmp
mkdir -p $ROOTDIR/var/lock

mkdir -p $ROOTDIR/tmp 2> /dev/null
mkdir -p $ROOTDIR/etc/reserved/ 2> /dev/null
mkdir -p $INSTALL_DIR 2> /dev/null
mkdir -p $DOWNLOAD_DIR 2> /dev/null

chmod 0755 $ROOTDIR/
chmod 0755 $ROOTDIR/sys
chmod 0755 $ROOTDIR/proc
chmod 0755 $ROOTDIR/boot
chmod 0755 $ROOTDIR/var

chmod 1777 $ROOTDIR/tmp
chmod 1777 $ROOTDIR/var/tmp
chmod 1777 $ROOTDIR/var/lock

chown root.root $ROOTDIR/sys
chown root.root $ROOTDIR/proc

# Copy temporary files ...
cp -a $TMP $ROOTDIR/

if [ "$SMACK" = "enabled" ]; then
	# Simplified Mandatory Access Control
	mkdir -p "$ROOTDIR/smack"
	mkdir -p "$ROOTDIR/etc/smack"
fi

if [ -e $ROOTDIR/usr/lib/dbus-1.0/dbus-daemon-launch-helper ]; then
	# For dbus to work properly
	chmod u+s $ROOTDIR/usr/lib/dbus-1.0/dbus-daemon-launch-helper
fi

if [ "$PKGTYPE" = "package" -o "$PKGTYPE" = "install" -o "$PKGTYPE" = "squashfs" ]; then
	echo "INSTALLER: SUCCESS"
	touch $TMP/pkg-failed.lst
	exit 0
fi

echo "INSTALLER: MESSAGE L_INIT_ETC_FILES"
sync; sleep 1

d-set-etc-files.sh

echo "INSTALLER: MESSAGE L_INIT_DATABASES"
sync; sleep 1

if [ ! -f "$ROOTDIR/tmp/titles.lst" ]; then
	zcat ./install/factory/titles.lst.gz 1> $ROOTDIR/tmp/titles.lst

	if [ "$?" = 0 -a -s $ROOTDIR/tmp/titles.lst ]; then
		unlink ./install/factory/titles.lst.gz
	fi
	echo "INSTALLER: PROGRESS ((filename,titles.lst))"
fi

if [ ! -e $ROOTDIR/etc/packager/packages.db ]; then

	echo "INSTALLER: MESSAGE L_RETRIEVING_PACKAGES_DB"
	sleep 1

	d-retr-file.sh /databases/packages.db.xz \
		$ROOTDIR/etc/packager/packages.db.xz

	if [ "$?" = 0 ]; then
		echo "INSTALLER: MESSAGE L_INFLATING_PACKAGES_DB"
		xz -d $ROOTDIR/etc/packager/packages.db.xz
	fi

	if [ "$?" != 0 ]; then
		echo "INSTALLER: FAILURE L_RETRIEVING_PACKAGES_DB_FAILED"
		exit 1
	fi
	echo "INSTALLER: PROGRESS ((filename,packages.db))"
fi

if [ ! -e $ROOTDIR/etc/packager/descriptions.db.xz ]; then

	echo "INSTALLER: MESSAGE L_RETRIEVING_DESCRIPTIONS_DB"
	sleep 1

	d-retr-file.sh /databases/descriptions.db.xz \
		$ROOTDIR/etc/packager/descriptions.db.xz

	if [ "$?" != 0 ]; then
		echo "INSTALLER: FAILURE L_RETRIEVING_DESCRIPTIONS_DB_FAILED"
		exit 1
	fi
	echo "INSTALLER: PROGRESS ((filename,descriptions.db))"
fi

if [ ! -e $ROOTDIR/etc/packager/updates.db.xz ]; then

	echo "INSTALLER: MESSAGE L_RETRIEVING_UPDATES_DB"
	sleep 1

	d-retr-file.sh /databases/updates.db.xz \
		$ROOTDIR/etc/packager/updates.db.xz

	if [ "$?" != 0 ]; then
		echo "INSTALLER: FAILURE L_RETRIEVING_UPDATES_DB_FAILED"
		exit 1
	fi
	echo "INSTALLER: PROGRESS ((filename,updates.db))"
fi

if [ ! -e $ROOTDIR/etc/packager/manifests.db.xz ]; then
	
	echo "INSTALLER: MESSAGE L_RETRIEVING_MANIFESTS_DB"
	sleep 1

	d-retr-file.sh /databases/manifests.db.xz \
		$ROOTDIR/etc/packager/manifests.db.xz

	echo "INSTALLER: PROGRESS ((filename,manifests.db))"

	if [ "$?" != 0 ]; then
		# Optionally inflate manifests database
		#echo "INSTALLER: MESSAGE L_INFLATING_DESCRIPTIONS_DB"
		#xz -d $ROOTDIR/etc/packager/descriptions.db.xz
		echo "INSTALLER: SUCCESS"
		exit 0
	fi
fi

if [ "$?" = 0 ]; then
	echo "INSTALLER: SUCCESS"
	touch $TMP/pkg-failed.lst
	exit 0
fi

echo "INSTALLER: FAILURE"
exit 1

# end Breeze::OS setup script
