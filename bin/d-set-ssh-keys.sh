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

VALUES="$1"

if [ "$1" = "openssl" -o "$1" = "uefi" ]; then
	SSHKEYS=$TMP/${1}.cnf
else
	echo "INSTALLER: FAILURE"
	exit 1
fi

HOSTNAME="$(cat $TMP/selected-hostname 2> /dev/null)"
DERIVED="$(cat $TMP/selected-derivative 2> /dev/null)"

COUNTRY="$(extract_value $VALUES 'country')"
STATE_PROV="$(extract_value $VALUES 'state-prov')"
CITY="$(extract_value $VALUES 'city')"
COMPANY="$(extract_value $VALUES 'company')"
DEPT="$(extract_value $VALUES 'dept')"
TITLE="$(extract_value $VALUES 'title')"
EMAIL="$(extract_value $VALUES 'email')"
LIFEFSPAN="$(extract_value $VALUES 'lifespan')"

cp $BRZDIR/factory/openssl.cnf ${SSHKEYS}

sed -i -r "s/%hostname%/$HOSTNAME/g" ${SSHKEYS}
sed -i -r "s/%countryName%/$COUNTRY/g" ${SSHKEYS}
sed -i -r "s/%stateOrProvinceName%/$STATE_PROV/g" ${SSHKEYS}
sed -i -r "s/%localityName%/$CITY/g" ${SSHKEYS}
sed -i -r "s/%organizationalName%/$COMPANY/g" ${SSHKEYS}
sed -i -r "s/%organizationalUnitName%/$DEPT/g" ${SSHKEYS}
sed -i -r "s/%commonName%/$TITLE/g" ${SSHKEYS}
sed -i -r "s/%emailAddress%/$EMAIL/g" ${SSHKEYS}
sed -i -r "s/%lifespan%/$LIFESPAN/g" ${SSHKEYS}

if [ "$1" = "openssl" ]; then
	if [ ! -e "$TMP/uefi.map" ]; then
		cp $TMP/openssl.map $TMP/uefi.map
	fi
fi

echo "INSTALLER: SUCCESS"
exit 0

# end Breeze::OS setup script
