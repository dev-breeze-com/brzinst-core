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
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR IMPLIED
# WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF 
# MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO
# EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, 
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
# PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
# OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, 
# WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR 
# OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF 
# ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
# ALL OTHER INSTALL SCRIPTS under install/bin HAVE THE SAME COPYRIGHT.
# EXCEPT for the modified ones which retains the Slackware copyright.
#
chmod a+rw /dev/null

#TERM=linux
SHELL="/bin/sh"
PATH="./:/bin:$PATH"
SERVER="http://master.localdomain:8012"

# The available uses for your hard drive are:
# - normal: use hard drive with normal partitions. 
# - lvm:     use LVM to partition the disk
# - raid:    use RAID drive partitioning method
# - crypto:  use LVM within an encrypted partition
DISKTYPE="normal"

# Hostname domain
DOMAIN="localdomain"

# Preseeding file, if any
PRESEED="$BREEZE_PRESEED"

ARCH=$(grep -F ARCH /etc/os-release)
ARCH=$(echo "$ARCH" | cut -f 2 -d '=')

DERIVED=$(grep -F DERIVED /etc/os-release)
DERIVED=$(echo "$DERIVED" | cut -f 2 -d '=' | tr '[:upper:]' '[:lower:]')

RELEASE=$(grep -F CODENAME /etc/os-release)
RELEASE=$(echo "$RELEASE" | cut -f 2 -d '=')

# Initialize folder paths
. d-dirpaths.sh

echo "$ARCH" 1> $TMP/selected-arch
echo "$DOMAIN" 1> $TMP/selected-domain

echo "true" 1> $TMP/netcfg-enabled
echo "$PRESEED" 1> $TMP/preseed-enabled

echo "$DISKTYPE" 1> $TMP/selected-disktype
echo "$DERIVED" 1> $TMP/selected-derivative
echo "$RELEASE" 1> $TMP/selected-release
echo "$SERVER" 1> $TMP/selected-server
echo "MBR" 1> $TMP/selected-gpt-mode

echo "US" 1> $TMP/selected-timezone-area
echo "US/Eastern" 1> $TMP/selected-timezone
echo "pc104" 1> $TMP/selected-keyboard
echo "us" 1> $TMP/selected-country
echo "en_US" 1> $TMP/selected-locale
echo "us" 1> $TMP/selected-kbd-layout
echo "qwerty/us" 1> $TMP/selected-keymap

export TERM SHELL PATH
export ARCH DERIVED RELEASE PRESEED
export ROOTDIR MOUNTUSB MOUNTPOINT

while [ 0 ]; do

	clear
	less -R ./license.txt

	echo "" 1> $TMP/prompt.txt
	echo "If you have carefully read the previous license page;" >> $TMP/prompt.txt
	echo "and, agree with the terms and conditions; then proceed ? " >> $TMP/prompt.txt
	echo "" >> $TMP/prompt.txt

	dialog --colors \
		--backtitle "Breeze::OS $RELEASE Installer"  \
		--title "Breeze::OS $RELEASE Setup (v0.9.0)" \
		--ok-label "Yes" --cancel-label "Back" \
		--extra-button --extra-label "No" \
		--textbox $TMP/prompt.txt 8 70

	RETCODE="$?"

	echo "$RETCODE" 1> $TMP/retcode

	if [ "$RETCODE" = 3 ]; then #Cancel
		clear
		exit 1
	fi

	if [ "$RETCODE" = 0 ]; then #Yes
		break
	fi
done

RETCODE="INTRO"

while [ 0 ]; do

dialog --colors --clear \
	--backtitle "Breeze::OS $RELEASE Installer" \
	--title "Breeze::OS $RELEASE Setup (v0.9.0)" \
	--default-item "$RETCODE" \
	--menu "\nSelect an option below ..." 14 50 6 \
"INTRO" "Introduction" \
"LOCALE" "Select your locale" \
"SYSTEM" "Prepare your system" \
"DESKTOP" "Select your destop settings" \
"INSTALL" "Install software packages" \
"EXIT" "Exit setup" 2> $TMP/retcode

	if [ $? = 0 ]; then
		RETCODE="`cat $TMP/retcode`"
	else
		unlink $TMP/retcode
		break
	fi

	if [ "$RETCODE" = "INTRO" ]; then
		clear
		cat ./text/intro.txt
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
		d-system.sh $DERIVED

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

		RETCODE=""

		if [ "$DERIVED" = "debian" -a "$PRESEED" = "true" ]; then
			d-preseed.sh
			exit 0
		fi

		d-install.sh

		if [ "$?" = 0 ]; then
			RETCODE="EXIT"
			continue
		fi
	fi

	if [ "$RETCODE" = "EXIT" ]; then

		RETCODE=""
		d-cleanup.sh

		if [ "$?" = 0 ]; then
			clear
			exit 0
		fi
	fi
done

clear
exit 1

# end Breeze::OS setup script

