#!/bin/bash
#
# (c) Pierre Innocent, Tsert Inc. <dev@tsert.com>
# Copyright 1996-2011, All Rights Reserved.
# See copyright file
#
# $1 =[ stop | start | up | down ]
# $2 = wireless device name
# $3 = access point [essid]
# $4 = encryption mode
# $5 = encryption key
# $6 = nickname
#

#------------------------ Examples Taken from MADWIFI -------------------------
#
#----------------------- To create an access point, use -----------------------
#wlanconfig ath0 create wlandev wifi0 wlanmode ap

#---------------- To create an access point and a station, use ----------------
#wlanconfig ath0 create wlandev wifi0 wlanmode ap
#wlanconfig ath1 create wlandev wifi0 wlanmode sta nosbeacon

#--------------- To create APs that share a single MAC address, use -----------
#------------------- the -bssid flag when creating the VAPs -------------------
#wlanconfig ath0 create wlandev wifi0 wlanmode ap -bssid
#wlanconfig ath1 create wlandev wifi0 wlanmode ap -bssid

#----------------- Finally, to destroy a VAP, issue the command ---------------
#wlanconfig ath0 destroy

###############################################################################

. d-dirpaths.sh

if [ -n "$2" -a -f "$2" ]; then
	device="$(grep -iF -m1 device $2 | cut -f2 -d=)"
	essid="$(grep -iF -m1 essid $2 | cut -f2 -d=)"
	key_mgmt="$(grep -iF -m1 'key-mgmt' $2 | cut -f2 -d=)"
	crypt_key="$(grep -iF -m1 'crypt-key' $2 | cut -f2 -d=)"
	nickname="$(grep -iF -m1 nickname $2 | cut -f2 -d=)"
else
	device=$2
	essid=$3
	key_mgmt=$4
	crypt_key=$5
	nickname=$6
fi

if [ $EUID -gt 0 ]; then
	echo "====================== EXECUTE ONLY AS ROOT ========================"
	exit 1
fi

if [ "$1" != "start" -a "$1" != "up" -a "$1" != "stop" -a "$1" != "down" ]; then
	echo "Usage: wireless-network (start|stop) device essid crypt-mode crypt-key [ nickname ]"
	exit 1
fi

if [ "$device" = "" ]; then
	echo "Usage: wireless-network (start|stop) device essid crypt-mode crypt-key [ nickname ]"
	exit 1
fi

if [ "$essid" = "" ]; then
	echo "Usage: wireless-network (start|stop) device essid crypt-mode crypt-key [ nickname ]"
	exit 1
fi

##### DO NOT REMOVE THIS LINE ######
iwconfig 1> /var/log/iwconfig.log

if [ "$1" = "up" -o "$1" = "start" ]; then
	# Scan for available access points
	iwlist $device scanning > /tmp/iwlist.log

	if [ $? = 0 ]; then
		in_range=$(egrep -i -e 'in\-range' /tmp/iwlist.log)
		signal_level=$(egrep -i -e 'signal\-level' /tmp/iwlist.log)

		# May exit here, if device is active
		if [ "$in_range" != "" -a "signal_level" != "" ]; then
			exit 0
		fi
	fi
fi

export IFACE=$device

if [ "$1" = "stop" -o "$1" = "down" ]; then
	echo "================== SHUTTING-DOWN WIRELESS NETWORK ================"
	if [ "$key_mgmt" = "WPA" ]; then
		if [ -x /etc/wpa_supplicant/ifupdown.sh ]; then
			/etc/wpa_supplicant/ifupdown.sh stop &> /dev/null
		fi
	fi
	ifconfig $device down
	exit 0
fi

if [ "$1" = "up" -o "$1" = "start" ]; then
	echo "================== SETTING-UP WIRELESS NETWORK ================"

	if [ -x /etc/wpa_supplicant/ifupdown.sh ]; then
		/etc/wpa_supplicant/ifupdown.sh start &> /dev/null

	elif [ "$key_mgmt" = "WEP" ]; then
		if [ "$crypt_key" != "" ]; then
			iwconfig $device essid $essid enc $crypt_key
		else
			iwconfig $device essid $essid
		fi
	else
		iwconfig $device essid $essid
	fi

	if ! [ $? = 0 ]; then
		exit 1
	fi

# 	Which mode to use
	iwconfig $device mode Managed

	if ! [ $? = 0 ]; then
		exit 1
	fi

# 	Which rate to use
	iwconfig $device rate 54M

	if ! [ $? = 0 ]; then
		exit 1
	fi

# 	Which nickname to use
	if [ "$nickname" != "" ]; then
		iwconfig $device nickname "$nickname"
	else
		iwconfig $device nickname $(hostname)
	fi

#	Setup the network interface 
	dhclient $device

	if ! [ $? = 0 ]; then
		exit 1
	fi

	exit 0
fi

exit 1

