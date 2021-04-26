#!/bin/bash
#
# (C) Pierre Innocent, Tsert Inc. <dev@tsert.com>
# Copyright 2011, All Rights Reserved.
#

FOLDERS=false
CREATE=false

USER=$1
ROOTDIR=/mnt/root
MOUNTPOINT=/var/mnt
DDIR=$ROOTDIR/etc/desktop

OTHERS="cdrom,disk,floppy,dialout,audio,video,scanner,plugdev,powerdev,bluetooth,netdev"

create_folders() {

	USER=$1
	HOMEDIR=$2
	USERDIR=$DDIR/users/$USER

	echo "USER=$1 HOMEDIR=$2"
	umask 022

	/bin/cp -rf $DDIR/skel/user-config $USERDIR

	ls $USERDIR

	if [ "$USER" = "tsert" ]; then
		if [ ! -f $USERDIR/connections.cfg ]; then
			/bin/cp $DDIR/skel/connections-tsert.cfg $USERDIR/connections.cfg
		fi

		if [ ! -f $DDIR/password/tsert.cfg ]; then
			/bin/cp $DDIR/skel/tsert.cfg $DDIR/password/
		fi

		if [ ! -f $DDIR/password/salt.cfg ]; then
			/bin/cp $DDIR/skel/salt.cfg $DDIR/password/
		fi
	else
		if [ ! -f $DDIR/password/$USER.cfg ]; then
			/bin/cp -f $DDIR/skel/password.cfg $DDIR/password/$USER.cfg
		fi
		ls $USERDIR
	fi

	chown -R tsert:users $USERDIR/
	chmod -R go-rwx,g+r $USERDIR/
	chmod go-rwx "$USERDIR/*.cfg"
	chmod u+rwx,g+rx $USERDIR

	chown -R tsert:users $DDIR/password/
	chmod -R go-rwx $DDIR/password/
}

if [ "$USER" = "" ]; then
	echo "Missing user name"
	exit 1
fi

#/bin/cp $DDIR/skel/adduser.conf /etc/

if [ "$FOLDERS" = true -o "$CREATE" = true ]; then
	if [ "$USER" = "root" ]; then
		create_folders root /root
		chown -R root:root /root
	else
		create_folders $USER /home/$USER
		chown -R $USER:users /home/$USER
		chmod -R go-rwx /home/$USER
	fi
fi

exit 0

