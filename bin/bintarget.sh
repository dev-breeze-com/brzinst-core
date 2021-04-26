#!/bin/bash
#
# GNU GENERAL PUBLIC LICENSE Version 3
#
# Copyright 2016 Pierre Innocent, Tsert Inc. All rights reserved.
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

. d-format-utils.sh

. d-crypto-utils.sh

set_mountpoints()
{
	local target="$1"
	local drive_id="$2"
	local hdpath="$3"
	local drive_ssd="$(is_drive_ssd $target)"
	local schemefile=$TMP/mountpoints-${drive_id}.csv

	while read line; do

		local device="$(echo "$line" | cut -f1 -d',')"
		local mtpt="$(echo "$line" | cut -f2 -d',')"
		local fstype="$(echo "$line" | cut -f3 -d',')"
		local ptype="$(echo "$line" | cut -f4 -d',')"
		local mode="$(echo "$line" | cut -f5 -d',')"
		local crypto="$(echo "$line" | cut -f6 -d',')"
		local rawdevice="$(echo "$line" | cut -f7 -d',')"

		echo "INSTALLER: PROGRESS ((device,$device),(mountpoint,$mtpt),(filesystem,$fstype))"
		echo "INSTALLER: MESSAGE TIP_SETTING_MOUNTPOINTS((device,$device),(mountpoint,$mtpt),(filesystem,$fstype))"

		if [ "$mode" = "crypt" -a "$crypto" != "encfs" -a "$mtpt" != "/boot" ]; then
			write_crypto_conf "$target" "$rawdevice" "$device" "$mtpt" "$CRYPTO"
		fi
	done < $schemefile

	return 0
}

# Main starst here ...
if [ "${#ROOTDIR}" = 1 ]; then
	echo "INSTALLER: FAILURE L_INVALID_ROOTDIR"
	exit 1
fi

IDX=0
DEVICE="$1"
DRIVE_ID="$(basename $DEVICE)"
SELECTED="$(cat $TMP/selected-drive 2> /dev/null)"

if [ -z "$SELECTED" -o "$SELECTED" != "$DEVICE" ]; then
	echo "INSTALLER: FAILURE L_SCRIPT_MISMATCH_ON_DEVICE"
	exit 1
fi

SELECTED="$(extract_value scheme-${DRIVE_ID} 'device')"

if [ -z "$SELECTED" -o "$SELECTED" != "$DEVICE" ]; then
	echo "INSTALLER: FAILURE L_SCRIPT_MISMATCH_ON_DEVICE"
	exit 1
fi

TARGET="$DEVICE"
CRYPTO="$(extract_value "crypto-${DRIVE_ID}" 'crypt-type')"
DISK_TYPE="$(extract_value "scheme-${DRIVE_ID}" 'disk-type')"
ENCRYPTED="$(extract_value "scheme-${DRIVE_ID}" 'encrypted')"

if [ "$DISK_TYPE" = "lvm" ]; then
	SELECTED="$(get_lvm_master_drive $TARGET)"

	if [ "$SELECTED" != "$TARGET" ]; then
		echo "INSTALLER: FAILURE L_INVALID_TARGET_DRIVE"
		exit 1
	fi
fi

unlink $TMP/fstab 2> /dev/null
touch $TMP/fstab 2> /dev/null

printf "dmcrypt_key_timeout=1\ndmcrypt_retries=5\n\n" 1> $TMP/dmcrypt

unlink $TMP/crypttab 2> /dev/null
touch $TMP/crypttab 2> /dev/null

unlink $TMP/crypto-devices 2> /dev/null
touch $TMP/crypto-devices 2> /dev/null

unlink $TMP/umount.errs 2> /dev/null
touch $TMP/umount.errs 2> /dev/null

#if devtmpfs_enabled "$TARGET" ; then
cat <<EOT >> $TMP/fstab
proc      /proc       proc        defaults   0   0
sysfs     /sys        sysfs       defaults   0   0
devtmpfs  /dev        devtmpfs    remount,nosuid,mode=0755  0     0
tmpfs     /tmp        tmpfs       defaults,nodev,nosuid,mode=1777  0   0
tmpfs     /dev/shm    tmpfs       defaults,nodev,nosuid,mode=1777  0   0
devpts    /dev/pts    devpts      gid=5,mode=620   0   0
#tmpfs     /var/tmp    tmpfs       defaults,nodev,nosuid,mode=1777  0   0
EOT

set_mountpoints $TARGET $DRIVE_ID

add_fstab_cdrom "$TARGET"

if is_valid_target "$TARGET" ; then

	cat $TMP/fstab 1> $TMP/etc_fstab
	cat $TMP/dmcrypt 1> $TMP/etc_dmcrypt
	cat $TMP/crypttab 1> $TMP/etc_crypttab

	KEY="scheme-${DRIVE_ID}"
	SCHEME="$(extract_value $KEY 'scheme')"
	DISK_TYPE="$(extract_value $KEY 'disk-type')"
	ENCRYPTED="$(extract_value $KEY 'encrypted')"
	FSTYPE="$(extract_value $KEY 'fstype')"
	GPT_MODE="$(extract_value $KEY 'gpt-mode' 'upper')"
	BOOT_SIZE="$(extract_value $KEY 'boot-size')"
	SWAP_SIZE="$(extract_value $KEY 'swap-size')"
	SECTOR_SIZE="$(extract_value $KEY 'sector-size')"

	echo "$TARGET" 1> $TMP/selected-target
	echo "$TARGET" 1> $TMP/selected-drive
	echo "$TARGET" 1> $TMP/selected-boot-drive

	echo "$SCHEME" 1> $TMP/selected-scheme
	echo "$GPT_MODE" 1> $TMP/selected-gpt-mode
	echo "$DRIVE_ID" 1> $TMP/selected-drive-id
	echo "$DISK_TYPE" 1> $TMP/selected-disktype
	echo "$BOOT_SIZE" 1> $TMP/selected-boot-size
	echo "$SWAP_SIZE" 1> $TMP/selected-swap-size

	echo "INSTALLER: MESSAGE L_TARGET_DRIVE_SELECTED"
	sync; sleep 1

	echo "INSTALLER: SUCCESS"
	exit 0
fi

echo "INSTALLER: FAILURE"
exit 1

# end Breeze::OS setup script
