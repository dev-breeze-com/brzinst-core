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
# d-nvc.sh network virtual club settings <dev@tsert.com>
#

# Initialize folder paths
. d-dirpaths.sh

FQDN=
USERNAME=
PASSWORD=

DERIVED="`cat $TMP/selected-derivative 2> /dev/null`"
RELEASE="`cat $TMP/selected-release 2> /dev/null`"

parse_fields () {

	count=1
	mismatch=false

	while read f; do
		case $count in
			1) echo -n $f 1> $TMP/selected-dyndns-fqdn
			   FQDN=$f ;;
			2) echo -n $f 1> $TMP/selected-dyndns-username
			   USERNAME=$f ;;
			3) echo -n $f 1> $TMP/selected-dyndns-password
			   PASSWORD=$f ;;
			4)
				if [ "$PASSWORD" != "$f" ]; then
					mismatch=true
				fi
		esac

		count=$(( $count + 1 ))

	done < $TMP/nvc.log

	if [ "$mismatch" = true ]; then
		dialog --colors --clear --ok-label "Submit" \
		  --backtitle "Breeze::OS $RELEASE Installer" \
		  --title "Breeze::OS $RELEASE -- Network Virtual Clubs" \
		  --msgbox "\nPasswords don't match !" 7 60 2> /dev/null
		return 1
	fi

	if [ "$FQDN" = "" -o "$USERNAME" = "" -o "$PASSWORD" = "" ]; then
		dialog --colors --clear --ok-label "Submit" \
		  --backtitle "Breeze::OS $RELEASE Installer" \
		  --title "Breeze::OS $RELEASE -- Network Virtual Clubs" \
		  --msgbox "\nYou must provide a Fully Qualified Domain Name" 7 60 2> /dev/null
		return 1
	fi

	/bin/cp -f $BRZDIR/factory/ddclient.conf $TMP/
	/bin/sed -i -e "s/%fqdn%/$FQDN/g" $TMP/ddclient.conf
	/bin/sed -i -e "s/%username%/$USERNAME/g" $TMP/ddclient.conf
	/bin/sed -i -e "s/%password%/$PASSWORD/g" $TMP/ddclient.conf

	return 0
}

while [ 0 ]; do

	dialog --colors --clear --insecure \
	  --ok-label "Submit" \
	  --backtitle "Breeze::OS $RELEASE Installer" \
	  --title "Breeze::OS $RELEASE -- Network Virtual Clubs" \
	  --mixedform "\nIf you use, or intend to use a dynamic DNS service.\nYou must enter a username and password to access the dynamic DNS service." 14 65 4 \
	  "Fully Qualified Domain Name: "  1 1 "$FQDN" 1 30 70 0 0 \
	  "Dynamic DNS Service Username: " 2 1 "$USERNAME" 2 30 70 0 0 \
	  "Dynamic DNS Service Password: " 3 1 "$PASSWORD" 3 30 70 0 1 \
	  "Dynamic DNS Password Confirm: " 4 1 "$CONFIRM" 4 30 70 0 1 2> $TMP/nvc.log

	if [ "$?" != 0 ]; then
		exit 1
	fi

	parse_fields $TMP/nvc.log

	if [ "$?" != 0 ]; then
		break
	fi
done

exit 0

