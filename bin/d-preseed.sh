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

key=""
value=""
group=""

invoke_script() {
	group="$1"

	if [ "$group" = "LOCALE" ]; then
	elif [ "$group" = "NETWORK" ]; then
	elif [ "$group" = "INTERNET" ]; then
	elif [ "$group" = "PARTITIONS" ]; then
	elif [ "$group" = "DYNDNS" ]; then
	elif [ "$group" = "DESKTOP" ]; then
	elif [ "$group" = "INDEXING" ]; then
	elif [ "$group" = "USERS" ]; then
	elif [ "$group" = "SSL" ]; then
	elif [ "$group" = "XORG" ]; then
	elif [ "$group" = "KERNEL" ]; then
	elif [ "$group" = "BOOT" ]; then
	fi
	return 0
}

while read line; do

	if [ "$(echo "$line" | grep -E '^$|^#|^//')" != "" ]; then
		continue
	fi

	if [ "$(echo "$line" | grep -E '^\[/')" != "" ]; then
		invoke_script $group
		group="$(dirname $group)"
		continue
	fi

	if [ "$(echo "$line" | grep -E '^\[')" != "" ]; then
		key="$(echo "$line" | cut -d '[' -f 1)"

		if [ "$group" = "" ]; then
			group="$key"
		else
			group="$group/$key"
		fi
		continue
	fi

	key="$(echo "$line" | cut -d '=' -f 1)"
	value="$(echo "$line" | cut -d '=' -f 2)"

	if [ "$group" = "LOCALE" ]; then
		if [ "$key" = "locale" ]; then
			echo "$value" 1> $TMP/selected-locale
		elif [ "$key" = "timezone" ]; then
			echo "$value" 1> $TMP/selected-timezone
		elif [ "$key" = "keyboard" ]; then
			echo "$value" 1> $TMP/selected-keyboard
		elif [ "$key" = "keymap" ]; then
			echo "$value" 1> $TMP/selected-keymap
		fi
	elif [ "$group" = "NETWORK" ]; then
		if [ "$key" = "locale" ]; then
			echo "$value" 1> $TMP/selected-locale
		elif [ "$key" = "timezone" ]; then
			echo "$value" 1> $TMP/selected-timezone
		elif [ "$key" = "keyboard" ]; then
			echo "$value" 1> $TMP/selected-keyboard
		elif [ "$key" = "keymap" ]; then
			echo "$value" 1> $TMP/selected-keymap
		fi
	elif [ "$group" = "INTERNET" ]; then
		if [ "$key" = "locale" ]; then
			echo "$value" 1> $TMP/selected-locale
		elif [ "$key" = "timezone" ]; then
			echo "$value" 1> $TMP/selected-timezone
		elif [ "$key" = "keyboard" ]; then
			echo "$value" 1> $TMP/selected-keyboard
		elif [ "$key" = "keymap" ]; then
			echo "$value" 1> $TMP/selected-keymap
		fi
	elif [ "$group" = "PARTITIONS" ]; then
		if [ "$key" = "locale" ]; then
			echo "$value" 1> $TMP/selected-locale
		elif [ "$key" = "timezone" ]; then
			echo "$value" 1> $TMP/selected-timezone
		elif [ "$key" = "keyboard" ]; then
			echo "$value" 1> $TMP/selected-keyboard
		elif [ "$key" = "keymap" ]; then
			echo "$value" 1> $TMP/selected-keymap
		fi
	elif [ "$group" = "DYNDNS" ]; then
		if [ "$key" = "locale" ]; then
			echo "$value" 1> $TMP/selected-locale
		elif [ "$key" = "timezone" ]; then
			echo "$value" 1> $TMP/selected-timezone
		elif [ "$key" = "keyboard" ]; then
			echo "$value" 1> $TMP/selected-keyboard
		elif [ "$key" = "keymap" ]; then
			echo "$value" 1> $TMP/selected-keymap
		fi
	elif [ "$group" = "DESKTOP" ]; then
	elif [ "$group" = "INDEXING" ]; then
	elif [ "$group" = "USERS" ]; then
	elif [ "$group" = "SSL" ]; then
	elif [ "$group" = "XORG" ]; then
	elif [ "$group" = "KERNEL" ]; then
	elif [ "$group" = "BOOT" ]; then
	fi
done < "$BRZDIR/factory/preseed.cfg"

ROUTER="$(cat $TMP/router-modem)"
HOSTNAME="$(cat $TMP/selected-hostname)"
DOMAIN="$(cat $TMP/selected-domain)"
COUNTRY="$(cat $TMP/selected-country)"
COUNTRY="$(echo $COUNTRY | /bin/sed 's/\//\\\//g')"
DESKTOP="$(cat $TMP/selected-desktop)"
DESKTOP="$(echo "$DESKTOP" | tr '[:upper:]' '[:lower:]')"
LOCALE="$(cat $TMP/selected-locale)"
GRUB_OTHER_OS="$(cat $TMP/grub-other-os)"
KEYMAP="$(cat $TMP/selected-keymap)"
KEYBOARD="$(cat $TMP/selected-keyboard)"
KEYBOARD="$(echo $KEYBOARD | /bin/sed 's/\//\\\//g')"
LAYOUT="$(cat $TMP/selected-keyboard-layout)"
LAYOUT="$(echo "$LAYOUT" | /bin/sed 's/\//\\\//g')"
TIMEZONE="$(cat $TMP/selected-timezone)"
TIMEZONE="$(echo "$TIMEZONE" | /bin/sed 's/\//\\\//g')"
TZ_AREA="$(cat $TMP/selected-timezone-area)"
TZ_AREA="$(echo "$TZ_AREA" | tr '[:upper:]' '[:lower:]')"
USER="$(cat $TMP/selected-isp-username)"
PASSWORD="$(cat $TMP/selected-isp-password)"
PASSWORD="$(echo "$PASSWORD" | /bin/sed 's/\//\\\//g')"
PASSWORD="$(echo "$PASSWORD" | /bin/sed 's/\-/\\-/g')"
PHONE="$(cat $TMP/selected-isp-phone-nb)"
FQDN="$(cat $TMP/selected-dyndns-fqdn)"
USER="$(cat $TMP/selected-dyndns-username)"
PASSWORD="$(cat $TMP/selected-dyndns-password)"
PASSWORD="$(echo $PASSWORD | /bin/sed 's/\//\\\//g')"
PASSWORD="$(echo $PASSWORD | /bin/sed 's/\-/\\-/g')"
USER="$(cat $TMP/selected-username)"
FULLNAME="$(cat $TMP/selected-full-name)"
PASSWORD="$(cat $TMP/selected-password)"
PASSWORD="$(echo $PASSWORD | /bin/sed 's/\//\\\//g')"
PASSWORD="$(echo $PASSWORD | /bin/sed 's/\-/\\-/g')"
GRUB_DISK_ID="$(cat $TMP/selected-drive)"
GRUB_DISK_ID="$(echo $GRUB_DISK_ID | /bin/sed 's/\//\\\//g')"
DISK_TYPE="$(cat $TMP/selected-disktype)"
KEYMAP="$(cat $TMP/selected-keymap)"
KEYMAP="$(echo $KEYMAP | /bin/sed 's/\.map//g')"
KEYMAP="$(grep -E "$KEYMAP[:\t]" $BRZDIR/factory/console-keymaps.txt)"
KEYMAP="$(echo "$KEYMAP" | /bin/sed 's/.*[ \t]//g')"
KEYMAP="$(echo $KEYMAP | /bin/sed 's/\//\\\//g')"
KEYMAP="$(echo $KEYMAP | /bin/sed 's/\-/\\-/g')"
USB_KEYMAP="$(grep -E "$KEYMAP[:\t]" $BRZDIR/factory/usb-keymaps.txt)"
QWERTY_KEYMAP="$(grep -E "$KEYMAP[:\t]" $BRZDIR/factory/qwerty-keymaps.txt)"
XKB_KEYMAP="$(grep -E "$KEYMAP[:\t]" $BRZDIR/factory/xkb-keymaps.txt)"

# end Breeze::OS script
