#!/bin/bash
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
CRYPTARG="$2"

if ! is_valid_device "$DEVICE" ; then
    echo_failure "L_NO_DEVICE_SPECIFIED"
    exit 1
fi

DRIVE_ID="$(basename $DEVICE)"

SELECTED="$(cat $TMP/selected-drive 2> /dev/null)"

if [ -z "$SELECTED" -o "$SELECTED" != "$DEVICE" ]; then
    echo_failure "L_NO_DEVICE_SPECIFIED"
    exit 1
fi

if ! is_safemode_drive "$DEVICE" ; then
    echo_error "L_SAFEMODE_DRIVE_SELECTED !"
    exit 1
fi

EXPERTISE="$(cat $TMP/selected-expertise 2> /dev/null)"

if [ "$CRYPTARG" = "beginner" -a "$EXPERTISE" = "beginner" ]; then

    CONFIRM="$(extract_value crypto 'confirm')"
    PASSWORD="$(extract_value crypto 'password')"

    cat ${BRZDIR}/templates/crypto.tpl | sed \
        -e "s/@TYPE@/luks/g" \
        -e "s/@DEVICE@/\/dev\/$DRIVE_ID/g" \
        -e "s/@CIPHER@/default/g" \
        -e "s/@BLOCK_MODE@/plain64/g" \
        -e "s/@CRYPTO_MODE@/master/g" \
        -e "s/@HASH@/sha256/g" \
        -e "s/@ERASURE@/none/g" \
        -e "s/@KEYFILE@/unique/g" \
        -e "s/@PASSWORD@/$PASSWORD/g" \
        -e "s/@CONFIRM@/$CONFIRM/g" \
    1> $TMP/crypto.map
fi

SELECTED="$(extract_value crypto 'device')"

if [ -z "$SELECTED" -o "$SELECTED" != "$DEVICE" ]; then
    echo_failure "L_NO_DEVICE_SPECIFIED"
    exit 1
fi

CRYPTO="$(extract_value crypto 'type')"
CYPHER="$(extract_value crypto 'cipher')"
KEYFILE="$(extract_value crypto 'keyfile')"
PASSWORD="$(extract_value crypto 'password')"
CONFIRM="$(extract_value crypto 'confirm')"

cp -f $TMP/crypto.map $TMP/crypto-${DRIVE_ID}.map

echo "$CIPHER" 1> $TMP/selected-cipher
echo "$CRYPTO" 1> $TMP/selected-crypto

if [ "$CRYPTO" = "encfs" ]; then
    echo_failure "L_CRYPTO_KEYS_CREATION_FAILED"
    exit 1
fi

if [ -z "$PASSWORD" -o -z "$CONFIRM" -o "$PASSWORD" != "$CONFIRM" ]; then
    echo_failure "L_CRYPTO_KEYS_PASSWORD_MISSING"
    exit 1
fi

if [ "$KEYFILE" = "unique" ]; then
    if ! create_crypto_keyfile "$DEVICE" "$DEVICE" "master" ; then
        echo_failure "L_CRYPTO_KEYS_CREATION_FAILED"
        exit 1
    fi
fi

echo "INSTALLER: SUCCESS"
exit 0

# end Breeze::OS setup script
