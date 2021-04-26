#!/bin/bash
#
# d-postint.sh post installation script <dev@tsert.com>
# Copyright 2011, Pierre Innocent, Tsert Inc. All Rights Reserved
#
TMP=/var/tmp
ROOTDIR=/mnt/root
MOUNTPOINT=/var/mnt

DRIVE_NAME="$(cat $TMP/drive-model)"
SELECTED_DRIVE="$(cat $TMP/selected-drive)"
DRIVE_ID="$(basename $SELECTED_DRIVE)"

/bin/cp $TMP/postinst $ROOTDIR/install/postinst.map

echo $PASSWORD 1> $ROOTDIR/install/postinst.map

/bin/cat $TMP/postinst >> $ROOTDIR/install/postinst.map

exit 0

