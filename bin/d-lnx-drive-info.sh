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

create_disk_log() {

	local bootsz=""
	local device=""
	local DEVICE="$1"
	local FDISK_USED=false

	local part_sz=""
	local end_sector=""
	local start_sector=""
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

		line="`echo "$line" | crunch`"

		if [ "$FDISK_USED" = true ]; then

			IDX=$(( $IDX + 1 ))

			device="`echo "$line" | cut -f1 -d ' '`"
			start_sector="`echo "$line" | cut -f2 -d ' '`"
			end_sector="`echo "$line" | cut -f3 -d ' '`"
			nb_blocks="`echo "$line" | cut -f4 -d ' '`"
			nb_blocks="`echo "$nb_blocks" | sed 's/[+]//g'`"

			part_sz=$(( $nb_blocks / 1000 ))

			ptype="`echo "$line" | cut -f5 -d ' '`"
			ptype="`echo "$ptype" | tr '[:lower:]' '[:upper:]'`"
		else
			IDX="`echo "$line" | cut -f1 -d ' '`"

			device="${DEVICE}$IDX"

			start_sector="`echo "$line" | cut -f2 -d ' '`"
			end_sector="`echo "$line" | cut -f3 -d ' '`"
			nb_sectors=$(( $end_sector - $start_sector ))

			part_sz="`echo "$line" | cut -f4-5 -d ' '`"

			if echo "$part_sz" | grep -qF 'MiB' ; then
				part_sz="`echo "$part_sz" | sed 's/[.][0-9 ]*MiB//g'`"

			elif echo "$part_sz" | grep -qF 'GiB' ; then
				part_sz="`echo "$part_sz" | sed 's/[ ]*GiB//g'`"
				part_sz="`echo "$part_sz" | sed 's/[.][0-9]*//g'`"
				part_sz="${part_sz}000"

			elif echo "$part_sz" | grep -qF 'TiB' ; then
				part_sz="`echo "$part_sz" | sed 's/[ ]*TiB//g'`"
				part_sz="`echo "$part_sz" | sed 's/[.][0-9]*//g'`"
				part_sz="${part_sz}000000"

			elif echo "$part_sz" | grep -qF 'KiB' ; then
				part_sz="`echo "$part_sz" | sed 's/[ ]*TiB//g'`"
				part_sz="`echo "$part_sz" | sed 's/[.][0-9]*//g'`"
				part_sz="1"
			else
				part_sz="0"
			fi
			ptype="`echo "$line" | cut -f6 -d ' '`"
			ptype="`echo "$ptype" | tr '[:lower:]' '[:upper:]'`"
		fi

		local psize=$part_sz
		#typeset -i psize

		fstype="`lsblk -n -l -o 'fstype,type' $device`"
		mtpt="`lsblk -n -l -o 'mountpoint,type' $device`"

		if echo "$fstype" | grep -q -F lvm ; then
			ptype="8E00"
			fstype="lvm2"
			mtpt="`echo "$mtpt" | grep -m1 -v -F lvm`"
		fi

		fstype="`echo "$fstype" | cut -f1 -d' '`"
		mtpt="`echo "$mtpt" | cut -f1 -d' '`"

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
		elif [ "$ptype" = "FD00" -o "$ptype" = "FD" ]; then
			mtpt="raid,$mtpt,format"
			echo "raid" 1> $TMP/selected-disktype
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

	if grep -q -m1 -F '/efi,' $DRIVE_INFO ; then
		GPT_MODE="UEFI"
		bootsz="`grep -F "/efi" $DRIVE_INFO | cut -f4 -d ','`"

	elif grep -q -m1 -F ',EE' $DRIVE_INFO ; then
		GPT_MODE="GPT"
		bootsz="`grep -F '/boot' $DRIVE_INFO | cut -f4 -d ','`"

	elif grep -q -m1 -F '/boot' $DRIVE_INFO ; then
		GPT_MODE="MBR"
		bootsz="`grep -F "/boot" $DRIVE_INFO | cut -f4 -d ','`"
	else
		GPT_MODE="MBR"
	fi

	if [ -z "$bootsz" ]; then
		echo "0" 1> $TMP/selected-boot-size
	else
		echo "$bootsz" 1> $TMP/selected-boot-size
	fi

	echo "$GPT_MODE" 1> $TMP/selected-gpt-mode

	return 0
}

# Main starts here ...

DEVICE="$1"

if [ -z "$DEVICE" -o ! -e "$DEVICE" ]; then
	echo "INSTALLER: FAILURE L_NO_DRIVE_SELECTED"
	exit 1
fi

DRIVE_ID="`basename $DEVICE`"
SECTOR_SIZE="`cat $TMP/sector-size 2> /dev/null`"
GPT_MODE="`cat $TMP/selected-gpt-mode 2> /dev/null`"

DISK_SIZE="`sfdisk -s $DEVICE 2> /dev/null`"
DISK_SIZE=$(( $DISK_SIZE * 1024 / 1000000 ))

echo "$DISK_SIZE" 1> $TMP/drive-total

lsblk -d -n -o 'model,vendor,rev' "$DEVICE" | \
	sed 's/[\t ][\t ]*/ /g' 1> $TMP/selected-drive-model

DRIVE_INFO="$TMP/partitions-${DRIVE_ID}.csv"
OUTPUT_SECTORS="$TMP/sectors-${DRIVE_ID}.csv"

rm -f "$DRIVE_INFO" "$OUTPUT_SECTORS"
touch "$DRIVE_INFO" "$OUTPUT_SECTORS"

if isa_gpt_drive $DEVICE ; then
	echo "$DEVICE=GPT Partitioned" >> $TMP/gpt-mbr-drives
else
	echo "$DEVICE=MBR Partitioned" >> $TMP/gpt-mbr-drives
fi

d-set-drive-settings.sh

create_disk_log $DEVICE

if [ "$?" = 0 ]; then

	wc -l "$DRIVE_INFO" | cut -f1 -d' ' 1> $TMP/nb-partitions
	cp -f "$DRIVE_INFO" "$TMP/drive-info.csv"
	cat "$DRIVE_INFO"

	exit 0
fi

exit 1

# end Breeze::OS setup script
