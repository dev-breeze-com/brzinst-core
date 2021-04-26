#!/bin/bash
#
# GNU GENERAL PUBLIC LICENSE -- Version 3
#
# Copyright 2013 Pierre Innocent, Tsert Inc. All rights reserved.
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

mkdir -p $ROOTDIR/etc/desktop/keyring/public 2> /dev/null
mkdir -p $ROOTDIR/etc/desktop/keyring/private 2> /dev/null
mkdir -p $ROOTDIR/etc/desktop/certificates 2> /dev/null

DERIVED="$(cat $TMP/selected-derivative 2> /dev/null)"
HOSTNAME="$(cat $TMP/selected-hostname 2> /dev/null)"

COUNTRY="$(extract_value 'openssl' 'country')"
STATE_PROV="$(extract_value 'openssl' 'state-prov')"
CITY="$(extract_value 'openssl' 'city')"
COMPANY="$(extract_value 'openssl' 'company')"
DEPT="$(extract_value 'openssl' 'department')"
TITLE="$(extract_value 'openssl' 'full-name')"
EMAIL="$(extract_value 'openssl' 'email')"

/bin/cp ./install/factory/$DERIVED/openssl.cnf $TMP/openssl.cnf

/bin/sed -i -e "s/%hostname%/$HOSTNAME/g" $TMP/openssl.cnf
/bin/sed -i -e "s/%countryName%/$COUNTRY/g" $TMP/openssl.cnf
/bin/sed -i -e "s/%stateOrProvinceName%/$STATE_PROV/g" $TMP/openssl.cnf
/bin/sed -i -e "s/%localityName%/$CITY/g" $TMP/openssl.cnf
/bin/sed -i -e "s/%organizationalName%/$COMPANY/g" $TMP/openssl.cnf
/bin/sed -i -e "s/%organizationalUnitName%/$DEPT/g" $TMP/openssl.cnf
/bin/sed -i -e "s/%commonName%/$TITLE/g" $TMP/openssl.cnf
/bin/sed -i -e "s/%emailAddress%/$EMAIL/g" $TMP/openssl.cnf

exit 0

# end Breeze::OS setup script
