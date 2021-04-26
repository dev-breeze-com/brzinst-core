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
	local scheme="$1"
	local nb_part=$(( $MAX_PARTITIONS - $MIN_PARTITIONS ))
	local percent=$(( 100 / $nb_part ))

	if [ "$DRIVE_SIZE" != "$EXTENDED_SIZE" ]; then
		nb_part=$(( $MAX_PARTITIONS - $MIN_PARTITIONS_PLUS1 ))
		percent=$(( 100 / $nb_part ))

	elif [ "$mtpt" = "/" ]; then
		if [ "$scheme" = "root-home" ]; then
			percent=40
		fi
	elif [ "$mtpt" = "/home" ]; then
		if [ "$scheme" = "root-home" ]; then
			percent=60
		else
			nb_part=$(( $MAX_PARTITIONS - $MIN_PARTITIONS_PLUS1 ))
			percent=$(( $nb_part * $percent ))
			percent=$(( 100 - $percent ))
		fi
	fi
	echo "$percent"
	return 0
}

set_partition_names()
{
	local scheme="$1"
	local idx="0"

	eval PARTITIONS${idx}="boot"

	idx=$(( $idx + 1 ))
	eval PARTITIONS${idx}="boot"

	if [ "$DISK_TYPE" = "msdos" -o "$DISK_TYPE" = "vfat" ]; then

		idx=$(( $idx + 1 ))
		eval PARTITIONS${idx}="efi"

		idx=$(( $idx + 1 ))
		eval PARTITIONS${idx}="root"

		MIN_PARTITIONS=2
		MIN_PARTITIONS_PLUS1=3
		MAX_PARTITIONS=${idx}

		return 0
	fi

	idx=$(( $idx + 1 ))
	eval PARTITIONS${idx}="bios"

	if [ "$DISK_TYPE" = "lvm" -o "$DISK_TYPE" = "lvmcrypto" ]; then
		idx=$(( $idx + 1 ))
		eval PARTITIONS${idx}="dummy"

	elif [ "$DISK_TYPE" = "msdos" -o "$DISK_TYPE" = "vfat" ]; then
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

	if [ "$scheme" = "root" ]; then
		MAX_PARTITIONS=${idx}

	elif [ "$scheme" = "root-home" ]; then
		idx=$(( $idx + 1 ))
		eval PARTITIONS${idx}="home"

	elif [ "$scheme" = "root-var" ]; then
		idx=$(( $idx + 1 ))
		eval PARTITIONS${idx}="var"
		idx=$(( $idx + 1 ))
		eval PARTITIONS${idx}="home"

	elif [ "$scheme" = "root-srv" ]; then
		idx=$(( $idx + 1 ))
		eval PARTITIONS${idx}="var"
		idx=$(( $idx + 1 ))
		eval PARTITIONS${idx}="srv"
		idx=$(( $idx + 1 ))
		eval PARTITIONS${idx}="home"

	elif [ "$scheme" = "root-opt" ]; then
		idx=$(( $idx + 1 ))
		eval PARTITIONS${idx}="var"
		idx=$(( $idx + 1 ))
		eval PARTITIONS${idx}="srv"
		idx=$(( $idx + 1 ))
		eval PARTITIONS${idx}="opt"
		idx=$(( $idx + 1 ))
		eval PARTITIONS${idx}="home"

	elif [ "$scheme" = "root-share" ]; then
		idx=$(( $idx + 1 ))
		eval PARTITIONS${idx}="var"
		idx=$(( $idx + 1 ))
		eval PARTITIONS${idx}="srv"
		idx=$(( $idx + 1 ))
		eval PARTITIONS${idx}="opt"
		idx=$(( $idx + 1 ))
		eval PARTITIONS${idx}="share"
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
	elif [ "$DISK_TYPE" = "lvm" -o "$DISK_TYPE" = "lvmcrypto" ]; then
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
		sizeup_partition_$PART $IDX $size $fsmtpt $fstype
		IDX=$(( $IDX + 1 ))
	done < "$scheme"
}

sizeup_partitions()
{
	local IDX=1
	local PART=""
	local KEEPPART=""
	local SIZE=0
	local SIZE_DRIVE=0
	local keep_size=0

	local keep=""
	local size=""
	local ptype=""
	local scheme="$1"
	local device="$2"
	local disktype="$3"

	if [ "$DISK_TYPE" = "raid" ]; then
		PART_TYPE=FD00
		PT_TYPE=FD
	elif [ "$DISK_TYPE" = "lvm" -o "$DISK_TYPE" = "lvmcrypto" ]; then
		PART_TYPE=8E00
		PT_TYPE=8E
	elif [ "$DISK_TYPE" = "bsd" ]; then
		PART_TYPE=8300
		PT_TYPE=83
	else
		PART_TYPE=8300
		PT_TYPE=83
	fi

	if keep_partitions "$device" "$disktype" ; then

		while read line; do

			eval kept_names$IDX=""

			keep="$(echo "$line" | cut -f6 -d',')"
			ptype="$(echo "$line" | cut -f2 -d',')"

			if [ "$ptype" = "5" -o "$ptype" = "85" -o "$ptype" = "8500" ]; then
				IDX=$(( $IDX + 1 ))
				continue
			fi

			if [ "$keep" = "keep" ]; then
				keep_size="$(echo "$line" | cut -f3 -d',')"
				#DRIVE_SIZE=$(( $DRIVE_SIZE - $keep_size ))
				eval kept_names$IDX="$line"
			else
				size="$(echo "$line" | cut -f3 -d',')"
				SIZE_DRIVE=$(( $SIZE_DRIVE + $size ))
			fi
			IDX=$(( $IDX + 1 ))
		done < $TMP/kept-partitions.csv

		IDX=1

		DRIVE_SIZE=$(( $SIZE_DRIVE - $RESERVED ))

		# Just to keep /home partition, for now ...
		#
		while test $IDX -le $MAX_PARTITIONS ; do

			eval mtpt=\$PARTITIONS$IDX
			eval keep=\$kept_names$IDX

			if [ "$keep" != "" ]; then

				if [ "$mtpt" = "home" ]; then

					device="$(echo "$keep" | cut -f1 -d',')"
					KEEPPART="$(basename "$device" | sed 's/[a-z\/]*//g')"

					keep="$(echo "$keep" | sed 's/^[^,]*,//g')"
					keep="/dev/${DRIVE_ID}${IDX},${keep}"
					keep="$(echo "$keep" | sed 's/,,/,\/home,/g')"

					START="$(grep -F "$device" $OUTPUT_SECTORS | cut -f2 -d,)"
					SIZE="$(grep -F "$device" $OUTPUT_SECTORS | cut -f4 -d,)"

					echo "$keep" >> $OUTPUT_SCHEME
					echo "$START,$SIZE,L,K$KEEPPART" >> $TMP/fdisk-scheme

					IDX=$(( $IDX + 1 ))
				else
					eval PART=\$PARTITIONS$IDX
					sizeup_partition_$PART $IDX
					IDX=$(( $IDX + 1 ))
					eval kept_names$IDX="$keep"
				fi
			else
				eval PART=\$PARTITIONS$IDX
				sizeup_partition_$PART $IDX
				IDX=$(( $IDX + 1 ))
			fi
		done
	else
		while test $IDX -le $MAX_PARTITIONS ; do
			eval PART=\$PARTITIONS$IDX
			sizeup_partition_$PART $IDX
			IDX=$(( $IDX + 1 ))
		done
	fi
	return 0
}

sizeup_partition_efi()
{
	local IDX="$1"
	local SIZE="$2"
	local FS_TYPE="$4"

	if [ "$ARG" != "modify" ]; then
		SIZE=$BOOT_SIZE
		FS_TYPE="$FSTYPE"
	fi

	SECTORS=$(( $SIZE * $FACTOR ))
	echo "$START,$SECTORS,EF,*" 1> $TMP/fdisk-scheme

	if [ "$ARG" != "modify" ]; then
		echo "/dev/${DRIVE_ID}${IDX},EF00,$SIZE,vfat,/boot,format" 1> $OUTPUT_SCHEME
	fi
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

	if [ "$DISK_TYPE" = "msdos" -o "$DISK_TYPE" = "vfat" ]; then
		SECTORS=$(( $SIZE * $FACTOR ))
		echo "$START,$SECTORS,EF,*" 1> $TMP/fdisk-scheme
		if [ "$ARG" != "modify" ]; then
			echo "/dev/${DRIVE_ID}${IDX},EF02,$SIZE,msdos,/boot,format" 1> $OUTPUT_SCHEME
		fi
	elif [ "$GPT_MODE" = "UEFI" ]; then
		SECTORS=$(( $SIZE * $FACTOR ))
		echo "$START,$SECTORS,EF,*" 1> $TMP/fdisk-scheme
		if [ "$ARG" != "modify" ]; then
			echo "/dev/${DRIVE_ID}${IDX},EF00,$SIZE,vfat,/boot,format" 1> $OUTPUT_SCHEME
		fi
	elif [ "$GPT_MODE" = "GPT" ]; then
		SECTORS=$(( $SIZE * $FACTOR ))
		echo "$START,$SECTORS,EE,*" 1> $TMP/fdisk-scheme
		if [ "$ARG" != "modify" ]; then
			echo "/dev/${DRIVE_ID}${IDX},EE00,$SIZE,$FS_TYPE,/boot,format" 1> $OUTPUT_SCHEME
		fi
	else
		SECTORS=$(( $SIZE * $FACTOR ))
		echo "$START,$SECTORS,L,*" 1> $TMP/fdisk-scheme
		if [ "$ARG" != "modify" ]; then
			echo "/dev/${DRIVE_ID}${IDX},EF01,$SIZE,$FS_TYPE,/boot,format" 1> $OUTPUT_SCHEME
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
	echo "$START,$SECTORS,L" >> $TMP/fdisk-scheme

	return 0
}

sizeup_partition_bios()
{
	local IDX="$1"
	local SIZE="$2"

	START=$(( $START + $SECTORS ))
	START=$(( $START / 8 * 8 + $OFFSET ))

	if [ -z "$SIZE" ]; then SIZE=$BIOS_SIZE; fi

	if [ "$ARG" != "modify" ]; then
		echo "/dev/${DRIVE_ID}${IDX},EF02,$SIZE,none,/none,ignore" >> $OUTPUT_SCHEME
	fi

	SECTORS=$(( $SIZE * $FACTOR ))
	echo "$START,$SECTORS,L" >> $TMP/fdisk-scheme

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
	echo "$START,$SECTORS,S" >> $TMP/fdisk-scheme

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
	echo "$START,+,E" >> $TMP/fdisk-scheme
	return 0
}

sizeup_partition_root()
{
	local IDX="$1"
	local SIZE="$2"
	local PERCENT=20
	local FS_MTPT="$3"
	local FS_TYPE="$4"

	if [ -z "$SIZE" ]; then SIZE=$DRIVE_SIZE; fi

	if [ -z "$FS_MTPT" ]; then FS_MTPT="/"; fi

	if [ "$SCHEME" = "root" ]; then

		if [ "$ARG" != "modify" ]; then
			FS_TYPE="$FSTYPE"
			SIZE=$(( $DRIVE_SIZE / 8 * 8 ))
			echo "/dev/${DRIVE_ID}${IDX},$PART_TYPE,$SIZE,$FS_TYPE,/,format" >> $OUTPUT_SCHEME
		fi
		echo ",+,$PT_TYPE" >> $TMP/fdisk-scheme
		return 0
	fi

	if [ "$ARG" = "modify" ]; then
		SECTORS=$(( $SIZE * $FACTOR - 2048 ))
	else
		FS_TYPE="$FSTYPE"
		PERCENT=$(get_percentage "$SCHEME" $FS_MTPT)
		SECTORS=$(( $DRIVE_SIZE * $PERCENT / 100 * $FACTOR / 8 * 8 - 2048 ))
		SIZE=$(( $DRIVE_SIZE * $PERCENT / 100 / 8 * 8 ))
		echo "/dev/${DRIVE_ID}${IDX},$PART_TYPE,$SIZE,$FS_TYPE,/,format" >> $OUTPUT_SCHEME
	fi
	echo ",$SECTORS,$PT_TYPE" >> $TMP/fdisk-scheme
	return 0
}

sizeup_partition_home()
{
	local IDX="$1"
	local SIZE="$2"
	local PERCENT=20
	local FS_MTPT="$3"
	local FS_TYPE="$4"

	if [ -z "$SIZE" ]; then SIZE=$DRIVE_SIZE; fi

	if [ "$ARG" = "modify" ]; then
		SECTORS=$(( $SIZE * $FACTOR - 2048 ))
	else
		FS_MTPT="/home"
		FS_TYPE="$FSTYPE"
		PERCENT=$(get_percentage "$SCHEME" $FS_MTPT)
		SECTORS=$(( $DRIVE_SIZE * $PERCENT / 100 * $FACTOR / 8 * 8 - 2048 ))
		SIZE=$(( $DRIVE_SIZE * $PERCENT / 100 / 8 * 8 ))
		echo "/dev/${DRIVE_ID}${IDX},$PART_TYPE,$SIZE,$FS_TYPE,$FS_MTPT,format" >> $OUTPUT_SCHEME
	fi

	echo ",+,$PT_TYPE" >> $TMP/fdisk-scheme

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

sizeup_partition_X()
{
	local IDX="$1"
	local SIZE="$2"
	local PERCENT=20
	local FS_MTPT="$3"
	local FS_TYPE="$4"

	if [ -z "$FS_TYPE" ]; then FS_TYPE="$FSTYPE"; fi

	if [ -z "$SIZE" ]; then SIZE=$DRIVE_SIZE; fi

	if [ "$ARG" = "modify" ]; then
		SECTORS=$(( $SIZE * $FACTOR - 2048 ))
	else
		PERCENT=$(get_percentage "$SCHEME" $FS_MTPT)
		SECTORS=$(( $SIZE * $PERCENT / 100 * $FACTOR / 8 * 8 - 2048 ))
		SIZE=$(( $SIZE * $PERCENT / 100 / 8 * 8 ))
		echo "/dev/${DRIVE_ID}${IDX},$PART_TYPE,$SIZE,$FS_TYPE,$FS_MTPT,format" >> $OUTPUT_SCHEME
	fi
	echo ",$SECTORS,$PT_TYPE" >> $TMP/fdisk-scheme
	return 0
}

# Main starts here ...
ARG="$1"
DEVICE="$(extract_value scheme 'device')"
DRIVE_ID="$(basename $DEVICE)"

OFFSET=0
START=2048
SECTORS=512000
FACTOR=$(( 1024000 / 512 )) # by the logical sector size

BIOS_SIZE=2 # 2 Megabytes
DUMMY_SIZE=256
MAX_PARTITIONS=0

if [ -z "$DEVICE" ]; then
	echo "INSTALLER: FAILURE L_NO_DEVICE_SPECIFIED"
	exit 1
fi

DISK_SIZE="$(sfdisk -s $DEVICE 2> /dev/null)"
DISK_SIZE=$(( $DISK_SIZE * 1024 / 1000000 ))

DRIVE_SSD="$(is_drive_ssd $DEVICE)"

unmount_devices "$DEVICE"

if test "$DISK_SIZE" -ge 750000 ; then # Probably a 4K drive
	DISK_SIZE="$(sfdisk -s $DEVICE 2> /dev/null)"
	DISK_SIZE=$(( $DISK_SIZE / 1024 * 1000 / 1024 ))
fi

SCHEME="$(extract_value scheme 'scheme')"
DISK_TYPE="$(extract_value scheme 'disk-type')"

if [ "$DISK_TYPE" != "lvm" -a "$DISK_TYPE" != "lvmcrypto" ]; then
	if [ "$SCHEME" = "lvm-10" -o "$SCHEME" = "lvm-breeze" ]; then
		echo "INSTALLER: FAILURE L_INVALID_LVM_DISKTYPE"
		exit 1
	fi
fi

cp -f $TMP/scheme.map $TMP/scheme-${DRIVE_ID}.map

FSTYPE="$(extract_value scheme 'fstype')"
GPT_MODE="$(extract_value scheme 'gpt-mode' 'upper')"
BOOT_SIZE="$(extract_value scheme 'boot-size')"
SWAP_SIZE="$(extract_value scheme 'swap-size')"
SECTOR_SIZE="$(extract_value scheme 'sector-size')"

if [ "$DISK_TYPE" = "lvm" -o "$DISK_TYPE" = "lvmcrypto" ]; then
	if keep_partitions "$DEVICE" "$DISK_TYPE" ; then
		DTYPE="$(echo $DISK_TYPE | tr '[:lower:]' '[:upper:]')"
		echo "INSTALLER: FAILURE L_CANNOT_KEEP_HOME_WITH_$DTYPE"
		exit 1
	fi
fi

OUTPUT_SCHEME=$TMP/partitions-${DRIVE_ID}.csv
OUTPUT_SECTORS=$TMP/sectors-${DRIVE_ID}.csv

if test "$DISK_SIZE" -gt 16000; then
	if [ "$GPT_MODE" != "MBR" -o "$DRIVE_SSD" = "yes" ]; then
		BIOS_SIZE=256
	fi
fi

RESERVED=$(( $BOOT_SIZE + $BIOS_SIZE + $SWAP_SIZE ))

if [ "$DISK_TYPE" = "lvm" -o "$DISK_TYPE" = "lvmcrypto" ]; then

	cp -f $TMP/scheme.map $TMP/scheme-${DISK_TYPE}.map

	# Replace swap primary partition by dummy one
	# Swap partition is to be part of the LVM store;
	# if an LVM drive is being prepared.
	RESERVED=$(( $BOOT_SIZE + $BIOS_SIZE + $DUMMY_SIZE ))

	# Force all LVM partitioning to the root scheme.
	# Use user specified scheme for logical volumes.
	SCHEME="root"
fi

if [ "$ARG" = "modify" ]; then
	if set_partition_names "$SCHEME" ; then
		modify_scheme "$OUTPUT_SCHEME"
	fi
	exit $?
fi

echo "$SCHEME" 1> $TMP/selected-scheme
echo "$GPT_MODE" 1> $TMP/selected-gpt-mode
echo "$DRIVE_ID" 1> $TMP/selected-drive-id
echo "$DISK_SIZE" 1> $TMP/drive-total
echo "$DISK_TYPE" 1> $TMP/selected-disktype
echo "$BOOT_SIZE" 1> $TMP/selected-boot-size
echo "$SWAP_SIZE" 1> $TMP/selected-swap-size
echo "$SECTOR_SIZE" 1> $TMP/sector-size

unlink "$OUTPUT_SCHEME" 2> /dev/null
touch "$OUTPUT_SCHEME" 2> /dev/null

#ASBOOT="$(extract_value scheme 'as-boot')"
#if [ "$ASBOOT" = "yes" ]; then
#	unlink $TMP/fstab 2> /dev/null
#	unlink $TMP/etc_fstab 2> /dev/null
#	unlink $TMP/root-device 2> /dev/null
#	unlink $TMP/boot-selected 2> /dev/null
#	echo "$DEVICE" 1> $TMP/selected-boot-drive
#fi

DEVIDX="$(grep -F "$DEVICE" $TMP/formatted-drives | cut -f2 -d'=')"

if [ -z "$DEVIDX" ]; then
	DEVIDX="$(wc -l "$TMP/formatted-drives" | cut -f1 -d' ')"
fi

if [ -z "$DEVIDX" ]; then
	DEVIDX="1"
else
	DEVIDX=$(( $DEVIDX + 1 ))
fi

echo "${DEVICE}=${DEVIDX}" >> $TMP/formatted-drives

DRIVE_SIZE=$(( $DISK_SIZE - $RESERVED ))
EXTENDED_SIZE=$DRIVE_SIZE

if set_partition_names "$SCHEME" ; then

	if sizeup_partitions "$SCHEME" "${DEVICE}" "${DISK_TYPE}" ; then
		wc -l "$OUTPUT_SCHEME" | cut -f1 -d' ' 1> $TMP/nb-partitions
		echo "INSTALLER: SUCCESS"
		exit 0
	fi
fi

echo "INSTALLER: FAILURE"
exit 1

# end Breeze::OS setup script
