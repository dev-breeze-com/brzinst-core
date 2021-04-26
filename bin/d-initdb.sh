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

create_misc_folders()
{
	local rootdir="$1"

	mkdir -p $rootdir/tmp
	mkdir -p $rootdir/boot
	mkdir -p $rootdir/sys
	mkdir -p $rootdir/proc
	mkdir -p $rootdir/var
	mkdir -p $rootdir/etc

	# For X11 to work properly
	mkdir -p $rootdir/var/tmp
	mkdir -p $rootdir/var/lock
	chmod 0755 $rootdir/var
	chmod 1777 $rootdir/var/tmp
	chmod 1777 $rootdir/var/lock

	# Make sure /tmp is readable by all
	mkdir -p $rootdir/tmp
	chmod 1777 $rootdir/tmp

	# Make sure that /var/run/dbus exists ...
	mkdir -p $rootdir/var/run/dbus

	# Make sure brzpkg folder exists ...
	mkdir -p $rootdir/etc/brzpkg

	# Make sure root owns /usr/share/ ...
	if [ -d $rootdir/usr/share/ ]; then
		chmod 0755 $rootdir/usr/share/*
		chown root.root $rootdir/usr/share/*
	fi

	# Make sure /etc/config/ is present
	mkdir -p $ROOTDIR/etc/config/settings
	chmod 0755 $ROOTDIR/etc/config/settings

	mkdir -p $ROOTDIR/etc/config/network
	chmod 0755 $ROOTDIR/etc/config/network

	mkdir -p $ROOTDIR/etc/config/services
	chmod 0755 $ROOTDIR/etc/config/services

	# Make sure slackware folders are present
	mkdir -p $rootdir/var/log/setup
	mkdir -p $rootdir/var/log/packages
	mkdir -p $rootdir/var/log/scripts

	mkdir -p $rootdir/etc/reserved
	mkdir -p $rootdir/etc/ld.so.conf.d

	mkdir -p $rootdir/share/archives/
	mkdir -p $rootdir/var/cache/packages/

	chmod 0755 $rootdir/
	chmod 0755 $rootdir/sys
	chmod 0755 $rootdir/proc
	chmod 0755 $rootdir/boot
	chmod 0755 $rootdir/var

	chown root.root $rootdir/sys
	chown root.root $rootdir/proc

	if [ -e $rootdir/usr/lib/dbus-1.0/dbus-daemon-launch-helper ]; then
		# For dbus to work properly
		chmod u+s $rootdir/usr/lib/dbus-1.0/dbus-daemon-launch-helper
	fi

	return 0
}

copy_tmp_files()
{
	local rootdir="$1"

	mkdir -p $rootdir/tmp
	chmod a+rwxt $rootdir/tmp
	cp -a $TMP/* $rootdir/tmp/

	mkdir -p $rootdir/var/tmp/brzinst
	cp -a $TMP/* $rootdir/var/tmp/brzinst/

	return 0
}

echo_message "L_CREATING_NEEDED_FOLDERS"
create_misc_folders "$ROOTDIR"

echo_message "L_COPYING_TEMPORARY_FILES"
copy_tmp_files "$ROOTDIR"

echo "INSTALLER: SUCCESS"
exit 0

# end Breeze::OS setup script
