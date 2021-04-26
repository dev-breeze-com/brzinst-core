#!/bin/bash
#
# GNU GENERAL PUBLIC LICENSE Version 3
#
# Copyright 1993, 1999, 2002 Patrick Volkerding, Moorhead, MN.
# Use and redistribution covered by the same terms as the "setup" script.
#
# Copyright 2015 Pierre Innocent, Tsert Inc., All Rights Reserved
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

DERIVED="`cat $TMP/selected-derivative 2> /dev/null`"
RELEASE="`cat $TMP/selected-release 2> /dev/null`"

while [ 0 ]; do

	# OK, at this point $MOUNTPOINT should not have anything mounted on it,
	# but we will umount just in case.
	umount $MOUNTPOINT 2> /dev/null

	# Anything mounted on $MOUNTPOINT now is a fatal error:
	if mount | grep "$MOUNTPOINT" 1> /dev/null 2> /dev/null ; then
		echo "Can't umount $MOUNTPOINT.  Reboot machine and run setup again."
		exit
	fi

	# If the mount table is corrupt, the above might not do it, so we will
	# try to detect Linux and FAT32 partitions that have slipped by:
	if [ -d $MOUNTPOINT/lost+found -o -d $MOUNTPOINT/recycled \
		 -o -r $MOUNTPOINT/io.sys ]; then
		echo "Mount table corrupt.  Reboot machine and run setup again."
		exit
	fi

cat << EOF > $TMP/tempmsg

OK, we will install from an ISO9660 file on the current filesystem.
You may install from any part of the current directory structure,
no matter the media. You will need to type in the name 
of the ISO9660 file containing the source disk.

Which ISO9660 file would you like to install from?
EOF

	dialog --colors --clear \
		--backtitle "Breeze::OS $RELEASE Installer" \
		--title "INSTALL FROM THE CURRENT FILESYSTEM" \
		--inputbox "`cat $TMP/tempmsg`" 19 67 2> $TMP/source-iso

	unlink $TMP/tempmsg

	if [ $? != 0 ]; then
		 unlink $TMP/source-iso
		 exit 1
	fi

	ISOFILE="`cat $TMP/source-iso`"

	if [ -r $ISOFILE ]; then
		mount -o loop,ro -t iso9660 $ISOFILE $MOUNTPOINT

		echo "$ISOFILE" 1> $TMP/selected-source
		echo "$MOUNTPOINT" 1> $TMP/selected-source-path
		exit 0
	else
 cat << EOF > $TMP/tempmsg

Sorry - the ISO9660 file you specified is not valid. Please check and try again.

(ISO9660 file given: $ISOFILE)

EOF
	dialog --colors --clear \
		--backtitle "Breeze::OS $RELEASE Installer" \
		--title "INVALID ISO9660 file ENTERED" \
		--msgbox "`cat $TMP/tempmsg`" 10 65
 fi
done

exit 0

