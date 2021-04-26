#!/bin/bash
#
# GNU GENERAL PUBLIC LICENSE Version 3
#
# GNU GENERAL PUBLIC LICENSE Version 3
#
# Copyright 2016 Pierre Innocent, Tsert Inc., All Rights Reserved
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

. d-crypto-utils.sh

# Main starts here ...
DEVICE="$1"
ARGUMENT="$2"

if ! is_valid_device "$DEVICE" ; then
	echo "INSTALLER: FAILURE L_NO_DEVICE_SPECIFIED"
	exit 1
fi

DRIVE_ID="$(basename $1)"

SELECTED="$(cat $TMP/selected-drive 2> /dev/null)"

if [ -z "$SELECTED" -o "$SELECTED" != "$DEVICE" ]; then
	echo "INSTALLER: FAILURE L_NO_DEVICE_SPECIFIED"
	exit 1
fi

SELECTED="$(extract_value crypto 'device')"

if [ -z "$SELECTED" -o "$SELECTED" != "$DEVICE" ]; then
	echo "INSTALLER: FAILURE L_NO_DEVICE_SPECIFIED"
	exit 1
fi

CRYPTO="$(extract_value crypto 'type')"
CYPHER="$(extract_value crypto 'cipher')"
KEYFILE="$(extract_value crypto 'keyfile')"

cp -f $TMP/crypto.map $TMP/crypto-${DRIVE_ID}.map

echo "$CIPHER" 1> $TMP/selected-cipher
echo "$CRYPTO" 1> $TMP/selected-crypto

if [ "$CRYPTO" = "encfs" ]; then
	echo "INSTALLER: FAILURE L_CRYPTO_KEYS_CREATION_FAILED"
	exit 1
fi

PASSWORD="$(extract_value crypto 'password')"
CONFIRM="$(extract_value crypto 'confirm')"

if [ -z "$PASSWORD" -o -z "$CONFIRM" -o "$PASSWORD" != "$CONFIRM" ]; then
	echo "INSTALLER: FAILURE L_CRYPTO_KEYS_PASSWORD_MISSING"
	exit 1
fi

if [ "$KEYFILE" = "unique" ]; then
	if create_crypto_keyfile "$device" "$device" "master" ; then
		echo "INSTALLER: SUCCESS"
		exit 0
	fi
else
	echo "INSTALLER: SUCCESS"
	exit 0
fi

echo "INSTALLER: FAILURE L_CRYPTO_KEYS_CREATION_FAILED"
exit 1

# end Breeze::OS setup script
