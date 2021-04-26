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

# end Breeze::OS setup script

isa_gpt_drive() {
	if fdisk -l ${1} | grep -iqF 'Disk label type: gpt' ; then
		return 0
	fi
	return 1
}

set_drive_settings() {

	local device="$1"
	local disksz="$2"
	local ssd="$(is_drive_ssd $device)"
	local memsize="$(probe_memory real $PLATFORM)"

	SWAP_SIZE=1024
	DISK_TYPE="normal"

	lsblk -d -n -o 'model,vendor,rev' "$device" | \
		sed -r 's/[\t ][\t ]*/ /g' 1> $TMP/selected-drive-model

	if test $memsize -lt 512; then
		SWAP_SIZE=1024
	elif test $memsize -lt 750; then
		SWAP_SIZE=2048
	elif test $memsize -lt 1000; then
		SWAP_SIZE=4096
	elif test $memsize -lt 4000; then
		SWAP_SIZE=5120
	else
		SWAP_SIZE=$(( $memsize ))
	fi

	if test $disksz -lt 5000; then
		SWAP_SIZE=256
	elif test $disksz -lt 10000; then
		SWAP_SIZE=512
	elif test $disksz -lt 20000; then
		SWAP_SIZE=1024
	fi

	GPT_MODE="mbr"
	BOOT_SIZE="256"
	SECTOR_SIZE="$(get_sector_size)"

	if test $disksz -ge 750000; then
		RESERVED="0"
		SCHEME="root-share"
		BOOT_SIZE="1024"
		GPT_MODE="gpt"

	elif test $disksz -ge 500000; then
		RESERVED="1"
		SCHEME="root-opt"
		BOOT_SIZE="512"
		GPT_MODE="gpt"

	elif test $disksz -ge 250000; then
		RESERVED="2"
		SCHEME="root-srv"

	elif test $disksz -ge 150000; then
		RESERVED="2"
		SCHEME="root-var"
	else
		SCHEME="root-home"
		RESERVED="5"
	fi

	if [ "$ssd" = "yes" ]; then
		GPT_MODE="gpt"
		SECTOR_SIZE="4k"
	fi

	if isa_gpt_drive $device ; then
		GPT_MODE="gpt"
	fi
	return 0
}

keep_home() {

	OUTPUT_SCHEME=$TMP/partitions-${DRIVE_ID}.csv
	unlink "$OUTPUT_SCHEME" 2> /dev/null
	touch "$OUTPUT_SCHEME" 2> /dev/null

	unlink $TMP/kepthome-${DRIVE_ID}.csv
	touch $TMP/kepthome-${DRIVE_ID}.csv

	while read line; do

		mtpt="$(echo "$line" | cut -f5 -d',')"

		if [ "$mtpt" = "/home" ]; then
			line="$(echo "$line" | sed -r 's/ignore/keep/g')"
		fi

		echo "$line" >> $OUTPUT_SCHEME
		echo "$line" >> $TMP/kepthome-${DRIVE_ID}.csv

	done < $TMP/kepthome.csv

	return 0
}

# Main starts here ...
DEVICE="$1"

if is_valid_device "$DEVICE" ; then
	DRIVE_ID="$(basename $1)"
	unlink $TMP/${DRIVE_ID}-kepthome 2> /dev/null
	#echo "yes" 1> $TMP/${DRIVE_ID}-kepthome
else
	echo "INSTALLER: FAILURE L_NO_DRIVE_SELECTED"
	exit 1
fi

DISK_SIZE="$(get_drive_size $DEVICE)"
echo "$DISK_SIZE" 1> $TMP/drive-total
echo "$DISK_SIZE" 1> $TMP/${DRIVE_ID}-drive-total

set_drive_settings $DEVICE $DISK_SIZE

#keep_home $DEVICE

if [ "$GPT_MODE" = "gpt" -o "$GPT_MODE" = "uefi" ]; then
	echo "$DEVICE=GPT Partitioned" >> $TMP/gpt-mbr-drives
else
	echo "$DEVICE=MBR Partitioned" >> $TMP/gpt-mbr-drives
fi

if [ ! -e $TMP/scheme-${DRIVE_ID}.map ]; then

	#-e "s/@DEVICE@/$DEVICE/g" \
	cat $BRZDIR/factory/scheme.map  | sed \
		-e "s/@MODE@/$GPT_MODE/g" \
		-e "s/@TYPE@/$DISK_TYPE/g" \
		-e "s/@BOOT@/$BOOT_SIZE/g" \
		-e "s/@SWAP@/$SWAP_SIZE/g" \
		-e "s/@SECTORS@/$SECTOR_SIZE/g" \
		-e "s/@SIZE@/$DISK_SIZE/g" \
		-e "s/@SCHEME@/$SCHEME/g" \
		-e "s/@RESERVED@/$RESERVED/g" \
	1> "$TMP/scheme-${DRIVE_ID}.map"
fi

echo "INSTALLER: SUCCESS"
exit 0

# end Breeze::OS setup script
