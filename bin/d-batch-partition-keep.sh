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

. d-format-utils.sh

mbr_removal() {
#	Next version ...
#	sfdisk --dump ${device} 1> "$SAVELOG".dump
#	or fdisk -O "$SAVELOG" ${device}
#	sleep 1
	sync
	return 0
}

fdisk_partitioning() {

	local device="$1"

	sync # Sync drives

	if [ "$SECTOR_SIZE" = "4K" ]; then
		/sbin/fdisk -H 224 -S 56 -B $TMP/fdisk-scheme ${device} \
			1> $TMP/fdisk.log 2> $TMP/fdisk.err

	elif [ "$DRIVE_SSD" = "yes" ]; then
		/sbin/fdisk -H 32 -S 32 -B $TMP/fdisk-scheme ${device} \
			1> $TMP/fdisk.log 2> $TMP/fdisk.err
	else
		/sbin/fdisk -B $TMP/fdisk-scheme ${device} \
			1> $TMP/fdisk.log 2> $TMP/fdisk.err
	fi
	return $?
}

mbr_partitioning() {

	local device="$1"
	local disktype="$2"

	if ! fdisk_partitioning ${device} ; then
		sync; sleep 1

		if ! grep -qiF 'device or resource busy' $TMP/fdisk.log ; then
			return 1
		fi
		#partprobe ${device}
	fi

	if keep_partitions "$device" "$disktype" ; then

		test_mount $RETVAL

		if [ "$?" != 0 ]; then
			exit 1
		fi
	fi

	N1="$(fdisk -l ${device} | grep -E '^/dev/' | wc -l | cut -f1 -d' ')"
	N2="$(cat $TMP/fdisk-scheme | wc -l | cut -f1 -d' ')"

	if [ "$N1" = "$N2" ]; then
		sync; sleep 1
		return 0
	fi
	return 1
}

gpart_removal() {

	local device="$1"

	gpart destroy -F -f C "$device" \
		1> gpart.log 2> $TMP/gpart.errlog

	if [ "$?" != 0 -a "$?" != 2 ]; then
		echo "Zapping all partition information failed ! "
		echo "INSTALLER: FAILURE L_GPART_ZAPPING_FAILED"
		return 1
	fi

	sync
	return 0
}

gpt_removal() {

	local device="$1"

#	sgdisk --mbrtogpt --backup "$SAVELOG" ${device} 2> $TMP/sgdisk.errlog
#
#	if [ "$?" != 0 ]; then
#		echo "Backing-up of partition information failed ! "
#		return 1
#	fi

	sgdisk --mbrtogpt --zap-all ${device} \
		1> sgdisk.log 2> $TMP/sgdisk.errlog

	if [ "$?" != 0 -a "$?" != 2 ]; then
		echo "Zapping all partition information failed ! "
		echo "INSTALLER: FAILURE L_GPT_ZAPPING_FAILED"
		return 1
	fi

	while read line; do

		mode="$(echo "$line" | cut -f 6 -d ',')"

		if [ "$mode" = "keep" ]; then
			continue
		fi

		device="$(echo "$line" | cut -f 1 -d ',')"
		partno="$(echo "$device" | sed 's/[a-z\/]*//g')"

		sgdisk -d $partno "${device}" \
			1> $TMP/sgdisk.log 2> $TMP/sgdisk.err

		if [ "$?" = 3 ]; then
			sgdisk -g -d $partno "${device}" \
				1> $TMP/sgdisk.log 2> $TMP/sgdisk.err
		fi

		if [ "$?" != 0 ]; then
			echo "Could not remove partition $partition ! "
			echo "INSTALLER: FAILURE L_GPT_PARTITION_REMOVAL_FAILED"
			return 1
		fi
	done < "$TMP/drive-info.csv"

	sync
	return 0
}

gpt_partitioning() {

	# Default sector alignment is 2048 => 8.4M bytes for 4K drives
	#
	local size=0
	local keep=""
	local line=""
	local partno=1
	local sectors=0
	local end_sector=0
	local start_sector=0
	local alignment=2048
	local selected_drive="$1"
	local factor=$(( 1024000 / 512 )) # by the logical sector size
	local max_partitions="$(wc -l "$OUTPUT_SCHEME" | cut -f1 -d' ' | crunch)"

	while read line; do

		device="$(echo "$line" | cut -f 1 -d ',')"
		ptype="$(echo "$line" | cut -f 2 -d ',')"
		size="$(echo "$line" | cut -f 3 -d ',')"
		fstype="$(echo "$line" | cut -f 4 -d ',')"
		mtpt="$(echo "$line" | cut -f 5 -d ',')"
		mode="$(echo "$line" | cut -f 6 -d ',')"

		echo "INSTALLER: PROGRESS ((device,$device),(mountpoint,$mtpt),(filesystem,$fstype))"

		if [ "${#ptype}" = 2 ]; then
			ptype="${ptype}00"
		fi

		if [ "$ptype" = "8500" -o "$ptype" = "85" ]; then
			partno=$(( $partno + 1 ))
			continue
		fi

		start_sector=0
		sectors=$(( $size * $factor ))

		if [ "$mode" = "keep" ]; then
			alignment=0
			end_sector="0"
			keep="$(grep -F keep $TMP/kept-partitions.csv | cut -f1 -d',')"

			if grep -q -m1 -F "/$DRIVE_ID" $TMP/kept-partitions.csv ; then
				line="$(grep -F "$keep" $OUTPUT_SECTORS)"
				start_sector="$(echo "$line" | cut -f2 -d',')"
				end_sector="$(echo "$line" | cut -f3 -d',')"
				sectors="$(echo "$line" | cut -f4 -d',')"
			fi
		else
			alignment=2048

			if test $partno -lt $max_partitions; then
				end_sector=$(( $end_sector + $sectors + 2048 ))
			else
				end_sector=0
			fi
		fi

		if [ "$ptype" = "EFI" -o "$ptype" = "UEFI" ]; then
			FSTYPE="$partno:0xEF00"
		elif [ "$ptype" = "BBP" ]; then
			FSTYPE="$partno:0xEF02"

			# If Windows is to boot from a GPT disk,
			# a partition of type Microsoft Reserved
			# (sgdisk internal code 0x0C01) is recommended
			# GPT fdisk Manual (8)
			# Retype the bios partition to an MSR one
			# Not feasible if Grub is used.
#			if [ "$GPT_MODE" = "UEFI" ]; then
#				FSTYPE="$partno:0x0C01"
#			fi
		elif [ "$ptype" = "GPT" ]; then
			FSTYPE="$partno:0xEE00"
		elif [ "$fstype" = "SWAP" ]; then
			FSTYPE="$partno:0x8200"
		elif [ "$ptype" = "LVM" ]; then
			FSTYPE="$partno:0x8E00"
		elif [ "$ptype" = "RAID" ]; then
			FSTYPE="$partno:0xFD00"
		else
			FSTYPE="$partno:0x$ptype"
		fi

		sgdisk --set-alignment=$alignment \
			--new=$partno:$start_sector:$end_sector \
			--typecode=$FSTYPE $selected_drive \
			1> $TMP/sgdisk.log 2> $TMP/sgdisk.err

		if [ "$?" != 0 ]; then
			echo "Could not partition drive $selected_drive"
			echo "INSTALLER: FAILURE Could not partition drive $selected_drive"
			return 1
		fi

		if [ "$mode" = "keep" ]; then
			device=$(echo "$device" | sed "s/[0-9]*/$partno/g")

			test_mount $device

			if [ "$?" != 0 ]; then
				exit 1
			fi
		fi

		if [ "$mtpt" = "/boot" ]; then
			# Required by syslinux to set the active partition
			sgdisk --attributes=${partno}:set:2 $selected_drive
		fi

		partno=$(( $partno + 1 ))

	done < "$OUTPUT_SCHEME"

	sync
	return 0
}

# Main starts here ...
SELECTED_DRIVE="$1"

DRIVE_ID="$(basename $SELECTED_DRIVE)"
DRIVE_SSD="$(is_drive_ssd $SELECTED_DRIVE)"

SECTOR_SIZE="$(cat $TMP/sector-size 2> /dev/null)"
DRIVE_TOTAL="$(cat $TMP/drive-total 2> /dev/null)"
GPT_MODE="$(cat $TMP/selected-gpt-mode 2> /dev/null)"
SELECTED_SCHEME="$(cat $TMP/selected-scheme 2> /dev/null)"

if ! check_settings_file "scheme-${DRIVE_ID}" ; then
	echo "INSTALLER: FAILURE L_MISSING_SCHEME_FILE"
	exit 1
fi

DISK_TYPE="$(extract_value scheme-${DRIVE_ID} 'disk-type')"

touch $TMP/umount.errs 2> /dev/null

if [ ! -s $TMP/kept-partitions.csv ]; then
	unlink $TMP/kept-partitions.csv 2> /dev/null
fi

if [ -z "$DRIVE_TOTAL" -o -z "$DRIVE_ID" -o \
	-z "$SELECTED_DRIVE" -o -z "$SELECTED_SCHEME" ]; then
	echo "INSTALLER: FAILURE L_MISSING_DRIVE_NAME"
	exit 1
fi

if [ "$GPT_MODE" != "MBR" -o "$DISK_TYPE" = "lvm" ]; then
	if keep_partitions "$SELECTED_DRIVE" "$DISK_TYPE" ; then
		echo "INSTALLER: FAILURE L_CANNOT_KEEP_HOME_WITH_LVM"
		exit 1
	fi
fi

OUTPUT_SCHEME="$TMP/partitions-${DRIVE_ID}.csv"
NEW_OUTPUT_SCHEME="$TMP/new-partitions-${DRIVE_ID}.csv"
OUTPUT_SECTORS="$TMP/sectors-${DRIVE_ID}.csv"

if [ "$SAFEMODE" = "yes" -a "$SELECTED_DRIVE" != "/dev/sdb" ]; then
	echo "INVALID TEST DRIVE $SELECTED_DRIVE !"
	echo "INSTALLER: FAILURE L_INVALID_TEST_DRIVE_SELECTED !"
	exit 1
fi

#if [ ! -x /bin/d-setenv.sh ]; then
#	if test $DRIVE_TOTAL -gt 7000; then
#		echo "INVALID TEST DRIVE !"
#		exit 1
#	fi
#fi
#
#echo "VALID TEST DRIVE $SELECTED_DRIVE !"

if [ -e "$OUTPUT_SCHEME" -a -e "$NEW_OUTPUT_SCHEME" ]; then
	if ! cmp -s "$NEW_OUTPUT_SCHEME" "$OUTPUT_SCHEME" ; then
		cp "$NEW_OUTPUT_SCHEME" "$OUTPUT_SCHEME"
		d-create-scheme.sh modify
	fi
fi

unmount_devices ${SELECTED_DRIVE}

if [ "$DISK_TYPE" = "lvm" -o "$DISK_TYPE" = "lvm-crypto" ]; then
	# Scanning LVM volume groups on the selected drive, if any
	d-lvm-info.sh pv scan 1> $TMP/lvm-physical.csv 2> /dev/null

	# Removing LVM volume groups on the selected drive, if any
	d-batch-lvm.sh remove pv ${SELECTED_DRIVE} 1> $TMP/lvm-del.err 2>&1
fi

SAVELOG="$TMP/sectors_${GPT_MODE}_${DRIVE_ID}.sav"

if is_gpt_drive ${SELECTED_DRIVE} ; then
	if [ "$BREEZE_PLATFORM" = "freebsd" ]; then
		gpart_removal ${SELECTED_DRIVE}
	else
		gpt_removal ${SELECTED_DRIVE}
	fi
else
	mbr_removal ${SELECTED_DRIVE}
fi

if [ "$?" = 0 ]; then

	if [ "$SECTOR_SIZE" = "4K" ]; then
		dd if=/dev/zero of=$SELECTED_DRIVE bs=4096 count=2048
	else
		dd if=/dev/zero of=$SELECTED_DRIVE bs=512 count=2048
	fi

	if [ "$GPT_MODE" = "MBR" ]; then
		mbr_partitioning ${SELECTED_DRIVE} ${DISK_TYPE}
	else
		# Because of a bug in gdisk (v0.6.10), we do the following:
		dd if=/dev/zero bs=512 count=1 \
			seek=$(( $(blockdev --getsize64 $SELECTED_DRIVE) / 512 - 1 )) \
			of=$SELECTED_DRIVE

		gpt_partitioning ${SELECTED_DRIVE}
	fi
fi

if [ "$DISK_TYPE" = "crypto" -o "$DISK_TYPE" = "lvm-crypto" ]; then
	if [ "$CRYPTO_TYPE" = "cryptsetup" ]; then
		d-cryptsetup.sh ${SELECTED_DRIVE}
	fi
fi

#if [ -f "$SAVELOG" ]; then
#	sgdisk --load-backup "$SAVELOG" $SELECTED_DRIVE 
#fi

exit $?

# end Breeze::OS setup script
