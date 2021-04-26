#!/bin/bash 
#
# Copyright 2013 Pierre Innocent, Tsert Inc., All Rights Reserved
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

PACKAGE_LIST=
RETCODE="DESKTOP"

ARCH="`cat $TMP/selected-arch 2> /dev/null`"
DISTRO="`cat $TMP/selected-distro 2> /dev/null`"
KERNEL="`cat $TMP/selected-kernel 2> /dev/null`"
DEVICE="`cat $TMP/selected-device 2> /dev/null`"
RELEASE="`cat $TMP/selected-release 2> /dev/null`"
DESKTOP="`cat $TMP/selected-desktop 2> /dev/null`"
INSTALL_MEDIA="`cat $TMP/install-media 2> /dev/null`"
SELECTED_MEDIA="`cat $TMP/selected-media 2> /dev/null`"

check_nb_pkgs() {

	PACKAGE_LIST="./install/desktop/$1.lst"

	if [ -f "$PACKAGE_LIST" ]; then

		/bin/grep -v "Stats: " $PACKAGE_LIST 1> $TMP/packages.lst
		STATS="`grep 'Stats: ' $PACKAGE_LIST | /bin/sed 's/Stats: //g'`"

		NB_PACKAGES="`echo "$STATS" | cut -f 1 -d /`"
		DISK_SPACE="`echo "$STATS" | cut -f 3 -d /`"

		echo -n "$NB_PACKAGES" 1> $TMP/total-nb-packages
		echo -n "$DISK_SPACE" 1> $TMP/total-disk-space
	fi
	return 0
}

while [ 0 ]; do

dialog --colors \
	--backtitle "Breeze::OS $RELEASE Installer" \
	--title "Breeze::OS Setup" \
	--default-item "$RETCODE" \
	--menu "\nSelect an option below ..." 11 60 3 \
		"DESKTOP" "Select your desktop installation" \
		"INTERNET" "Prepare internet account info" \
		"USERS" "Create user accounts" 2> $TMP/retcode

	if [ "$?" = 0 ]; then
		RETCODE="`cat $TMP/retcode`"
	else
		clear
		unlink $TMP/retcode
		exit 1
	fi

	if [ "$RETCODE" = "DESKTOP" ]; then

		dialog --colors \
			--backtitle "Breeze::OS $RELEASE Installer" \
			--title "Breeze::OS Setup -- Desktop Selection" \
			--default-item "xfce" \
			--menu "\nSelect a desktop installation ..." 10 60 2 \
		"basic" "A basic Xfce desktop installation" \
		"xfce" "A full Xfce desktop installation" 2> $TMP/selected-desktop

		if [ "$?" != 0 ]; then
			RETCODE=""
			continue
		fi

		SELECTED_DESKTOP="`cat $TMP/selected-desktop`"
		export SELECTED_DESKTOP

		check_nb_pkgs $SELECTED_DESKTOP
		RETCODE="INTERNET"
	fi

	if [ "$RETCODE" = "INTERNET" ]; then

		clear
		cat ./install/text/internet.txt
		read command
		command="`echo $command | tr '[:upper:]' '[:lower:]'`"

		if [ "$command" = "r" ]; then
			SELECTED_NET="router"
		elif [ "$command" = "a" ]; then
			SELECTED_NET="adsl"
		elif [ "$command" = "c" ]; then
			SELECTED_NET="cable"
		elif [ "$command" = "d" ]; then
			SELECTED_NET="dialup"
		elif [ "$command" = "w" ]; then
			SELECTED_NET="wireless"
		elif [ "$command" = "n" ]; then
			SELECTED_NET="none"
		else
			SELECTED_NET="none"
		fi

		echo -n "$SELECTED_NET" 1> $TMP/selected-network

		if [ "$SELECTED_NET" = "router" -o "$SELECTED_NET" = "none" ]; then
			RETCODE="USERS"
		else
			d-internet.sh $SELECTED_NET

			if [ "$?" = 0 ]; then
				RETCODE="USERS"
			else
				RETCODE=""
			fi
		fi
	fi

	if [ "$RETCODE" = "USERS" ]; then

		clear
		cat ./install/text/users.txt
		read command

		d-users.sh

		if [ $? = 0 ]; then
			clear
			exit 0
		fi
	fi
done

exit 0

# end Breeze::OS setup script

