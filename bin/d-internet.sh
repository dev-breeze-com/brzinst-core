#!/bin/bash
#
# GNU GENERAL PUBLIC LICENSE Version 3
#
# Copyright 2015 Pierre Innocent, Tsert Inc. All rights reserved.
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

INTERNET="$1"

parse_fields() {

	count=1
	failure=false

	if [ "$INTERNET" = "dialup" ]; then

		while read f; do
			case $count in
				1) username=$f ;;
				2) area_code=$f ;;
				3) phone_nb=$f ;;
				4) password=$f ;;
				5) confirm=$f ;;
				*) ;;
			esac
			count=$(( $count + 1 ))
		done < $TMP/fields.txt

		if [ "$password" = "" -o "$username" = "" -o \
			"$password" != "$confirm" ]; then
			failure=true
		else
			/bin/sed -i -r 's/%username%/$username/g' /etc/wvdial.conf
			/bin/sed -i -r 's/%password%/$password/g' /etc/wvdial.conf
			/bin/sed -i -r 's/%area-code%/$area_code/g' /etc/wvdial.conf
			/bin/sed -i -r 's/%phone-nb%/$phone_nb/g' /etc/wvdial.conf
		fi
	elif [ "$INTERNET" = "adsl" -o "$INTERNET" = "cable" ]; then

		while read f; do
			case $count in
				1) username=$f ;;
				2) primary=$f ;;
				3) secondary=$f ;;
				4) password=$f ;;
				5) confirm=$f ;;
				*) ;;
			esac
			count=$(( $count + 1 ))
		done < $TMP/fields.txt

		if [ "$password" = "" -o "$username" = "" -o \
			"$password" != "$confirm" ]; then
			failure=true
		fi
	elif [ "$INTERNET" = "wifi" ]; then

		while read f; do
			case $count in
				1) essid=$f ;;
				2) wpa_mode=$f ;;
				3) key_mgmt=$f ;;
				4) crypt_key=$f ;;
				5) nickname=$f ;;
				6) wifi_dns=$f ;;
				7) wifi_addr=$f ;;
				*) : ;;
			esac
			count=$(( $count + 1 ))
		done < $TMP/fields.txt

		if [ "$essid" = "" -o "$crypt_key" = "" ]; then
			failure=true
		else
			/bin/sed -i -r 's/%essid%/$essid/g' $TMP/interfaces
			/bin/sed -i -r 's/%nickame%/$nickname/g' $TMP/interfaces
			/bin/sed -i -r 's/%crypt\-key%/$crypt_key/g' $TMP/interfaces
			/bin/sed -i -r 's/%wpa\-mode%/$wpa_mode/g' $TMP/interfaces
			/bin/sed -i -r 's/%key\-mgmt%/$key_mgmt/g' $TMP/interfaces
			/bin/sed -i -r 's/%wifi\-dns%/$wifi_dns/g' $TMP/interfaces
			/bin/sed -i -r 's/%wifi\-addr%/$wifi_addr/g' $TMP/interfaces
		fi
	fi

	if [ "$failure" = true ]; then
		if [ "$INTERNET" = "wifi" ]; then
			dialog --colors --clear \
				--backtitle "Breeze::OS $RELEASE Installer" \
				--title "Error: Incorrect Password or Missing username" \
				--msgbox "\nYou must provide an essid and crypt key !" 7 55 2> /dev/null
		else
			dialog --colors --clear \
				--backtitle "Breeze::OS $RELEASE Installer" \
				--title "Error: Incorrect Password or Missing username" \
				--msgbox "\nYou must provide a username or proper password !" 7 55 2> /dev/null
		fi
		return 1
	fi
	return 0
}

# main starts here...
essid=""
primary=""
secondary=""
username=""
password=""
cryptkey=""
nickname=""
wpa_mode="WPA WPA2"
key_mgmt="WPA-PSK"
wifi_dns="192.168.2.1"
wifi_addr="192.168.1.15"

GATEWAY="`cat $TMP/selected-gateway 2> /dev/null`"

/bin/cp -f $BRZDIR/factory/interfaces $TMP/

if [ "$INTERNET" = "none" ]; then
	exit 0
fi

if [ "$INTERNET" = "router" ]; then
	sed -i -r "s/^192.168.2.1/$GATEWAY/g" $TMP/interfaces
	exit 0
fi

while [ 0 ]; do

	if [ "$INTERNET" = "dialup" ]; then

		/bin/cp -f $BRZDIR/factory/wvdial.conf /etc/

		sed -i -r "s/^192.168.2.1/$GATEWAY/g" $TMP/interfaces

		dialog --insecure --colors --ok-label "Submit" \
		  --backtitle "Breeze::OS $RELEASE Installer" \
		  --title "Breeze::OS $RELEASE -- Dialup Configuration" \
		  --mixedform "\nThe \Z1DNS\Zn \Zb\Z4primary\Zn and \Zb\Z4secondary\Zn IP addresses are optional; but, you must provide your \Zb\Z4username\Zn and \Zb\Z4password\Zn." 14 60 5 \
		  "Username:"  1 1 "$username" 1 12 45 0 0 \
		  "Area Code:" 2 1 "$area_code" 2 12 45 0 0 \
		  "Phone No:"  3 1 "$phone_nb" 3 12 45 0 0 \
		  "Password:"  4 1 "$password" 4 12 45 0 1 \
		  "Confirm:"   5 1 "$confirm" 5 12 45 0 1 2> $TMP/fields.txt

		if [ "$?" != 0 ]; then
			exit 1
		fi
	elif [ "$INTERNET" = "wifi" ]; then

		/bin/cp -f $BRZDIR/factory/interfaces.wifi $TMP/interfaces

		sed -i -r "s/^192.168.2.1/$GATEWAY/g" $TMP/interfaces

		dialog --colors --ok-label "Submit" \
		  --backtitle "Breeze::OS $RELEASE Installer" \
		  --title "Breeze::OS $RELEASE -- Wireless Configuration" \
		  --form "\nYou \Z1must\Zn provide your \Zb\Z4ESSID\Zn network name, as well as your\n\Zb\Z4WPA\Zn mode (WPA-PSK, WPA-EAP, WPA, IEEE), and \Zb\Z4encryption key\Zn.\nYou \Zn\Z1must have\Zn an \Zb\Z4encryption key\Zn to secure your network." 17 65 7 \
		  "Essid:" 1 1  "$essid" 1 12 45 0 \
		  "WPA Mode:" 2 1  "$wpa_mode" 2 12 45 0 \
		  "Key Mgmt:" 3 1  "$key_mgmt" 3 12 45 0 \
		  "Crypt Key"  4 1  "$crypt_key" 4 12 45 0 \
		  "Nick Name:" 5 1  "$nickname" 5 12 45 0 \
		  "Wifi DNS:" 6 1  "$wifi_dns" 6 12 45 0 \
		  "Wifi Addr:" 7 1  "$wifi_addr" 7 12 45 0 2> $TMP/fields.txt

		if [ "$?" != 0 ]; then
			exit 1
		fi
	else
		sed -i -r "s/^192.168.2.1/$GATEWAY/g" $TMP/interfaces

		dialog --insecure --colors --ok-label "Submit" \
		  --backtitle "Breeze::OS $RELEASE Installer" \
		  --title "Breeze::OS $RELEASE -- Adsl/Cable Configuration" \
		  --mixedform "\nThe \Z1DNS\Zn \Zb\Z4primary\Zn and \Zb\Z4secondary\Zn IP addresses are optional; but, you must provide your \Zb\Z4username\Zn and \Zb\Z4password\Zn." 14 60 5 \
		  "Username:"      1 1 "$username" 1 16 45 0 0 \
		  "Primary DNS:"   2 1 "$primary" 2 16 45 0 0 \
		  "Secondary DNS:" 3 1 "$secondary" 3 16 45 0 0 \
		  "Password:"      4 1 "$password" 4 16 45 0 1 \
		  "Confirm:"       5 1 "$confirm" 5 16 45 0 1 2> $TMP/fields.txt

		if [ "$?" != 0 ]; then
			exit 1
		fi
	fi

	parse_fields $TMP/fields.txt

	if [ "$?" = 0 ]; then

		echo -n "$essid" 1> $TMP/selected-isp-essid
		echo -n "$wpa_mode" 1> $TMP/selected-isp-wpamode
		echo -n "$crypt_key" 1> $TMP/selected-isp-cryptkey
		echo -n "$key_mgmt" 1> $TMP/selected-isp-keymgmt
		echo -n "$nickname" 1> $TMP/selected-isp-nickname
		echo -n "$wifi_dns" 1> $TMP/selected-isp-wifidns
		echo -n "$wifi_addr" 1> $TMP/selected-isp-wifiaddr

		echo -n "$username" 1> $TMP/selected-isp-username
		echo -n "$password" 1> $TMP/selected-isp-password
		echo -n "$primary" 1> $TMP/selected-isp-primary
		echo -n "$secondary" 1> $TMP/selected-isp-secondary
		echo -n "$phone_nb" 1> $TMP/selected-isp-phone-nb
		echo -n "$area_code" 1> $TMP/selected-isp-area-code

#		if [ "$INTERNET" = "dialup" ]; then
#			echo "dialup\t&username=$username&password=$password&area-code=$area_code&phone-nb=$phone_nb" >> $ROOTDIR/post-config.log
#			break
#
#		elif [ "$INTERNET" = "adsl" ]; then
#			echo "adsl\t&username=$username&password=$password&primary=$primary&secondary=$secondary" >> $ROOTDIR/post-config.log
#			break
#
#		elif [ "$INTERNET" = "cable" ]; then
#			echo "cable\t&username=$username&password=$password&primary=$primary&secondary=$secondary" >> $ROOTDIR/post-config.log
#			break
#
#		elif [ "$INTERNET" = "wifi" ]; then
#			echo "wifi\t&wpa-mode=$wpa_mode&essid=$essid&cryptkey=$crypt_key&keymgmt=$key_mgmt&nickame=$nickname&wifi-addr=$wifi_addr&wifi-dns=$wifi_dns" >> $ROOTDIR/post-config.log
#			break
#		fi
		break
	fi
done

exit 0

# end Breeze::OS setup script
