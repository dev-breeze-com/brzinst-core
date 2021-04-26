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

get_percentage()
{
	local mtpt="$2"
	local partition="$3"
	local path="$BRZDIR/data/scheme-${1}.csv"
	local nb_part=$(( $MAX_PARTITIONS - $MIN_PARTITIONS ))
	local value=""

	if [ -z "$partition" ]; then
		partition="$(basename $mtpt)"
	fi

	local percent=$(grep -F ",$partition" $path | cut -f2 -d',' | crunch)

	if [ -z "$percent" -o "$percent" = "0" ]; then
		percent=100
		if test "$nb_part" -gt 0 ; then
			percent=$(( 100 / $nb_part ))
		fi
	fi

#	if [ "$DRIVE_SIZE" != "$EXTENDED_SIZE" ]; then
#		nb_part=$(( $MAX_PARTITIONS - $MIN_PARTITIONS_PLUS1 ))
#		percent=$(( 100 / $nb_part ))
	if [ "$mtpt" = "/home" ]; then
		percent=$PERCENT_TOTAL
	fi
	echo "$percent"
	return 0
}

set_partition_names()
{
	local scheme="$1"
	local partition=""
	local path="$BRZDIR/data/scheme-${1}.csv"
	local idx="0"

	eval PARTITIONS${idx}="boot"

#	if [ "$scheme" = "usb-backup" ]; then
#
#		idx=$(( $idx + 1 ))
#		eval PARTITIONS${idx}="boot"
#
#		MIN_PARTITIONS=1
#		MIN_PARTITIONS_PLUS1=2
#		MAX_PARTITIONS=${idx}
#		return 0
#	fi
#
#	if [ "$scheme" = "usb-install" ]; then
#
#		eval PARTITIONS${idx}="bios"
#
#		idx=$(( $idx + 1 ))
#		eval PARTITIONS${idx}="bios"
#
#		idx=$(( $idx + 1 ))
#		eval PARTITIONS${idx}="boot"
#
#		idx=$(( $idx + 1 ))
#		eval PARTITIONS${idx}="root"
#
#		MIN_PARTITIONS=3
#		MIN_PARTITIONS_PLUS1=4
#		MAX_PARTITIONS=${idx}
#
#		return 0
#	fi

	idx=$(( $idx + 1 ))
	eval PARTITIONS${idx}="boot"

	idx=$(( $idx + 1 ))
	eval PARTITIONS${idx}="bios"

	if [ "$DISK_TYPE" = "lvm" ]; then
		idx=$(( $idx + 1 ))
		eval PARTITIONS${idx}="dummy"
	else
		idx=$(( $idx + 1 ))
		eval PARTITIONS${idx}="swap"
	fi

	idx=$(( $idx + 1 ))
	eval PARTITIONS${idx}="extended"

	idx=$(( $idx + 1 ))
	eval PARTITIONS${idx}="root"

	while read line ; do
		partition="$(echo $line | cut -f3 -d,)"

		if test $idx -eq 5 ; then
			if [ "$partition" != "root" ]; then
				echo "INSTALLER: FAILURE L_ROOT_MUST_FIRST_DECLARED"
				exit 1
			fi
		fi
		idx=$(( $idx + 1 ))
		eval PARTITIONS${idx}="$partition"
	done < $path

	if [ "$partition" != "home" ]; then
		echo "INSTALLER: FAILURE L_HOME_MUST_LAST_DECLARED"
		exit 1
	fi

	if [ "$scheme" = "root" ]; then
		MAX_PARTITIONS=${idx}

	elif [ "$scheme" = "root-home" ]; then
		idx=$(( $idx + 1 ))
		eval PARTITIONS${idx}="home"

	elif [ "$scheme" = "root-var" -o "$scheme" = "server-var" ]; then
		idx=$(( $idx + 1 ))
		eval PARTITIONS${idx}="var"
		idx=$(( $idx + 1 ))
		eval PARTITIONS${idx}="home"

	elif [ "$scheme" = "root-srv" -o "$scheme" = "server-srv" ]; then
		idx=$(( $idx + 1 ))
		eval PARTITIONS${idx}="var"
		idx=$(( $idx + 1 ))
		eval PARTITIONS${idx}="srv"
		idx=$(( $idx + 1 ))
		eval PARTITIONS${idx}="home"

	elif [ "$scheme" = "root-share" -o "$scheme" = "root-devel" ]; then
		idx=$(( $idx + 1 ))
		eval PARTITIONS${idx}="var"
		idx=$(( $idx + 1 ))
		eval PARTITIONS${idx}="srv"
		idx=$(( $idx + 1 ))
		eval PARTITIONS${idx}="share"
		idx=$(( $idx + 1 ))
		eval PARTITIONS${idx}="home"

	elif [ "$scheme" = "root-opt" ]; then
		idx=$(( $idx + 1 ))
		eval PARTITIONS${idx}="var"
		idx=$(( $idx + 1 ))
		eval PARTITIONS${idx}="srv"
		idx=$(( $idx + 1 ))
		eval PARTITIONS${idx}="share"
		idx=$(( $idx + 1 ))
		eval PARTITIONS${idx}="opt"
		idx=$(( $idx + 1 ))
		eval PARTITIONS${idx}="home"

	elif [ "$scheme" = "root-build" ]; then
		idx=$(( $idx + 1 ))
		eval PARTITIONS${idx}="var"
		idx=$(( $idx + 1 ))
		eval PARTITIONS${idx}="srv"
		idx=$(( $idx + 1 ))
		eval PARTITIONS${idx}="share"
		idx=$(( $idx + 1 ))
		eval PARTITIONS${idx}="opt"
		idx=$(( $idx + 1 ))
		eval PARTITIONS${idx}="build"
		idx=$(( $idx + 1 ))
		eval PARTITIONS${idx}="home"
	else
		return 1
	fi

	MIN_PARTITIONS=4
	MIN_PARTITIONS_PLUS1=5
	MAX_PARTITIONS=${idx}

	return 0
}

modify_scheme()
{
	local IDX=1
	local line=""
	local size=""
	local fstype=""
	local scheme="$1"

	if [ "$DISK_TYPE" = "raid" ]; then
		PART_TYPE=FD00
		PT_TYPE=FD
	elif [ "$DISK_TYPE" = "lvm" ]; then
		PART_TYPE=8E00
		PT_TYPE=8E
	elif [ "$DISK_TYPE" = "bsd" ]; then
		PART_TYPE=8300
		PT_TYPE=83
	else
		PART_TYPE=8300
		PT_TYPE=83
	fi

	while read line ; do

		size="$(echo "$line" | cut -f3 -d',')"
		fstype="$(echo "$line" | cut -f4 -d',')"
		fsmtpt="$(echo "$line" | cut -f5 -d',')"

		eval PART=\$PARTITIONS$IDX
		sizeup_partition_$PART "$IDX" "$size" "$fsmtpt" "$fstype"
		IDX=$(( $IDX + 1 ))

	done < "$scheme"
	return 0
}

sizeup_partitions()
{
	local IDX=1
	local PART=""

	if [ "$DISK_TYPE" = "raid" ]; then
		PART_TYPE=FD00
		PT_TYPE=FD
	elif [ "$DISK_TYPE" = "lvm" ]; then
		PART_TYPE=8E00
		PT_TYPE=8E
	elif [ "$DISK_TYPE" = "bsd" ]; then
		PART_TYPE=8300
		PT_TYPE=83
	else
		PART_TYPE=8300
		PT_TYPE=83
	fi

	while test $IDX -le $MAX_PARTITIONS ; do
		eval PART=\$PARTITIONS$IDX
		sizeup_partition_$PART $IDX
		IDX=$(( $IDX + 1 ))
	done

	return 0
}

sizeup_partition_boot()
{
	local IDX="$1"
	local SIZE="$2"
	local FS_TYPE="$4"

	if [ "$ARG" != "modify" ]; then
		SIZE=$BOOT_SIZE
		FS_TYPE="$FSTYPE"
	fi

	SECTORS=$(( $SIZE * $FACTOR ))

	if [ "$SCHEME" = "usb-backup" ]; then
		SECTORS=$(( $DISK_SIZE * $FACTOR ))
		echo "$START,+,0B," >> $FDISK_SCHEME
		if [ "$ARG" != "modify" ]; then
			echo "/dev/${DRIVE_ID}${IDX},EF00,$DISK_SIZE,vfat,/,format" >> $OUTPUT_SCHEME
		fi
	elif [ "$GPT_MODE" = "UEFI" -o "$SCHEME" = "usb-install" ]; then
		echo "$START,$SECTORS,EF,*" >> $FDISK_SCHEME
		if [ "$ARG" != "modify" ]; then
			echo "/dev/${DRIVE_ID}${IDX},EF00,$SIZE,vfat,/boot,format" >> $OUTPUT_SCHEME
		fi
	elif [ "$GPT_MODE" = "GPT" ]; then
		echo "$START,$SECTORS,EE,*" >> $FDISK_SCHEME
		if [ "$ARG" != "modify" ]; then
			echo "/dev/${DRIVE_ID}${IDX},EE00,$SIZE,$FS_TYPE,/boot,format" >> $OUTPUT_SCHEME
		fi
	else
		echo "$START,$SECTORS,L,*" >> $FDISK_SCHEME
		if [ "$ARG" != "modify" ]; then
			echo "/dev/${DRIVE_ID}${IDX},EF01,$SIZE,$FS_TYPE,/boot,format" >> $OUTPUT_SCHEME
		fi
	fi
	return 0
}

sizeup_partition_dummy()
{
	local IDX="$1"
	local SIZE="$2"

	START=$(( $START + $SECTORS ))
	START=$(( $START / 8 * 8 + $OFFSET ))

	if [ -z "$SIZE" ]; then SIZE=$DUMMY_SIZE; fi

	if [ "$ARG" != "modify" ]; then
		echo "/dev/${DRIVE_ID}${IDX},8300,$SIZE,none,/none,ignore" >> $OUTPUT_SCHEME
	fi

	SECTORS=$(( $SIZE * $FACTOR ))
	echo "$START,$SECTORS,L" >> $FDISK_SCHEME

	return 0
}

sizeup_partition_bios()
{
	local IDX="$1"
	local SIZE="$2"

	START=$(( $START + $SECTORS ))
	START=$(( $START / 8 * 8 + $OFFSET ))

	if [ -z "$SIZE" ]; then
		SIZE=$BIOS_SIZE
		SECTORS=$(( $SIZE * $FACTOR ))
	fi

	if [ "$ARG" != "modify" ]; then
		if [ "$SCHEME" = "usb-install" ]; then
			echo "/dev/${DRIVE_ID}${IDX},EF02,$SIZE,msdos,/none,format" >> $OUTPUT_SCHEME
			echo "$START,$SECTORS,EF" >> $FDISK_SCHEME
		else
			echo "/dev/${DRIVE_ID}${IDX},EF02,$SIZE,none,/none,ignore" >> $OUTPUT_SCHEME
			echo "$START,$SECTORS,L" >> $FDISK_SCHEME
		fi
	else
		echo "$START,$SECTORS,L" >> $FDISK_SCHEME
	fi

	SECTORS=$(( $SIZE * $FACTOR ))
	return 0
}

sizeup_partition_swap()
{
	local IDX="$1"
	local SIZE="$2"

	START=$(( $START + $SECTORS ))
	START=$(( $START / 8 * 8 + $OFFSET ))

	if [ -z "$SIZE" ]; then SIZE=$SWAP_SIZE; fi

	if [ "$ARG" != "modify" ]; then
		echo "/dev/${DRIVE_ID}${IDX},8200,$SIZE,swap,/swap,format" >> $OUTPUT_SCHEME
	fi

	SECTORS=$(( $SIZE * $FACTOR ))
	echo "$START,$SECTORS,S" >> $FDISK_SCHEME

	return 0
}

sizeup_partition_extended()
{
	local IDX="$1"
	local SIZE="$2"

	START=$(( $START + $SECTORS ))
	START=$(( $START / 8 * 8 + $OFFSET ))

	if [ "$ARG" != "modify" ]; then
		SIZE=$(( $EXTENDED_SIZE / 8 * 8 ))
		echo "/dev/${DRIVE_ID}${IDX},8500,$SIZE,extended,/none,ignore" >> $OUTPUT_SCHEME
	fi
	echo "$START,+,E" >> $FDISK_SCHEME
	return 0
}

sizeup_partition_root()
{
	local IDX="$1"
	local SIZE="$2"
	local FS_MTPT="$3"
	local FS_TYPE="$4"
	local PERCENT=20

	if [ -z "$SIZE" ]; then SIZE=$DRIVE_SIZE; fi

	if [ -z "$FS_MTPT" ]; then FS_MTPT="/"; fi

	if [ "$SCHEME" = "root" -o "$SCHEME" = "usb-install" ]; then

		if [ "$ARG" != "modify" ]; then
			FS_TYPE="$FSTYPE"
			SIZE=$(( $DRIVE_SIZE / 8 * 8 ))
			echo "/dev/${DRIVE_ID}${IDX},$PART_TYPE,$SIZE,$FS_TYPE,/,format" >> $OUTPUT_SCHEME
		fi
		echo ",+,$PT_TYPE" >> $FDISK_SCHEME
		return 0
	fi

	if [ "$ARG" = "modify" ]; then
		SECTORS=$(( $SIZE * $FACTOR - 2048 ))
	else
		FS_TYPE="$FSTYPE"
		PERCENT=$(get_percentage "$SCHEME" $FS_MTPT root)
		PERCENT_TOTAL=$(( $PERCENT_TOTAL - $PERCENT ))

		SECTORS=$(( $DRIVE_SIZE * $PERCENT / 100 * $FACTOR / 8 * 8 - 2048 ))
		SIZE=$(( $DRIVE_SIZE * $PERCENT / 100 / 8 * 8 ))
		echo "/dev/${DRIVE_ID}${IDX},$PART_TYPE,$SIZE,$FS_TYPE,/,format" >> $OUTPUT_SCHEME
	fi
	echo ",$SECTORS,$PT_TYPE" >> $FDISK_SCHEME
	return 0
}

sizeup_partition_home()
{
	local IDX="$1"
	local SIZE="$2"
	local FS_MTPT="$3"
	local FS_TYPE="$4"
	local PERCENT=20

	if [ -z "$SIZE" ]; then SIZE=$DRIVE_SIZE; fi

	if [ "$ARG" = "modify" ]; then
		SECTORS=$(( $SIZE * $FACTOR - 2048 ))
	else
		FS_MTPT="/home"
		FS_TYPE="$FSTYPE"
		PERCENT=$(get_percentage "$SCHEME" $FS_MTPT)
		PERCENT_TOTAL=$(( $PERCENT_TOTAL - $PERCENT ))

		SECTORS=$(( $DRIVE_SIZE * $PERCENT / 100 * $FACTOR / 8 * 8 - 2048 ))
		SIZE=$(( $DRIVE_SIZE * $PERCENT / 100 / 8 * 8 ))
		echo "/dev/${DRIVE_ID}${IDX},$PART_TYPE,$SIZE,$FS_TYPE,$FS_MTPT,format" >> $OUTPUT_SCHEME
	fi

	echo ",+,$PT_TYPE" >> $FDISK_SCHEME

	return 0
}

sizeup_partition_var()
{
	if [ "$ARG" = "modify" ]; then
		sizeup_partition_X "$1" "$2" "$3" "$4"
	else
		sizeup_partition_X "$1" "$DRIVE_SIZE" "/var"
	fi
	return "$?"
}

sizeup_partition_srv()
{
	if [ "$ARG" = "modify" ]; then
		sizeup_partition_X "$1" "$2" "$3" "$4"
	else
		sizeup_partition_X "$1" "$DRIVE_SIZE" "/srv"
	fi
	return "$?"
}

sizeup_partition_opt()
{
	if [ "$ARG" = "modify" ]; then
		sizeup_partition_X "$1" "$2" "$3" "$4"
	else
		sizeup_partition_X "$1" "$DRIVE_SIZE" "/opt"
	fi
	return "$?"
}

sizeup_partition_share()
{
	if [ "$ARG" = "modify" ]; then
		sizeup_partition_X "$1" "$2" "$3" "$4"
	else
		sizeup_partition_X "$1" "$DRIVE_SIZE" "/share"
	fi
	return "$?"
}

sizeup_partition_build()
{
	if [ "$ARG" = "modify" ]; then
		sizeup_partition_X "$1" "$2" "$3" "$4"
	else
		sizeup_partition_X "$1" "$DRIVE_SIZE" "/build"
	fi
	return "$?"
}

sizeup_partition_X()
{
	local IDX="$1"
	local SIZE="$2"
	local FS_MTPT="$3"
	local FS_TYPE="$4"
	local PERCENT=20

	if [ -z "$FS_TYPE" ]; then FS_TYPE="$FSTYPE"; fi

	if [ -z "$SIZE" ]; then SIZE=$DRIVE_SIZE; fi

	if [ "$ARG" = "modify" ]; then
		SECTORS=$(( $SIZE * $FACTOR - 2048 ))
	else
		PERCENT=$(get_percentage "$SCHEME" $FS_MTPT)
		PERCENT_TOTAL=$(( $PERCENT_TOTAL - $PERCENT ))

		SECTORS=$(( $SIZE * $PERCENT / 100 * $FACTOR / 8 * 8 - 2048 ))
		SIZE=$(( $SIZE * $PERCENT / 100 / 8 * 8 ))
		echo "/dev/${DRIVE_ID}${IDX},$PART_TYPE,$SIZE,$FS_TYPE,$FS_MTPT,format" >> $OUTPUT_SCHEME
	fi
	echo ",$SECTORS,$PT_TYPE" >> $FDISK_SCHEME
	return 0
}

# Main starts here ...
DEVICE="$1"
ARG="$2"

OFFSET=0
START=2048
SECTORS=0
PERCENT_TOTAL=100
START_SECTORS=512000
FACTOR=$(( 1024000 / 512 )) # by the logical sector size

BIOS_SIZE=2 # 2 Megabytes
DUMMY_SIZE=256
MAX_PARTITIONS=0

if is_valid_device "$DEVICE" ; then
	DRIVE_ID="$(basename $1)"
	cat $TMP/scheme.map 1> $TMP/scheme-${DRIVE_ID}.map
else
	echo "INSTALLER: FAILURE L_NO_DEVICE_SPECIFIED"
	exit 1
fi

SELECTED="$(extract_value scheme-${DRIVE_ID} 'device')"

if [ -z "$SELECTED" -o "$SELECTED" != "$DEVICE" ]; then
	echo "INSTALLER: FAILURE L_SCRIPT_MISMATCH_ON_DEVICE"
	exit 1
fi

SCHEME="$(extract_value scheme-${DRIVE_ID} 'scheme')"
DISK_TYPE="$(extract_value scheme-${DRIVE_ID} 'disk-type')"
ENCRYPTED="$(extract_value scheme-${DRIVE_ID} 'encrypted')"
FSTYPE="$(extract_value scheme-${DRIVE_ID} 'fstype')"
GPT_MODE="$(extract_value scheme-${DRIVE_ID} 'gpt-mode' 'upper')"
BOOT_SIZE="$(extract_value scheme-${DRIVE_ID} 'boot-size')"
SWAP_SIZE="$(extract_value scheme-${DRIVE_ID} 'swap-size')"
SECTOR_SIZE="$(extract_value scheme-${DRIVE_ID} 'sector-size')"

if [ "$DISK_TYPE" != "lvm" ]; then
	if [ "$SCHEME" = "lvm-10" -o "$SCHEME" = "lvm-12" ]; then
		echo "INSTALLER: FAILURE L_MISMATCH_SCHEME_DISK_TYPE"
		exit 1
	fi
fi

FDISK_SCHEME="$TMP/fdisk-${DRIVE_ID}-scheme"
OUTPUT_SCHEME=$TMP/partitions-${DRIVE_ID}.csv
OUTPUT_SECTORS=$TMP/sectors-${DRIVE_ID}.csv
#NEW_OUTPUT_SCHEME="$TMP/partitions-${DRIVE_ID}-new.csv"

unlink "$OUTPUT_SCHEME" 2> /dev/null
touch "$OUTPUT_SCHEME" 2> /dev/null

unlink "$FDISK_SCHEME" 2> /dev/null
touch "$FDISK_SCHEME" 2> /dev/null

DISK_SIZE="$(get_drive_size $DEVICE)"

RESERVED=$(( $BOOT_SIZE + $BIOS_SIZE + $SWAP_SIZE ))

if [ "$DISK_TYPE" = "lvm" ]; then

	cp -f $TMP/scheme.map $TMP/scheme-${DISK_TYPE}.map

	# Replace swap primary partition by dummy one
	# Swap partition is to be part of the LVM store;
	# if an LVM drive is being prepared.
	RESERVED=$(( $BOOT_SIZE + $BIOS_SIZE + $DUMMY_SIZE ))

	# Force all LVM partitioning to the root scheme.
	# Use user specified scheme for logical volumes.
	SCHEME="root"
fi

#if [ "$ARG" = "modify" ]; then
#	if set_partition_names "$SCHEME" ; then
#		modify_scheme "$OUTPUT_SCHEME"
#	fi
#	exit $?
#fi
#
#unlink "$NEW_OUTPUT_SCHEME" 2> /dev/null

DEVIDX="$(get_device_counter $DEVICE)"

if [ -z "$DEVIDX" ]; then
	DEVIDX="1"
else
	DEVIDX=$(( $DEVIDX + 1 ))
fi

touch $TMP/formatted-drives

echo "${DEVICE}=${DEVIDX}" >> $TMP/formatted-drives

if keep_home_partition "$DEVICE" ; then
	wc -l "$OUTPUT_SCHEME" | cut -f1 -d' ' 1> $TMP/nb-partitions
	echo "INSTALLER: SUCCESS"
	exit 0
fi

DRIVE_SIZE=$(( $DISK_SIZE - $RESERVED ))
EXTENDED_SIZE=$DRIVE_SIZE

if set_partition_names "$SCHEME" ; then

	if sizeup_partitions "$SCHEME" "$DEVICE" "$DISK_TYPE" ; then
		wc -l "$OUTPUT_SCHEME" | cut -f1 -d' ' 1> $TMP/nb-partitions
		echo "INSTALLER: SUCCESS"
		exit 0
	fi
fi

echo "INSTALLER: FAILURE"
exit 1

# end Breeze::OS setup script
