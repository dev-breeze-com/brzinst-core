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

PACKAGE_LIST=
RETCODE="WORKGROUP"

DERIVED=$(cat $TMP/selected-derivative 2> /dev/null)
KERNEL=$(cat $TMP/selected-kernel 2> /dev/null)
RELEASE="`cat $TMP/selected-release 2> /dev/null`"

DEVICE=$(cat $TMP/selected-device 2> /dev/null)
DESKTOP=$(cat $TMP/selected-desktop 2> /dev/null)
SELECTED_MEDIA=$(cat $TMP/selected-media 2> /dev/null)

check_nb_pkgs() {

	PACKAGE_LIST="$BRZDIR/desktop/$1.lst"

	if [ -f "$PACKAGE_LIST" ]; then

		/bin/grep -v "Stats: " $PACKAGE_LIST 1> $TMP/packages.lst
		STATS=$(grep 'Stats: ' $PACKAGE_LIST | /bin/sed -r 's/Stats: //g')

		NB_PACKAGES=$(dirname $STATS)
		DISK_SPACE=$(basename $STATS)

		echo -n "$NB_PACKAGES" 1> $TMP/total-nb-packages
		echo -n "$DISK_SPACE" 1> $TMP/total-disk-space
	fi
	return 0
}

while [ 0 ]; do

#		"INDEX" "Indexing engine settings ..." \

dialog --colors \
	--backtitle "Breeze::OS $RELEASE Installer" \
	--title "Breeze::OS Setup (v0.9.0)" \
	--default-item "$RETCODE" \
	--menu "\nSelect an option below ..." 15 60 7 \
		"WORKGROUP" "Select your network installation" \
		"DESKTOP" "Select your desktop installation" \
		"INTERNET" "Prepare internet account info" \
		"KERNEL" "Select your default kernel" \
		"USERS" "Create user accounts" \
		"NVC" "Network Virtual Club settings" \
		"SSL" "Prepare information for SSL keys" 2> $TMP/retcode

	if [ "$?" = 0 ]; then
		RETCODE="`cat $TMP/retcode`"
	else
		clear
		unlink $TMP/retcode
		exit 1
	fi

	if [ "$RETCODE" = "WORKGROUP" ]; then

		clear
		cat ./text/workgroup.txt
		read command
		command=$(echo $command | tr '[:upper:]' '[:lower:]')

#		dialog --colors \
#			--backtitle "Breeze::OS $RELEASE Installer" \
#			--title "Breeze::OS Setup (v0.9.0)" \
#			--default-item "standalone" \
#			--menu "\nSelect a workgroup installation ..." 11 60 7 \
#		"standalone" "A standalone installation" \
#		"network-client" "A network-client installation" \
#		"network-master" "A network-master installation" 2> $TMP/retcode

		RETCODE="DESKTOP"

		if [ "$command" = "c" ]; then
			SELECTED_WORKGROUP="network-client"
		elif [ "$command" = "m" ]; then
			SELECTED_WORKGROUP="network-master"
		elif [ "$command" = "s" ]; then
			SELECTED_WORKGROUP="standalone"
		else
			SELECTED_WORKGROUP="standalone"
			RETCODE=""
		fi
		echo -n "$SELECTED_WORKGROUP" 1> $TMP/selected-workgroup
		export SELECTED_WORKGROUP
	fi

	if [ "$RETCODE" = "DESKTOP" ]; then

		clear
		cat ./text/office.txt
		read command
		command=$(echo $command | tr '[:upper:]' '[:lower:]')

#		dialog --colors \
#			--backtitle "Breeze::OS $RELEASE Installer" \
#			--title "Breeze::OS Setup (v0.9.0)" \
#			--default-item "ooffice" \
#			--menu "\nSelect a desktop installation ..." 11 60 7 \
#		"base" "A basic desktop installation" \
#		"ooffice" "An office-suite desktop installation" \
#		"compleat" "A full desktop installation" 2> $TMP/retcode

		RETCODE="INTERNET"

		if [ "$command" = "r" ]; then
			SELECTED_DESKTOP="replicated"
		elif [ "$command" = "x" ]; then
			SELECTED_DESKTOP="xfce"
		elif [ "$command" = "b" ]; then
			SELECTED_DESKTOP="breeze"
		elif [ "$command" = "c" ]; then
			SELECTED_DESKTOP="compleat"
		else
			SELECTED_DESKTOP="compleat"
			RETCODE=""
		fi

		check_nb_pkgs $SELECTED_DESKTOP

		export SELECTED_DESKTOP
		echo -n "$SELECTED_DESKTOP" 1> $TMP/selected-desktop
	fi

	if [ "$RETCODE" = "INTERNET" ]; then

		clear
		cat ./text/internet.txt
		read command
		command=$(echo $command | tr '[:upper:]' '[:lower:]')

		RETCODE="KERNEL"

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
			RETCODE=""
		fi

		echo -n "$SELECTED_NET" 1> $TMP/selected-network

		if [ "$SELECTED_NET" = "router" -o "$SELECTED_NET" = "none" ]; then
			RETCODE="KERNEL"
		else
			d-internet.sh $SELECTED_NET

			if [ "$?" = 0 ]; then
				RETCODE="KERNEL"
			else
				RETCODE=""
			fi
		fi
	fi

	if [ "$RETCODE" = "KERNEL" ]; then

		lspci | grep 'Communication controller' 1> $TMP/lspci
		MODEM="`cat $TMP/lspci | /bin/sed -r 's/^.*://g'`"
		MODEM=$(echo $MODEM | /bin/sed -r 's/\//_/g')

		lsusb | grep 'WLAN Adapter' 1> $TMP/lsusb
		WIFI="`cat $TMP/lsusb | /bin/sed -r 's/^.*://g'`"
		WIFI="`echo $WIFI | /bin/sed -r 's/^.*://g'`"
		WIFI="`echo $WIFI | /bin/sed -r 's/^[^ ]*//g'`"
		WIFI=$(echo $WIFI | /bin/sed -r 's/WLAN Adapter//g')

		clear
		/bin/cp -f ./text/kernel.txt $TMP/tmpscript

		if [ "$MODEM" = "" ]; then
			/bin/sed -i -r \
				"s/%modem%/Unknown or non-existant DIALUP modem/g" \
				$TMP/tmpscript
		else
			/bin/sed -i -r "s/%modem%/$MODEM/g" $TMP/tmpscript
		fi

		if [ "$WIFI" = "" ]; then
			/bin/sed -i -r \
				"s/%wifi%/Unknown or non-existant WIFI adapter/g" \
				$TMP/tmpscript
		else
			/bin/sed -i -r "s/%wifi%/$WIFI/g" $TMP/tmpscript
		fi

		cat $TMP/tmpscript
		read command
		command=$(echo $command | tr '[:upper:]' '[:lower:]')

		RETCODE="USERS"

		if [ "$command" = "3" ]; then
			SELECTED_KERNEL="athlon-64bit"
		elif [ "$command" = "2" ]; then
			SELECTED_KERNEL="intel-64bit"
		elif [ "$command" = "1" ]; then
			SELECTED_KERNEL="intel-32bit"
		else
			SELECTED_KERNEL="intel-32bit"
			RETCODE=""
		fi
		echo -n "$SELECTED_KERNEL" 1> $TMP/selected-kernel
		export SELECTED_KERNEL
	fi

	if [ "$RETCODE" = "USERS" ]; then

		clear
		cat ./text/users.txt
		read command

		d-users.sh

		if [ $? = 0 ]; then
			RETCODE="INDEX"
		else
			RETCODE=""
		fi
	fi

	if [ "$RETCODE" = "INDEX" ]; then

#		clear
#		cat ./text/indexing.txt
#		read command
#
		d-indexing.sh

		if [ "$?" = 0 ]; then
			RETCODE="NVC"
		else
			RETCODE=""
		fi
	fi

	if [ "$RETCODE" = "NVC" ]; then
		
		if [ "$SELECTED_NET" = "none" -o "$SELECTED_NET" = "" ]; then

			dialog --colors --clear \
				--backtitle "Breeze::OS $RELEASE Installer" \
				--title "Breeze::OS Setup -- NVC Setting" \
				--msgbox "\nYou cannot setup a \Z4network virtual club\Zn (NVC)\n     \Z1without access\Zn to the Internet." 8 50 2> /dev/null
		else
			clear
			cat ./text/nvc.txt
			read command

			d-nvc.sh

			if [ $? = 0 ]; then
				RETCODE="SSL"
			else
				RETCODE=""
			fi
		fi
	fi

	if [ "$RETCODE" = "SSL" ]; then

		clear
		cat ./text/openssl.txt
		read command

		d-openssl.sh

		if [ $? = 0 ]; then
			clear
			exit 0
		fi
	fi
done

exit 0

# end Breeze::OS setup script
