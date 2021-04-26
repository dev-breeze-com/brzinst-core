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
# d-unmount-drives.sh Unmount unused partitions <dev@tsert.com>
#

# Initialize folder paths
. d-dirpaths.sh

SELECTED_MEDIA=$(cat $TMP/selected-media 2> /dev/null)
SELECTED_DRIVE=$(cat $TMP/selected-drive 2> /dev/null)
SELECTED_DEVICE=$(cat $TMP/selected-device 2> /dev/null)
SELECTED_SOURCE=$(cat $TMP/selected-source 2> /dev/null)

dialog --colors \
	--backtitle "Breeze::OS $RELEASE Installer" \
	--title "Breeze::OS $RELEASE Setup (v0.9.0)" \
	--yesno "\nUnmount all unused drives, before configuration ?" 7 55 2> /dev/null

if [ "$?" != 0 ]; then
	clear
	exit 0
fi

/bin/lsblk -d -n -l -o 'kname,type,mountpoint' 1> $TMP/lsblk.log
/bin/sed -i "s/[ ][ ]*/ /g" $TMP/lsblk.log

while read line; do

	type=$(echo "$line" | cut -f 2 -d ' ')
	device=$(echo "$line" | cut -f 1 -d ' ')
	mountpoint=$(echo "$line" | cut -f 3 -d ' ')

	if [ "$mountpoint" = "" ]; then
		if [ "`echo \"$SELECTED_DRIVE\" | grep $name`" = "" ]; then
			if [ "`echo \"$SELECTED_SOURCE\" | grep $name`" = "" ]; then
				umount /dev/$name 2> /dev/null
			fi
		fi
	fi
done

exit 0

