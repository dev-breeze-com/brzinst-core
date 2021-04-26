#!/bin/bash
#
# GNU GENERAL PUBLIC LICENSE Version 3
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

unlink $ROOTDIR/etc/indexer/init-selections.lst 2> /dev/null

dialog --colors --clear \
	--backtitle "Breeze::OS $RELEASE Installer" \
	--title "Breeze::OS $RELEASE Setup -- Indexing" \
	--menu "\nChoose \Z1NO INDICES\Zn if you do not want your drives to be \
indexed automatically after installation. Indexing your drives, right after installation, takes a while.\n\n\
Indexing folders is done through explicit requests. \
You may choose to \Z1manually index\Zn your drives after installation; \
by issuing an indexing request, through the \Z1Desktop Launcher\Zn, \
on a given folder.\n\n\
Select a post-installation indexing option ?" 19 70 3 \
"NO INDICES" "No post-installation indexing" \
"HELP FILES" "Help and Documentation files, only" \
"HOME DESKTOP" "Your home partition and desktop installation" 2> $TMP/selected-indexing

if [ "$?" != 0 ]; then
	exit 1
fi

RETCODE="`cat $TMP/selected-indexing`"

if [ "$RETCODE" != "NO INDICES" ]; then

	touch $ROOTDIR/etc/indexer/init-selections.lst

	if [ "$RETCODE" = "HELP FILES" ]; then
		echo "/usr/doc" >> $ROOTDIR/etc/indexer/init-selections.lst
		echo "/usr/info" >> $ROOTDIR/etc/indexer/init-selections.lst
		echo "/usr/man" >> $ROOTDIR/etc/indexer/init-selections.lst
		echo "/usr/share/info" >> $ROOTDIR/etc/indexer/init-selections.lst
		echo "/usr/share/doc" >> $ROOTDIR/etc/indexer/init-selections.lst
		echo "/usr/share/man" >> $ROOTDIR/etc/indexer/init-selections.lst
	fi

	if [ "$RETCODE" = "HOME DESKTOP" ]; then

		echo "/usr/doc" >> $ROOTDIR/etc/indexer/init-selections.lst
		echo "/usr/info" >> $ROOTDIR/etc/indexer/init-selections.lst
		echo "/usr/man" >> $ROOTDIR/etc/indexer/init-selections.lst
		echo "/usr/share/doc" >> $ROOTDIR/etc/indexer/init-selections.lst
		echo "/usr/share/info" >> $ROOTDIR/etc/indexer/init-selections.lst
		echo "/usr/share/man" >> $ROOTDIR/etc/indexer/init-selections.lst

		echo "/usr/share/icons/" >> $ROOTDIR/etc/indexer/init-selections.lst
		echo "/usr/share/fonts/" >> $ROOTDIR/etc/indexer/init-selections.lst
		echo "/usr/share/backgrounds/" >> $ROOTDIR/etc/indexer/init-selections.lst
		echo "/usr/share/sounds/" >> $ROOTDIR/etc/indexer/init-selections.lst

		echo "/home" >> $ROOTDIR/etc/indexer/init-selections.lst

		if [ -d "/usr/lib/libreoffice/basis3.2/share/gallery" ]; then
			echo "/usr/lib/libreoffice/basis3.2/share/gallery" \
				>> $ROOTDIR/etc/indexer/init-selections.lst
		fi
		if [ -d "/usr/lib/openoffice/basis3.2/share/gallery" ]; then
			echo "/usr/lib/openoffice/basis3.2/share/gallery" \
				>> $ROOTDIR/etc/indexer/init-selections.lst
		fi
		if [ -d "/opt/openoffice.org/basis3.4/share/gallery/" ]; then
			echo "/opt/openoffice.org/basis3.4/share/gallery/" \
				>> $ROOTDIR/etc/indexer/init-selections.lst
		fi
	fi
fi

exit 0

