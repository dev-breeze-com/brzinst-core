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
. d-dirpaths.sh

HOSTNAME=$(cat $TMP/selected-hostname)
DERIVED="`cat $TMP/selected-derivative 2> /dev/null`"
RELEASE="`cat $TMP/selected-release 2> /dev/null`"

mkdir -p $ROOTDIR/etc/desktop/public-keys 2> /dev/null
mkdir -p $ROOTDIR/etc/desktop/certificates 2> /dev/null

parse_fields () {

	count=1
	complete=true

	while read f; do
		if [ "$f" = "" ]; then
			complete=false
		fi

		case $count in
			1) COUNTRY=$f ;;
			2) STATE_PROV=$f ;;
			3) CITY=$f ;;
			4) COMPANY=$f ;;
			5) DEPT=$f ;;
			6) TITLE=$f ;;
			7) EMAIL=$f ;;
		esac
		count=$(( $count + 1 ))
	done < $TMP/openssl.log

	if [ "$complete" = false ]; then
		return 1
	fi

	/bin/cp $BRZDIR/factory/openssl.cnf $TMP/openssl.cnf

	/bin/sed -i -e "s/%hostname%/$HOSTNAME/g" $TMP/openssl.cnf
	/bin/sed -i -e "s/%countryName%/$COUNTRY/g" $TMP/openssl.cnf
	/bin/sed -i -e "s/%stateOrProvinceName%/$STATE_PROV/g" $TMP/openssl.cnf
	/bin/sed -i -e "s/%localityName%/$CITY/g" $TMP/openssl.cnf
	/bin/sed -i -e "s/%organizationalName%/$COMPANY/g" $TMP/openssl.cnf
	/bin/sed -i -e "s/%organizationalUnitName%/$DEPT/g" $TMP/openssl.cnf
	/bin/sed -i -e "s/%commonName%/$TITLE/g" $TMP/openssl.cnf
	/bin/sed -i -e "s/%emailAddress%/$EMAIL/g" $TMP/openssl.cnf

	return 0
}

while [ 0 ]; do

	dialog --colors --ok-label "Submit" \
	  --backtitle "Breeze::OS $RELEASE Installer" \
	  --title "Breeze::OS $RELEASE -- Openssl Configuration" \
	  --form "\nDefault information for SSL configuration." 15 60 7 \
	  "Country:"    1 1 "$COUNTRY" 1 16 45 0 \
	  "State/Prov:" 2 1 "$STATE_PROV" 2 16 45 0 \
	  "City:"       3 1 "$CITY" 3 16 45 0 \
	  "Company:"    4 1 "$COMPANY" 4 16 45 0 \
	  "Department:" 5 1 "$DEPT" 5 16 45 0 \
	  "Full Name:"  6 1 "$TITLE" 6 16 45 0 \
	  "Email Address:"  7 1 "$EMAIL" 7 16 45 0 2> $TMP/openssl.log

	if [ "$?" != 0 ]; then
		break
	fi

	parse_fields $TMP/openssl.log

	if [ "$?" = 0 ]; then
		/bin/cp -f $TMP/openssl.cnf $ROOTDIR/etc/desktop/
		exit 0
	fi
done

exit 1

