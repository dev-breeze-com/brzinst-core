#!/bin/bash
#
# Copyright 2011 Pierre Innocent, Tsert Inc., All Rights Reserved
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
#  ALL OTHER INSTALL SCRIPTS under install/bin HAVE THE SAME COPYRIGHT.
#
chmod a+rw /dev/null

TMP=/var/tmp
ROOTDIR=/mnt/root
MOUNTPOINT=/var/mnt

TERM=linux
SHELL=/bin/sh
COLOR=on

PATH="./:$PATH"
export PATH ROOTDIR MOUNTPOINT

if [ ! -d "$TMP" ]; then
	mkdir -p "$TMP"
	mkdir -p "$ROOTDIR"
	mkdir -p "$MOUNTPOINT"
else
	files=$(ls /var/tmp/)

	for f in $files; do
		if [ -f "/var/tmp/$f" ]; then
			unlink /var/tmp/$f
		fi
	done
fi

#echo "on" > $TMP/SeTcolor

RETCODE="LOCALE"

while [ 0 ]; do

dialog --colors \
	--backtitle "Breeze::OS Kodiak.light Installer" \
	--title "Breeze::OS Kodiak.light Setup (v0.9.0)" \
	--default-item "$RETCODE" \
	--menu "\nSelect an option below ..." 14 50 6 \
"INTRO" "Introduction ..." \
"LOCALE" "Select your locale ..." \
"SYSTEM" "Prepare your system ..." \
"DESKTOP" "Select your destop settings ..." \
"INSTALL" "Install software packages ..." \
"EXIT" "Exit setup ..." 2> $TMP/retcode

	if [ $? = 0 ]; then
		RETCODE="`cat $TMP/retcode`"
	else
		rm -f $TMP/retcode
		clear
		exit 1
	fi

	if [ "$RETCODE" = "INTRO" ]; then
		clear
		cat ./install/text/intro.txt
		read command
		RETCODE="LOCALE"
	fi

	if [ "$RETCODE" = "LOCALE" ]; then
		d-locale.sh

		if [ $? = 0 ]; then
			RETCODE="SYSTEM"
		fi
	fi

	if [ "$RETCODE" = "SYSTEM" ]; then
		d-system.sh

		if [ $? = 0 ]; then
			RETCODE="DESKTOP"
		fi
	fi

	if [ "$RETCODE" = "DESKTOP" ]; then
		d-desktop.sh

		if [ $? = 0 ]; then
			RETCODE="INSTALL"
		fi
	fi

	if [ "$RETCODE" = "INSTALL" ]; then
		d-install.sh
		RETCODE=""
	fi

	if [ "$RETCODE" = "EXIT" ]; then
		d-cleanup.sh
		exit 0
	fi
done

exit 1

# end Breeze::OS setup script
