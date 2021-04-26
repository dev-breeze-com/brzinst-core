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
#
. d-dirpaths.sh

. d-format-utils.sh

# Main starts here ...
DEVICE="$1"
SCHEME="$2"
ARG="$3"

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

if [ "$ARG" != "beginner" -o "$EXPERTISE" != "beginner" ]; then
    echo_failure "L_INVALID_EXPERTISE_LEVEL"
    exit 1
fi

SELECTED="$(extract_value scheme-${DRIVE_ID} 'device')"

if [ -z "$SELECTED" -o "$SELECTED" != "$DEVICE" ]; then
    echo_failure "L_SCRIPT_MISMATCH_ON_DEVICE"
    exit 1
fi

DISK_TYPE="$(extract_value scheme-${DRIVE_ID} 'disk-type')"

if [ "$DISK_TYPE" = "lvm" ]; then
    echo_failure "L_NO_LVM_IN_BEGINNER_LEVEL"
    exit 1
fi

ENCRYPTED="$(extract_value scheme-${DRIVE_ID} 'encrypted')"
FSTYPE="$(extract_value scheme-${DRIVE_ID} 'fstype')"
GPT_MODE="$(extract_value scheme-${DRIVE_ID} 'gpt-mode' 'upper')"
BOOT_SIZE="$(extract_value scheme-${DRIVE_ID} 'boot-size')"
SWAP_SIZE="$(extract_value scheme-${DRIVE_ID} 'swap-size')"
SECTOR_SIZE="$(extract_value scheme-${DRIVE_ID} 'sector-size')"
RESERVED="$(extract_value scheme-${DRIVE_ID} 'reserved')"

echo "none" 1> $TMP/selected-crypto

if echo "$SCHEME" | egrep -q '[-](crypto|luks)' ; then
    echo "luks" 1> $TMP/selected-crypto
    SCHEME="$(echo "$SCHEME" | sed -r -e 's/[-](crypto|luks)[ ]*$//g')"
    ENCRYPTED="yes"
fi

echo "$SCHEME" 1> $TMP/selected-scheme

if [ -e $TMP/scheme-${DRIVE_ID}.map ]; then
    DISK_SIZE="$(extract_value scheme-${DRIVE_ID} 'disk-size')"
fi

cat ${BRZDIR}/templates/scheme.tpl | sed \
    -e "s/@DEVICE@/\/dev\/$DRIVE_ID/g" \
    -e "s/@FSTYPE@/$FSTYPE/g" \
    -e "s/@SCHEME@/$SCHEME/g" \
    -e "s/@GPT_MODE@/$GPT_MODE/g" \
    -e "s/@DISK_TYPE@/$DISK_TYPE/g" \
    -e "s/@DISK_SIZE@/$DISK_SIZE/g" \
    -e "s/@BOOT_SIZE@/$BOOT_SIZE/g" \
    -e "s/@SWAP_SIZE@/$SWAP_SIZE/g" \
    -e "s/@SECTOR_SIZE@/$SECTOR_SIZE/g" \
    -e "s/@ENCRYPTED@/$ENCRYPTED/g" \
    -e "s/@RESERVED@/$RESERVED/g" \
1> $TMP/scheme.map

exec d-create-scheme.sh "$DEVICE" "none"

# end Breeze::OS setup script
