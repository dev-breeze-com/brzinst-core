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
#
. d-dirpaths.sh

. d-crypt-utils.sh

create_keyfile() {

	dd if=/dev/urandom bs=512 count=4 | \
		gpg -v --cipher-algo aes256 --digest-algo sha512 \
		-c -a > $TMP/${1}-keyfile.gpg

	#dd if=/dev/urandom bs=512 count=4 of=$TMP/${1}-keyfile
	return $?
}

setup_crypto() {

	local luks_fs=""

	while read line; do

		local device="$(echo "$line" | cut -f 1 -d ',')"
		local ptype="$(echo "$line" | cut -f 2 -d ',')"
		local fstype="$(echo "$line" | cut -f 4 -d ',')"
		local mtpt="$(echo "$line" | cut -f 5 -d ',')"
		local mode="$(echo "$line" | cut -f 6 -d ',')"

		local devid="$(basename "$mtpt")"
		local cryptodev="luks_${devid}"

		if [ "${#ptype}" = 2 ]; then ptype="${ptype}00"; fi

		if [ "$mode" != "crypt" ]; then
			continue
		fi

		if [ "$ptype" = "8500" -o "$ptype" = "85" ]; then
			continue
		elif [ "$ptype" = "EFI" -o "$ptype" = "UEFI" ]; then
			continue
		elif [ "$ptype" = "BBP" ]; then
			continue
		fi

		if [ "$mtpt" = "/" ]; then
			cryptodev="luks_root"
		elif [ "$fstype" = "SWAP" ]; then
			cryptodev="luks_swap"
		fi

		echo "INSTALLER: PROGRESS ((device,$device),(mountpoint,$mtpt),(filesystem,$fstype))"

		if [ "$ONE_CRYPTO_KEY" = "yes" ]; then
			keyfile="$TMP/luks-uniq-keyfile.gpg"
		elif create_keyfile $cryptodev ; then
			keyfile="$TMP/$cryptodev-keyfile.gpg"
		else
			echo "INSTALLER: FAILURE L_CREATING_KEYFILE_FAILED"
			exit 1
		fi

		sync
		#cryptsetup -y -v luksFormat $device
		gpg -q -d $keyfile 2> /dev/null | \
			cryptsetup -v -–key-file=- -c aes-cbc-essiv:sha256 -s 256 \
			-h whirlpool luksFormat $device

		if [ "$?" != 0 ]; then
			echo "INSTALLER: FAILURE L_CRYPTO_DEVICE_CREATION"
			exit 1
		fi

		sync
		#cryptsetup open $device $cryptodev
		gpg -q -d $keyfile 2> /dev/null | \
			cryptsetup -v –-key-file=- luksOpen $device $cryptodev

		if [ "$?" != 0 ]; then
			echo "INSTALLER: FAILURE L_CRYPTO_DEVICE_CREATION"
			exit 1
		fi

		sync
		cryptsetup close $cryptodev

		if [ -z "$luks_fs" ]; then
			luks_fs="$device"
		else
			luks_fs="$luks_fs:$device"
		fi
	done < "$OUTPUT_SCHEME"

	echo "$luks_fs" > $TMP/luks-devices
	sync

	return 0
}

# Main starts here ...
SELECTED_DRIVE="$1"

DRIVE_ID="$(basename $SELECTED_DRIVE)"
DRIVE_TOTAL="$(cat $TMP/drive-total 2> /dev/null)"
SELECTED_SCHEME="$(cat $TMP/selected-scheme 2> /dev/null)"

if ! check_settings_file "scheme-${DRIVE_ID}" ; then
	echo "INSTALLER: FAILURE L_MISSING_SCHEME_FILE"
	exit 1
fi

DISK_TYPE="$(extract_value scheme-${DRIVE_ID} 'disk-type')"
ONE_CRYPTO_KEY="$(extract_value scheme-${DRIVE_ID} 'cryptokey-unique')"
OUTPUT_SCHEME="$TMP/new-partitions-${DRIVE_ID}.csv"

if [ -z "$DRIVE_TOTAL" -o -z "$DRIVE_ID" -o \
	-z "$SELECTED_DRIVE" -o -z "$SELECTED_SCHEME" ]; then
	echo "INSTALLER: FAILURE L_MISSING_DRIVE_NAME"
	exit 1
fi

if [ "$DISK_TYPE" != "crypto" -a "$DISK_TYPE" != "lvm-crypto" ]; then
	echo "INSTALLER: FAILURE L_NO_CRYPTO_SELECTED"
	exit 1
fi

if [ "$ONE_CRYPTO_KEY" = "yes" ]; then
	if ! create_keyfile "luks-uniq" ; then
		echo "INSTALLER: FAILURE L_CREATING_KEYFILE_FAILED"
		exit 1
	fi
fi

if ! setup_crypto ; then
	echo "INSTALLER: FAILURE L_CREATING_KEYFILE_FAILED"
	exit 1
fi

echo "INSTALLER: SUCCESS"
exit 0

# end Breeze::OS setup script
