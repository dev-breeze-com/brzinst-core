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

MODE="$1"
DERIVED="`cat $TMP/selected-derivative 2> /dev/null`"
RELEASE="`cat $TMP/selected-release 2> /dev/null`"
HOSTNAME="`cat $TMP/selected-hostname 2> /dev/null`"

echo "no" 1> $TMP/internet-enabled

if [ "$HOSTNAME" = "" ]; then
	if [ "$MODE" = "dialog" ]; then
		dialog --colors --clear \
			--backtitle "Breeze::OS $RELEASE Installer" \
			--title "Breeze::OS Setup -- Network Configuration" \
			--msgbox "\nThe \Zb\Z4hostname\Zn \Z1must be specified\Zn !" 7 50 2> /dev/null
	fi

	if [ "$MODE" = "batch" ]; then
		echo "Your hostname must be specified !"
		echo "INSTALLER: FAILURE"
	fi
	exit 1
fi

ETHERNET="`lspci | grep -F -i 'ethernet'`"
ETHERNET="`echo "$ETHERNET" | sed -r 's/ethernet.*$//g'`"
ETHERNET="`echo "$ETHERNET" | sed -r 's/^.*[ ]//g'`"

if [ -s /etc/resolv.conf ]; then
	if [ "$MODE" = "dialog" ]; then
		dialog --colors --clear \
			--backtitle "Breeze::OS $RELEASE Installer" \
			--title "Breeze::OS Setup -- Network Configuration" \
			--msgbox "\nYour network has \Z1already\Zn been configured !\n" 7 55
	fi

	echo "yes" 1> $TMP/internet-enabled

	if [ "$MODE" = "batch" ]; then
		echo "Your network has already been configured !"
		echo "INSTALLER: SUCCESS"
	fi
	exit 0
fi

# If we can get information from a local DHCP server, we store that for later:
if grep -wq nodhcp /proc/cmdline ; then
	if [ "$MODE" = "dialog" ]; then
		dialog --colors --clear \
			--backtitle "Breeze::OS $RELEASE Installer" \
			--title "Breeze::OS Setup -- Network Configuration" \
			--msgbox "\nDHCP network probing was disabled on boot !\n" 7 55
	fi

	if [ "$MODE" = "batch" ]; then
		echo "DHCP network probing was disabled on boot !"
		echo "INSTALLER: SUCCESS"
	fi
	exit 0
fi

DEVICES="`cat /proc/net/dev | grep -F ':' | \
	sed -r "s/^ *//" | cut -f1 -d: | grep -v lo | sort`"

for EDEV in eth0 $DEVICES; do

	if grep -q `echo ${EDEV}: | cut -f 1 -d :`: /proc/net/wireless ; then
		continue # skip wireless interfaces
	fi

	if [ "$MODE" = "dialog" ]; then
		dialog --colors \
			--backtitle "Breeze::OS $RELEASE Installer" \
			--title "Breeze::OS Setup -- Network Configuration" \
			--infobox "\nPlease wait -- probing network on interface $EDEV !\n" 5 55
	fi

	if [ -x /sbin/udhcpc -o -h /sbin/udhcpc ]; then
		/sbin/udhcpc -f -n -q -t 5 -i $EDEV \
			1> $TMP/dhcpcd-${EDEV}.info 2> /dev/null
	else
		/sbin/dhcpcd -t 10 -h $HOSTNAME $EDEV \
			1> $TMP/dhcpcd-${EDEV}.info 2> /dev/null
	fi

	if [ ! -s /etc/resolv.conf ]; then
		if [ -x /sbin/udhcpc -o -h /sbin/udhcpc ]; then
			/sbin/udhcpc -f -n -q -t 5 -i $EDEV \
				1> $TMP/dhcpcd-${EDEV}.info 2> /dev/null
		else
			/sbin/dhcpcd -t 10 $EDEV \
				1> $TMP/dhcpcd-${EDEV}.info 2> /dev/null
		fi
	fi
	done

if [ -s /etc/resolv.conf ]; then

	if [ "$MODE" = "dialog" ]; then
		dialog --colors --clear \
			--backtitle "Breeze::OS $RELEASE Installer" \
			--title "Breeze::OS Setup -- Network Configuration" \
			--msgbox "\nYour network has been configured !\n" 7 55
	fi

	NAMESERVER="`grep -F nameserver /etc/resolv.conf`"
#	NAMESERVER="`echo "$NAMESERVER" | cut -f 2 -d '='`"
	echo $NAMESERVER 1> $TMP/selected-nameserver

	GATEWAY="`grep -F -i gateway /etc/resolv.conf`"
#	GATEWAY="`echo "$GATEWAY" | cut -f 2 -d '='`"
	echo $GATEWAY 1> $TMP/selected-gateway

	DOMAIN="`echo "$NAMESERVER" | sed 's/^[^.]*.//g'`"
	echo $DOMAIN 1> $TMP/selected-dhcp-domain

	unlink $TMP/dhcp.map 2> /dev/null

	echo "dns=dhcp" 1> $TMP/dhcp.map
	echo "gateway=$GATEWAY" >> $TMP/dhcp.map
	echo "nameserver=$NAMESERVER" >> $TMP/dhcp.map
	echo "domain=$DOMAIN" >> $TMP/dhcp.map

	echo "yes" 1> $TMP/internet-enabled

	if [ "$MODE" = "batch" ]; then
		echo "Your network has been configured !"
		echo "INSTALLER: SUCCESS"
	fi
	exit 0
fi

# Now, let's call the d-network-cards.sh script to actually do most of the work:
exec d-network-cards.sh "$MODE"

# end Breeze::OS setup script
