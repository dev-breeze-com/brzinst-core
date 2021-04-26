#!/bin/bash
#
# d-vpn.sh virtual private network settings <dev@tsert.com>
# Copyright 2011, Pierre Innocent, Tsert Inc. All Rights Reserved
#
TMP=/var/tmp
ROOTDIR=/mnt/root
MOUNTPOINT=/var/mnt

VPNNAME=""
VPNDOMAIN="dyndns.org"
USERNAME=
PASSWORD=

parse_fields () {

	count=1

	fields=$(cat $TMP/vpn.log)
	fields=$(echo $fields | sed -e 's/[\n ]/ , /g')

	for f in fields; do
		case $count in
			1) echo $f 1> $TMP/dyndns-fqdn ;;
			2) echo $f 1> $TMP/dyndns-user ;;
			3) echo $f 1> $TMP/dyndns-passwd ;;
		esac
		count=$(( $count + 1 ))
	done

	return 0
}

dialog --colors --ok-label "Submit" \
  --backtitle "Breeze::OS Kodiak.light Installer" \
  --title "Breeze::OS Kodiak.light -- Virtual Private Network" \
  --form "\nRemember, when you create your dynamic DNS account; the information you enter, must be as you specified here. Possible domain names are dyndns.org, dyndns-at-home.org, dyndns-home.org" 15 60 4 \
  "VPN Name:"  1 1 "$VPNNAME" 1 16 45 0 \
  "VPN Domain:"  2 1 "$VPNDOMAIN" 2 16 45 0 \
  "User Name:" 3 1 "$USERNAME" 3 16 45 0 \
  "Password:"  4 1 "$PASSWORD" 4 16 45 0 2> $TMP/vpn.log

if [ $? = 0 ]; then
	parse_fields true
fi

clear
exit 0

