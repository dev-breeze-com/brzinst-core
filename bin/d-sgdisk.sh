#!/bin/bash
#
# GNU GENERAL PUBLIC LICENSE Version 3

lastsz=""
keep_partitions=""

drive="$(cat $TMP/selected-drive 2> /dev/null)"
sector_size="$(cat $TMP/sector-size 2> /dev/null)"
#gpt_type="$(cat $TMP/selected-gpt-type 2> /dev/null)"
mbrdrive="$(cat $TMP/drive-is-mbr-partitioned 2> /dev/null)"

alignment=$(( 2048 * $sector_size ))

# Try to save partition table ...
sgdisk --save ... 1> $TMP/$(basename $drive).fstable

# Convert mbr drive to gpt ...
if [ "$mbrdrive" = "yes" ]; then
	sgdisk --mbrtogpt $drive 2> /dev/null
fi

# If Windows is to boot from a GPT disk,
# a partition of type Microsoft Reserved
# (sgdisk internal code 0x0C01) is recommended
# GPT fdisk Manual (8)

while read line; do

	mode="$(echo "$line" | cut -f6 -d',')"
	partnb="$(echo "$line" | cut -f1 -d',')"
	partnb="$(echo "$partnb" | sed 's/[a-z\/]*//g')"

	if [ "$mode" = "keep" ]; then
		keep_partitions="$keep_partitions $partnb"
	else
		sgdisk --delete=$partnb 2> $TMP/sgdisk.err

		if [ "$?" != 0 ]; then
			echo "FAILURE TIP_PARTITION_DELETE_ERROR"
			exit 1
		fi
	fi
done < $TMP/keep-partitions.csv

while read line; do
	device="$(echo "$line" | cut -f1 -d',')"
	partnb="$(echo "$device" | sed 's/[a-z\/]*//g')"

	size="$(echo "$line" | cut -f3 -d',')"
	mode="$(echo "$line" | cut -f6 -d',')"

	if [ "$mode" != "keep" ]; then

		ptype="$(echo "$line" | cut -f2 -d',')"
		mtpt="$(echo "$line" | cut -f5 -d',')"

		# Partition size - 2048 sector alignment
		size=$(( $size - $alignment ))

		sgdisk --set-alignment=2048 \
			--new=${partnb}:0:+${size} \
			--typecode=${partnb}:0x${ptype} 2> $TMP/sgdisk.err

		if [ "$?" != 0 ]; then
			echo "FAILURE TIP_FORMATTING_ERROR"
			exit 1
		fi

		if [ "$mtpt" = "/" ]; then
			# Required by syslinux
			sgdisk -A ${partnb}:set:2 $device
		fi

		if [ "$?" != 0 ]; then
			echo "FAILURE TIP_FORMATTING_ERROR"
			exit 1
		fi
	fi
done < $TMP/partitioning.csv

echo "SUCCESS"

exit 0

