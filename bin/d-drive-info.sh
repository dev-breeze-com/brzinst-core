#!/bin/bash
#
# GNU GENERAL PUBLIC LICENSE Version 3
#
# Copyright 2015 Pierre Innocent, Tsert Inc., All Rights Reserved
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

	if [ "$DISK_TYPE" = "freebsd" ]; then
		camcontrol devlist
	else
		DISK_TYPE="linux"
	fi

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
	elif test $disksz -lt 20000; then
		SWAP_SIZE=512
    elif test $disksz -lt 35000; then
		SWAP_SIZE=768
	elif test $disksz -lt 50000; then
		SWAP_SIZE=1024
	fi

	GPT_MODE="gpt"
	BOOT_SIZE="256"
	SECTOR_SIZE="$(get_sector_size $device)"

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
		RESERVED="2"
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

create_disk_log() {

	local DEVICE="$1"
	local FDISK_USED=false

	local mtpt=""
	local ptype=""
	local fstype=""
	local device=""

	local part_sz=""
	local end_sector=""
	local start_sector=""
	local nb_blocks=""
	local nb_sectors=""

	sgdisk -p $DEVICE 1> $TMP/${DRIVE_ID}.log

	grep -E '^[ ]+[0-9]+[ ]' $TMP/${DRIVE_ID}.log 1> $TMP/sgdisk.log

	if [ ! -s $TMP/sgdisk.log ]; then
		fdisk -l $DEVICE | grep -E '^/dev/' 1> $TMP/sgdisk.log
		echo "yes" 1> $TMP/fdisk-used
		FDISK_USED=true
	fi

	sed -r -i "s/^[\t ]*//g" $TMP/sgdisk.log
	sed -r -i "s/[\t ][\t *]*/ /g" $TMP/sgdisk.log

	IDX=0

	while read line; do

		line="$(echo "$line" | crunch)"

		if [ "$FDISK_USED" = true ]; then

			IDX=$(( $IDX + 1 ))

			device="$(echo "$line" | cut -f1 -d ' ')"
			start_sector="$(echo "$line" | cut -f2 -d ' ')"
			end_sector="$(echo "$line" | cut -f3 -d ' ')"
			nb_blocks="$(echo "$line" | cut -f4 -d ' ')"
			nb_blocks="$(echo "$nb_blocks" | sed -r 's/[+]//g')"

			part_sz=$(( $nb_blocks / 1000 ))

			ptype="$(echo "$line" | cut -f5 -d ' ')"
			ptype="$(echo "$ptype" | tr '[:lower:]' '[:upper:]')"
		else
			IDX="$(echo "$line" | cut -f1 -d ' ')"

			device="${DEVICE}$IDX"

			start_sector="$(echo "$line" | cut -f2 -d ' ')"
			end_sector="$(echo "$line" | cut -f3 -d ' ')"
			nb_sectors=$(( $end_sector - $start_sector ))

			part_sz="$(echo "$line" | cut -f4-5 -d ' ')"

			if echo "$part_sz" | grep -qF 'MiB' ; then
				part_sz="$(echo "$part_sz" | sed -r 's/[.][0-9 ]*MiB//g')"

			elif echo "$part_sz" | grep -qF 'GiB' ; then
				part_sz="$(echo "$part_sz" | sed -r 's/[ ]*GiB//g')"
				part_sz="$(echo "$part_sz" | sed -r 's/[.][0-9]*//g')"
				part_sz="${part_sz}000"

			elif echo "$part_sz" | grep -qF 'TiB' ; then
				part_sz="$(echo "$part_sz" | sed -r 's/[ ]*TiB//g')"
				part_sz="$(echo "$part_sz" | sed -r 's/[.][0-9]*//g')"
				part_sz="${part_sz}000000"

			elif echo "$part_sz" | grep -qF 'KiB' ; then
				part_sz="$(echo "$part_sz" | sed -r 's/[ ]*TiB//g')"
				part_sz="$(echo "$part_sz" | sed -r 's/[.][0-9]*//g')"
				part_sz="1"
			else
				part_sz="0"
			fi
			ptype="$(echo "$line" | cut -f6 -d ' ')"
			ptype="$(echo "$ptype" | tr '[:lower:]' '[:upper:]')"
		fi

		local psize=$part_sz
		#typeset -i psize

		fstype="$(lsblk -n -l -o 'fstype' $device | tr -s '\n' ' ' | crunch)"
		mtpt="$(lsblk -n -l -o 'mountpoint' $device | tr -s '\n' ' ' | crunch)"

		if echo "$fstype" | grep -q -F lvm ; then
			ptype="8E00"
			fstype="lvm2"
			mtpt="$(echo "$mtpt" | grep -m1 -v -F lvm)"
		fi

		fstype="$(echo "$fstype" | cut -f1 -d' ' | crunch)"
		mtpt="$(echo "$mtpt" | cut -f1 -d' ' | crunch)"
		mtpt="$(echo "$mtpt" | sed -e 's/\/target//g')"

		if [ -z "$fstype" ]; then fstype="unknown"; fi

		if [ "$ptype" = "B" -o "$ptype" = "C" -o "$ptype" = "E" -o "$ptype" = "F" ]; then
			mtpt="vfat,/windows,format"
		elif [ "$ptype" = "EF00" -o "$ptype" = "EF" ]; then
			mtpt="vfat,/boot/efi,format"
		elif [ "$ptype" = "EE00" -o "$ptype" = "EE" ]; then
			mtpt="$fstype,/gpt,format"
		elif [ "$ptype" = "EF01" ]; then
			mtpt="$fstype,/boot,format"
		elif [ "$ptype" = "EF02" ]; then
			mtpt="bios,/bios,ignore"
		elif [ "$ptype" = "8200" -o "$ptype" = "82" ]; then
			mtpt="swap,/swap,format"
		elif [ "$ptype" = "8300" -o "$ptype" = "83" ]; then

			if [ -z "$mtpt" -a 250 -eq "$psize" -a "$IDX" -eq 1 ]; then
				mtpt="$fstype,/boot,format"
			elif [ -z "$mtpt" -a 2 -eq "$psize" -a "$IDX" -eq 2 ]; then
				ptype="EF02"
				fstype="bios"
				mtpt="bios,/bios,ignore"
			else
				mtpt="$fstype,$mtpt,format"
			fi
		elif [ "$ptype" = "8E00" -o "$ptype" = "8E" ]; then
			mtpt="lvm,$mtpt,format"
			echo "lvm" 1> $TMP/selected-disktype
			DISK_TYPE="lvm"
		elif [ "$ptype" = "FD00" -o "$ptype" = "FD" ]; then
			mtpt="raid,$mtpt,format"
			echo "raid" 1> $TMP/selected-disktype
			DISK_TYPE="raid"
		elif [ "$ptype" = "8500" -o "$ptype" = "85" -o "$ptype" = "5" ]; then
			mtpt="extended,/none,ignore"
		elif [ 10 -gt "$psize" ]; then
			mtpt="unknown,/none,format"
		else
			mtpt="$fstype,$mtpt,format"
		fi

		echo "$device,$ptype,$part_sz,$mtpt" >> $DRIVE_INFO
		echo "$device,$start_sector,$end_sector,$nb_sectors" >> $OUTPUT_SECTORS

	done < "$TMP/sgdisk.log"

	if [ -s $DRIVE_INFO ]; then
		if grep -q -m1 -F '/efi,' $DRIVE_INFO ; then
			GPT_MODE="uefi"
		elif grep -q -m1 -F ',EE' $DRIVE_INFO ; then
			GPT_MODE="gpt"
		fi
	fi

	return 0
}

# Main starts here ...
DEVICE="$1"

if is_valid_device "$DEVICE" ; then
	echo "INSTALLER: FAILURE L_NO_DRIVE_SELECTED"
	exit 1
fi

DRIVE_ID="$(basename $1)"
DRIVE_INFO="$TMP/partitions-${DRIVE_ID}.csv"
OUTPUT_SECTORS="$TMP/sectors-${DRIVE_ID}.csv"

unlink $TMP/keepdrive.csv 2> /dev/null
unlink $TMP/${DRIVE_ID}-kepthome 2> /dev/null

rm -f "$DRIVE_INFO" "$OUTPUT_SECTORS"
touch "$DRIVE_INFO" "$OUTPUT_SECTORS"

DISK_SIZE="$(get_drive_size $DEVICE)"
echo "$DISK_SIZE" 1> $TMP/drive-total
echo "$DISK_SIZE" 1> $TMP/${DRIVE_ID}-drive-total

set_drive_settings $DEVICE $DISK_SIZE

set_drive_mode "$DEVICE"

create_disk_log "$DEVICE"

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

wc -l "$DRIVE_INFO" | cut -f1 -d' ' 1> $TMP/nb-${DRIVE_ID}-partitions
cp -f "$DRIVE_INFO" "$TMP/drive-info-${DRIVE_ID}.csv"

cat "$DRIVE_INFO"
sync; sleep 1

exit 0

# end Breeze::OS setup script
