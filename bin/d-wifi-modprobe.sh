#!/bin/bash

. d-dirpaths.sh

modprobe lib80211_crypt_wep 2> /dev/null
modprobe lib80211_crypt_ccmp 2> /dev/null
modprobe lib80211_crypt_tkip 2> /dev/null

# Check http://wireless.kernel.org/en/users/Drivers/ for compatible drivers

WIFI=$(lsusb | grep 'WLAN Adapter' | grep "Realtek")

if [ -n "$WIFI" ]; then
	modprobe rtl8187 2> /dev/null
	modprobe r8192u_usb 2> /dev/null
	modprobe rtl8192s_usb 2> /dev/null
	modprobe r8712u 2> /dev/null
fi

WIFI=$(lspci | grep 'WLAN Adapter' | grep "Realtek")

if [ -n "$WIFI" ]; then
	modprobe rtl8187 2> /dev/null
	modprobe r8187se 2> /dev/null
	modprobe r8192ce 2> /dev/null
	modprobe r8192ce_pci 2> /dev/null
	modprobe rtl8180 2> /dev/null
fi

WIFI=$(lsusb | grep 'WLAN Adapter' | grep "Broadcomm")

if [ -n "$WIFI" ]; then
	modprobe rndis_wlan 2> /dev/null
fi

WIFI=$(lspci | grep 'WLAN Adapter' | grep "Broadcomm")

if [ -n "$WIFI" ]; then
	modprobe b43 2> /dev/null
fi

WIFI=$(lsusb | grep 'WLAN Adapter' | grep "Atheros")

if [ -n "$WIFI" ]; then
	modprobe ath9k_htc 2> /dev/null
fi

WIFI=$(lspci | grep 'WLAN Adapter' | grep "Atheros")

if [ -n "$WIFI" ]; then
#	modprobe ath5k 2> /dev/null
	modprobe ath9k 2> /dev/null
fi

WIFI=$(lsusb | grep 'WLAN Adapter' | grep "Ralink")

if [ -n "$WIFI" ]; then
#	modprobe rt73usb 2> /dev/null
#	modprobe rt2500usb 2> /dev/null
	modprobe rt2800usb 2> /dev/null
fi

WIFI=$(lspci | grep 'WLAN Adapter' | grep "Ralink")

if [ -n "$WIFI" ]; then
#	modprobe rt2400pci 2> /dev/null
#	modprobe rt2500pci 2> /dev/null
	modprobe rt2800pci 2> /dev/null
fi

exit 0
