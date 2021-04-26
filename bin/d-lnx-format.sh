#!/bin/bash
#
# GNU GENERAL PUBLIC LICENSE Version 3
#
# Copyright 2015, Pierre Innocent, Tsert Inc. All Rights Reserved
#
# Took hints from SeTpartitions from Slackware
#
# Initialize folder paths
. d-dirpaths.sh

. d-format-utils.sh

# make_f2fs( dev, sz ) - Create a F2FS filesystem on the named device
make_f2fs() {

	local check="$3"
	local rsrvd="$4"
	local label="$5"
	local SETL=""

	show_settings $1 f2fs $2

	if [ -n "$label" ]; then
		SETL="-l ${label:0:16}"
	fi

	echo "---------------- f2fs $1 -----------------" >> $TMP/format.errs

	mkfs.f2fs $SETL $1 1> /dev/null 2>> $TMP/format.errs
	#mkfs.f2fs $SETL -a 1 -o $rsrvd $1 1> /dev/null 2>> $TMP/format.errs

	return "$?"
}

# make_nilfs2( dev, sz ) - Create a NILFS2 filesystem on the named device
make_nilfs2() {

	local check="$3"
	local rsrvd="$4"
	local label="$5"
	local SETL=""

	show_settings $1 nilfs2 $2

	if [ "$check" = "y" ]; then
		check="-c"
	fi

	if [ -n "$label" ]; then
		SETL="-L ${label:0:32}"
	fi

	echo "---------------- nilfs2 $1 -----------------" >> $TMP/format.errs

	echo "y" | mkfs.nilfs2 $SETL -q -f -b 4096 -m $rsrvd $check $1 1> /dev/null 2>> $TMP/format.errs

	return "$?"
}

# make_xfs( dev, sz ) - Create a XFS filesystem on the named device
make_xfs() {

	local SETL=""
	local label="$5"

	show_settings $1 xfs $2

	if [ -n "$label" ]; then
		SETL="-L ${label:0:12}"
	fi

	echo "---------------- xfs $1 -----------------" >> $TMP/format.errs

	mkfs.xfs $SETL -q -f $1 1> /dev/null 2>> $TMP/format.errs

	return "$?"
}

# make_btrfs( dev, sz ) - Create a btrfs filesystem on the named device
make_btrfs() {

	local sectors="$SECTOR_SIZE"
	local label="$5"
	local SETL=""

	show_settings $1 btrfs $2

	if [ -n "$label" ]; then
		SETL="-L ${label:0:32}"
	fi

	echo "---------------- btrfs $1 -----------------" >> $TMP/format.errs

	SECTOR_SIZE="`extract_value scheme 'sector-size' 4096`"

	mkfs.btrfs -s $sectors -d single -m single $1 \
		1> /dev/null 2>> $TMP/format.errs

	return "$?"
}

# make_ext2( dev, sz, check ) - Create a ext2 filesystem on the named device
make_ext2() {

	local check="$3"
	local label="$5"
	local SETL=""

	show_settings $1 ext2 $2

	if [ "$check" = "y" ]; then
		check="-c"
	fi

	if [ -n "$label" ]; then
		SETL="-L ${label:0:16}"
	fi

	echo "---------------- ext2 $1 -----------------" >> $TMP/format.errs

	mkfs.ext2 $SETL $check $1 1> /dev/null 2>> $TMP/format.errs

	return "$?"
}

# make_ext3( dev, sz, check ) - Create a ext3 filesystem on the named device
make_ext3() {

	local check="$3"
	local rsrvd="$4"
	local label="$5"
	local SETL=""

	show_settings $1 ext3 $2

	if [ "$check" = "y" ]; then
		check="-c"
	fi

	if [ -n "$label" ]; then
		SETL="-L ${label:0:16}"
	fi

	echo "---------------- ext3 $1 -----------------" >> $TMP/format.errs

	mkfs.ext3 $SETL $check -q -j -m $rsrvd $1 1> /dev/null 2>> $TMP/format.errs

	return "$?"
}

# make_ext4( dev, sz, check ) - Create a ext4 filesystem on the named device
make_ext4() {

	local check="$3"
	local rsrvd="$4"
	local label="$5"
	local SETL=""

	show_settings $1 ext4 $2

	if [ "$check" = "y" ]; then
		check="-c"
	fi

	if [ -n "$label" ]; then
		SETL="-L ${label:0:16}"
	fi

	echo "---------------- ext4 $1 -----------------" >> $TMP/format.errs

	mkfs.ext4 $SETL $check -q -j -m $rsrvd -b $BLKSIZE $1 1> /dev/null 2>> $TMP/format.errs

	return "$?"
}

# make_dos( dev, sz, check ) - Create a DOS filesystem on the named device
make_dos() {

	local check="$3"
	local label="$5"
	local SETL=""

	show_settings $1 dos $2

	if [ "$check" = "y" ]; then
		check="-c"
	fi

	if [ -n "$label" ]; then
		SETL="-n ${label:0:11}"
	fi

	echo "---------------- dos $1 -----------------" >> $TMP/format.errs

	mkdosfs $SETFL $check -s 2 -F 32 $1 1> /dev/null 2>> $TMP/format.errs

	return "$?"
}

# make_vfat( dev, sz, check ) - Create a VFAT filesystem on the named device
make_vfat() {

	#local sectors="$SECTOR_SIZE"
	local check="$3"
	local label="$5"
	local SETL=""

	show_settings $1 vfat $2

	if [ "$check" = "y" ]; then
		check="-c"
	fi

	if [ -n "$label" ]; then
		SETL="-n ${label:0:11}"
	fi

	echo "---------------- vfat $1 -----------------" >> $TMP/format.errs

	mkfs.vfat $SETFL $check -F 32 $1 1> /dev/null 2>> $TMP/format.errs

	return "$?"
}

# make_jfs( dev, sz, check ) - Create a jfs filesystem on the named device
make_jfs() {

	local check="$3"
	local label="$5"
	local SETL=""

	show_settings $1 jfs $2

	if [ "$check" = "y" ]; then
		check="-c"
	fi

	if [ -n "$label" ]; then
		SETL="-L ${label:0:32}"
	fi

	echo "---------------- jfs $1 -----------------" >> $TMP/format.errs

	mkfs.jfs $SETL -q $check $1 1> /dev/null 2>> $TMP/format.errs

	return "$?"
}

# make_reiserfs( dev, sz ) - Create a reiserfs filesystem on the named device
#
make_reiserfs() {

	local SETL=""
	local label="$5"

	show_settings $1 reiserfs $2

	if [ -n "$label" ]; then
		SETL="-L ${label:0:16}"
	fi

	echo "---------------- reiserfs $1 -----------------" >> $TMP/format.errs

	echo "y" | mkfs.reiserfs $SETL -b $BLKSIZE -q $1 1> /dev/null 2>> $TMP/format.errs

	return "$?"
}

# make_reiser4( dev, sz ) - Create a reiser4 filesystem on the named device
#
make_reiser4() {

	local SETL=""
	local label="$5"

	show_settings $1 reiser4 $2

	if [ -n "$label" ]; then
		SETL="-L ${label:0:16}"
	fi

	echo "---------------- reiserfs4 $1 -----------------" >> $TMP/format.errs

	echo "y" | mkfs.reiser4 $SETL -b $BLKSIZE -q $1 1> /dev/null 2>> $TMP/format.errs

	return $?
}

do_format() {

	local device="$1"
	local mtpt="$2"
	local fstype="$3"
	local mode="$4"
	local partition="$2"
	local rsrvd="$RSRVD_BLKS"
	local check=""
	local label=""

	if [ -z "$rsrvd" ]; then rsrvd="0"; fi

	if [ "$mode" = "check" ]; then check="y"; fi

	local model="`lsblk -dno serial $SELECTED_DRIVE | crunch`"

	if [ -z "$model" ]; then
		model="`lsblk -dno model $SELECTED_DRIVE | crunch`"
	fi

	model="`echo "$model" | sed 's/^[^ ]*[ ]//g'`"

	if [ "$mtpt" = "/boot" ]; then
		label="BOOT_${model}"
	elif [ "$mtpt" = "/" ]; then
		label="ROOT_${model}"
		partition="/ or root"
	fi

	echo "INSTALLER: MESSAGE L_FORMATTING_X_PARTITION((partition,$partition))"
	sync

	echo "$device" >> $TMP/formatted-partitions

	make_${fstype} "$device" "$mtpt" "$check" "$rsrvd" "$label"

#	if [ "$DRIVE_SSD" = "yes" ]; then
#		if echo "$fstype" | grep -qE "vfat|ext4|xfs" ; then
#			tune2fs -o discard $1
#		fi
#	fi

	sync

	return $?
}

do_format_root_device() {

	local device="$1"
	local mtpt="$2"
	local fstype="$3"

	do_format "$device" "$mtpt" "$3" "$4"

	if [ "$?" = 0 ]; then

		umount $device 2>> $TMP/umount.errs

		for fs in $fstype $FILESYSTEMS; do
			if mount -t $fs $device $ROOTDIR &> /dev/null; then
				FS_TYPE="$fs"
				sleep_one_second
				break
			fi
			sleep_one_second
		done

		sync

		FS_TYPE="`lsblk -n -l -o 'fstype' $device | crunch`"

		# For LVM volumes, we may have to use the device node that is exposed
		# by the devicemapper, instead of the LVM device node:
		#
		if [ -z "$FS_TYPE" ]; then
			VG="`echo "$device" | cut -f3 -d'/'`"
			LV="`echo "$device" | cut -f4 -d'/'`"
			FS_TYPE=`mount | grep -m1 -E "^/dev/mapper/$VG-$LV on " | cut -f5 -d' '`
		fi

		if [ ! -f "$TMP/etc_fstab" ]; then
			echo -n "$device" 1> "$TMP/root-device"
			write_fstab $device $mtpt $FS_TYPE "1"
		fi
	fi
	return $?
}

#---------------------------------------------------------------------------
# Main starts here ...
#---------------------------------------------------------------------------

DEVIDX=""
FS_TYPE=""
FORMAT_MODE="$1"
FORMAT_SCHEME=$TMP/format.csv
FILESYSTEMS="dos vfat ext2 ext3 ext4 reiserfs jfs xfs f2fs nilfs2"
SMACK_ENABLED="`cat $TMP/selected-smack 2> /dev/null`"
DRIVE_TOTAL="`cat $TMP/drive-total 2> /dev/null`"

SELECTED_DRIVE="`cat $TMP/selected-drive 2> /dev/null`"
DRIVE_ID="`basename $SELECTED_DRIVE`"
DRIVE_SSD="`is_drive_ssd $SELECTED_DRIVE`"

touch $TMP/mt.errs 2> /dev/null
touch $TMP/fstab 2> /dev/null
touch $TMP/umount.errs 2> /dev/null

unlink $TMP/format.errs 2> /dev/null
touch $TMP/format.errs 2> /dev/null

DISK_TYPE="`extract_value scheme 'disk-type'`"
FSTAB_ALL="`extract_value scheme 'fstab-all'`"
RSRVD_BLKS="`extract_value scheme 'reserved'`"
SECTOR_SIZE="`extract_value scheme 'sector-size' 4096`"
GPT_MODE="`extract_value scheme 'gpt-mode' 'upper'`"
BLKSIZE="`extract_value scheme 'block-size' 4096`"

if [ -f "$TMP/etc_fstab" ]; then
	DEVIDX="`grep -F "$SELECTED_DRIVE" $TMP/formatted-drives | cut -f2 -d'='`"
	#DEVIDX="`wc -l "$TMP/formatted-drives" | cut -f1 -d' '`"
fi

if [ "$DISK_TYPE" = "lvm" -o "$FORMAT_MODE" = "lvm" ]; then
	vgchange -ay
	cp "$TMP/lvm.csv" $FORMAT_SCHEME
else
	cp $TMP/partitions-${DRIVE_ID}.csv $FORMAT_SCHEME
fi

if [ "$SMACK_ENABLED" = "yes" -a ! -s "$TMP/etc_fstab" ]; then
	echo "smackfs /smack smackfs smackfsdef=* 0 0" 1> "$TMP/fstab"
fi

echo "no" 1> $TMP/${DRIVE_ID}-formatted

if [ ! -f "$FORMAT_SCHEME" ]; then
	echo "INSTALLER: FAILURE L_INVALID_FORMAT_INFO"
	exit 1
fi

if ! grep -q -m1 -F ',/,' "$FORMAT_SCHEME" ; then
	echo "INSTALLER: FAILURE L_INVALID_FORMAT_INFO"
	exit 1
fi

unmount_devices "$SELECTED_DRIVE"

reorder_rootfs "$FORMAT_SCHEME"

while read line; do

	DEVICE="`echo "$line" | cut -f 1 -d','`"
	PTYPE="`echo "$line" | cut -f 2 -d','`"
	SIZE="`echo "$line" | cut -f 3 -d','`"
	FSTYPE="`echo "$line" | cut -f 4 -d','`"
	MTPT="`echo "$line" | cut -f 5 -d','`"
	MODE="`echo "$line" | cut -f 6 -d','`"

#	if [ "$PTYPE" = "8E00" -o "$PTYPE" = "8e00" ]; then
#		lvchange -a n $DEVICE
#	fi

	echo "INSTALLER: PROGRESS ((device,$DEVICE),(mountpoint,$MTPT),(filesystem,$FSTYPE))"

	if [ "$PTYPE" = "8200" -o "$PTYPE" = "82" -o "$FSTYPE" = "swap" ]; then
		activate_swap "$DEVICE"
		write_fstab $DEVICE "swap" "swap" "0"
		continue
	fi

	if [ "$MODE" = "skip" -o "$MODE" = "keep" ]; then
		set_mountpoint "$line"
		continue
	fi

	if [ "$MODE" = "ignore" ]; then
		continue
	fi

	if [ "$MTPT" = "/" -a -z "$DEVIDX" ]; then
		do_format_root_device "$DEVICE" "$MTPT" "$FSTYPE" "$MODE"
	else
		do_format "$DEVICE" "$MTPT" "$FSTYPE" "$MODE"
	fi

	if [ "$?" != 0 ]; then
		echo "INSTALLER: FAILURE L_FORMATTING_FAILED"
		exit 1
	fi

	if [ "$MTPT" != "/" -a "$MTPT" != "/swap" ]; then
		set_mountpoint "$line"
	fi
done < "$FORMAT_SCHEME"

if [ -f "$TMP/etc_fstab" ]; then
	cat $TMP/fstab >> $TMP/etc_fstab
else
	if [ -s $TMP/formatted-partitions ]; then

		d-list-drives.sh all 1> /dev/null 2> /dev/null

		while read line; do

			device="/dev/`echo "$line" | cut -f 1 -d' '`"

			if ! grep -q -F "$device" $TMP/formatted-partitions ; then

				removable="`echo "$line" | cut -f 2 -d' '`"

				if [ "$removable" = "1" ]; then
					continue
				fi

				fstype="`echo "$line" | cut -f 4 -d' '`"

				if echo "$FILESYSTEMS" | grep -q -F "$fstype" ; then
					uuid="`echo "$line" | cut -f 5 -d' '`"
					mtpt="/mnt/hd/`basename $device`"
					write_fstab "$device" "$mtpt" "$fstype" "2" "$uuid"
					mkdir -p $ROOTDIR/$mtpt
				fi
			fi
		done < $TMP/fstab-all
	fi
	add_fstab_cdrom
fi

echo "yes" 1> $TMP/${DRIVE_ID}-formatted
exit 0

# end Breeze::OS script
