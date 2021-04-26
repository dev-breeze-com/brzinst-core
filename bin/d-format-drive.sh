#!/bin/bash
#
# GNU GENERAL PUBLIC LICENSE Version 3
#
# SeTpartitions modified by <dev@tsert.com> now d-format-drive.sh
# Copyright 2015, Pierre Innocent, Tsert Inc. All Rights Reserved
#
# SeTpartitions user-friendly rewrite Fri Dec 15 13:17:40 CST 1995 pjv
# Rewrite to support filesystem plugins <david@slackware.com>, 07-May-2001
# Don't use plugins, make it work, pjv, 18-May-2001.
# Generalize tempscript creation and support JFS and XFS. pjv, 30-Mar-2002
#
# Initialize folder paths
. d-dirpaths.sh

FSTYPE="`cat $TMP/selected-fstype 2> /dev/null`"
DERIVED="`cat $TMP/selected-derivative 2> /dev/null`"
RELEASE="`cat $TMP/selected-release 2> /dev/null`"

SECTOR_SIZE="`cat $TMP/sector-size 2> /dev/null`"
SMACK_ENABLED="`cat $TMP/selected-smack 2> /dev/null`"
SELECTED_DRIVE="`cat $TMP/selected-drive 2> /dev/null`"
SELECTED_DEVICE="`cat $TMP/selected-device 2> /dev/null`"
SELECTED_SCHEME="`cat $TMP/selected-scheme 2> /dev/null`"

show_settings() {

	local device="$1"
	local fstype="$2"
	local mtpt="$3"
	local size="`lsblk -n -o 'size' $device | crunch`"

	dialog --colors \
		--backtitle "Breeze::OS $RELEASE Installer" \
		--title "Breeze::OS Setup -- Formatting ($device)" \
		--infobox "\n\Z1Device Name\Zn = $device\n\Z1Partition\Zn   = $size\n\Z1Filesystem\Zn  = $fstype\n\Z1Mount Path\Zn  = $mtpt\n" 8 65

	umount $device 2> /dev/null
	sleep 1

	return 0
}

# write_fstab( dev, mtpt, fstype, fsdump_order )
write_fstab() {

	local DEVICE="$1"
	local MTPT="$2"
	local FSTYPE="$3"
	local ORDER="$4"
	local OPTIONS="defaults"

	UUID="`lsblk -n -l -o 'uuid' $DEVICE`"

	if [ "$FSTYPE" = "vfat" ]; then
		OPTIONS="uni_xlate,defaults"

	elif [ "$FSTYPE" = "reiserfs" -o "$FSTYPE" = "reiserfs4" ]; then
		if [ "$MTPT" = "/" ]; then
			OPTIONS="notail,barrier=flush"
		else
			OPTIONS="notail,noatime,barrier=flush"
		fi
	fi

	echo "# $DEVICE was mounted on $MTPT during installation" >> $TMP/fstab
	printf "UUID=%-36s %-16s %-10s %-16s %s %s\n" \
		"$UUID" "$MTPT" "$FSTYPE" "$OPTIONS" "1" "$ORDER" >> $TMP/fstab
	echo "" >> $TMP/fstab

	return 0
}

# make_xfs( dev, sz ) - Create a xfs filesystem on the named device
make_xfs() {
	show_settings $1 xfs $2
	mkfs.xfs -f $1 1> /dev/null 2> /dev/null
	return "$?"
}

# make_btrfs( dev, sz ) - Create a btrfs filesystem on the named device
make_btrfs() {
	show_settings $1 btrfs $2
	mkfs.btrfs -d single -m single $1 1> $REDIR 2> $REDIR
	return "$?"
}

# make_ext2( dev, sz, check ) - Create a ext2 filesystem on the named device
make_ext2() {

	show_settings $1 ext2 $2

	if [ "$3" = "y" ]; then
		mkfs.ext2 -c $1 1> /dev/null 2> $TMP/errors
	else
		mkfs.ext2 $1 1> /dev/null 2> $TMP/errors
	fi
	return "$?"
}

# make_ext3( dev, sz, check ) - Create a ext3 filesystem on the named device
make_ext3() {

	show_settings $1 ext3 $2

	if [ "$3" = "y" ]; then
		mkfs.ext3 -j -c $1 1> /dev/null 2> $TMP/errors
	else
		mkfs.ext3 -j $1 1> /dev/null 2> $TMP/errors
	fi
	return "$?"
}

# make_ext4( dev, sz, check ) - Create a ext4 filesystem on the named device
make_ext4() {

	show_settings $1 ext4 $2

	if [ "$3" = "y" ]; then
		mkfs.ext4 -j -c $1 1> $TMP/success.log 2> $TMP/errors
	else
		mkfs.ext4 -j $1 1> $TMP/success.log 2> $TMP/errors
	fi
	return "$?"
}

# make_vfat( dev, sz, check ) - Create a ext2 filesystem on the named device
make_vfat() {

	show_settings $1 vfat $2

	if [ "$3" = "y" ]; then
		mkfs.vfat -F 32 -c $1 1> /dev/null 2> $TMP/errors
	else
		mkfs.vfat -F 32 $1 1> /dev/null 2> $TMP/errors
	fi
	return "$?"
}

# make_jfs( dev, sz, check ) - Create a jfs filesystem on the named device
make_jfs() {

	show_settings $1 jfs $2

	if [ "$3" = "y" ]; then
		mkfs.jfs -c $1 1> /dev/null 2> $TMP/errors
	else
		mkfs.jfs $1 1> /dev/null 2> $TMP/errors
	fi
	return "$?"
}

# make_reiserfs( dev, sz ) - Create a reiserfs filesystem on the named device
#
make_reiserfs() {
	show_settings $1 reiserfs $2
	echo "y" | mkfs.reiserfs -q $1 1> $TMP/success.log 2> $TMP/errors
	return "$?"
}

# make_reiser4( dev, sz ) - Create a reiser4 filesystem on the named device
#
make_reiser4() {
	show_settings $1 reiser4 $2
	echo "y" | mkfs.reiser4 -q $1 1> /dev/null 2> $TMP/errors
	return $?
}

# ask_format( dev ) - Asks the user if he/she wants to format the named device
ask_format() {

	local device="$1"

	DO_FORMAT=""

	dialog --colors \
		--backtitle "Breeze::OS $RELEASE Installer." \
		--title "Breeze::OS Setup -- Format partition $device" \
		--menu "\nIf this partition is not formatted, you should format it. \
Remember that enough space must be present for installation if you choose, \
not to format the partition.\n\n\
    N.B. \Z1Formatting will erase all data on partition $device\Zn.\n\n\
Would you like to format this partition ?" 18 70 4 \
   "No" "Do not format this partition" \
   "Format" "Quick format with no bad block checking" \
   "Check" "Slow format that checks for bad blocks" \
   "Skip" "The OS will ignore this partition." 2> $TMP/retcode

	if [ "$?" != 0 ]; then
		exit 1
	fi

	DO_FORMAT="`cat $TMP/retcode`"

	if [ "$DO_FORMAT" = "Skip" ]; then
		return 1
	fi
	return 0
}

# ask_nodes( dev ) - Asks the user for the inode density for the named device.
#ask_nodes() {
#
#	dialog --colors \
#		--backtitle "Breeze::OS $RELEASE Installer." \
#		--title "SELECT INODE DENSITY FOR PARTITION $1" \
#		--default-item "4096" \
#		--menu "\nIf you know what your are doing; you can change the \Z1default\Zn density to one inode (file object) per 1024 or 2048 bytes.\n\n\
#Which inode setting would you like (recommended \Z14096\Zn) ?" 14 70 3 \
#   "1024" "1 inode per 1024 bytes" \
#   "2048" "1 inode per 2048 bytes" \
#   "4096" "1 inode per 4096 bytes" 2> $TMP/retcode
#
#	if [ "$?" != 0 ]; then
#		unlink $TMP/retcode 2> /dev/null
#		exit 1
#	fi
#}

strip_ptype() {
	read ptype
	ptype="`echo "$ptype" | sed -r 's/^.//'`"
	ptype="`echo "$ptype" | sed -r 's/.$//'`"
	echo "$ptype"
}

# ask_fs( dev ) - Asks the user the type of filesystem to use for the named
#                 device. Answer in $TMP/retcode
ask_fs() {

	unset VFAT EXT2 EXT3 EXT4 REISERFS REISERFS4 BTRFS JFS XFS

	FS_TYPE="$FSTYPE"

	if [ "$1" = "/efi" -o "$1" = "/boot/efi" ]; then
		FS_TYPE="vfat"
		return 0
	fi

	VFAT="\Z1VFAT\Zn is the traditional Microsoft file system."
	EXT2="\Z1Ext2\Zn is the traditional Linux filesystem."
	EXT3="\Z1Ext3\Zn is the journaling version of the Ext2 filesystem."
	EXT4="\Z1Ext4\Zn is the successor to the Ext3 filesystem."
	REISERFS="\Z1ReiserFS\Zn is a journaling filesystem using only B-trees."
	JFS="\Z1JFS\Zn is IBM's journaling filesystem, used in enterprise servers."
#	REISERFS4="\Z1ReiserFS4\Zn is the new version of the reiserFS filesystem."
#	BTRFS="\Z1BTRFS\Zn is a new B-tree copy-on-write filesystem."
#	XFS="\Z1XFS\Zn is SGI's journaling filesystem that originated on IRIX. "

	cat << EOF > $TMP/tempscript
	dialog --colors \\
		--backtitle "Breeze::OS $RELEASE Installer" \\
		--title "Breeze::OS Setup -- Formatting ($device)" \\
		--default-item "ext4" \\
		--menu \\
"\n$VFAT\n$EXT2\n$EXT3\n$EXT4\n$REISERFS\n$JFS\n$XFS\n\\
Filesystems \Z1ReiserFS\Zn and \Z1Ext4\Zn are recommended.\n\n\\
Select the filesystem for partition \Z1$DEVICE\Zn !" \\
17 70 0 \\
EOF
	if [ "$REISERFS" != "" ]; then
		echo "\"reiserfs\" \"Reiser's Journaling Filesystem (v3)\" \\" \
			>> $TMP/tempscript
	fi
	if [ "$EXT4" != "" ]; then
		echo "\"ext4\" \"Successor of the ext3fs filesystem\" \\" \
			>> $TMP/tempscript
	fi
	if [ "$EXT3" != "" ]; then
		echo "\"ext3\" \"Journaling version of the ext2fs filesystem\" \\" \
			>> $TMP/tempscript
	fi
	if [ "$EXT2" != "" ]; then
		echo "\"ext2\" \"Standard Linux ext2fs filesystem\" \\" \
			>> $TMP/tempscript
	fi
	if [ "$REISERFS4" != "" ]; then
		echo "\"reiserfs4\" \"Reiser's Journaling Filesystem (v4)\" \\" \
			>> $TMP/tempscript
	fi
	if [ "$VFAT" != "" ]; then
		echo "\"vfat\" \"VFAT Microsoft Filesystem\" \\" \
			>> $TMP/tempscript
	fi
	if [ "$BTRFS" != "" ]; then
		echo "\"btrfs\" \"B-tree Copy-on-Write Filesystem\" \\" \
			>> $TMP/tempscript
	fi
	if [ "$JFS" != "" ]; then
		echo "\"jfs\" \"IBM's Journaled Filesystem\" \\" \
			>> $TMP/tempscript
	fi
	if [ "$XFS" != "" ]; then
		echo "\"xfs\" \"SGI's Journaling Filesystem\" \\" \
			>> $TMP/tempscript
	fi

	echo "2> $TMP/retcode" >> $TMP/tempscript

	. $TMP/tempscript

	if [ "$?" != 0 ]; then
		unlink $TMP/retcode 2> /dev/null
		exit 1
	fi

	FS_TYPE="`cat $TMP/retcode`"
	return 0
}

do_format() {

	local device="$1"
	local mtpt="$2"
	local check="n"

	ask_format $device

	if [ "$DO_FORMAT" = "Skip" ]; then
		return 1
	fi

	if [ "$DO_FORMAT" = "No" ]; then
		return 0
	fi

	if [ "$DO_FORMAT" = "Check" ]; then
		check="y"
	fi

	ask_fs $device $FSTYPE

	if [ "$FS_TYPE" = "vfat" ]; then
		make_vfat $device "$mtpt" $check

	elif [ "$FS_TYPE" = "ext2" ]; then
		make_$FS_TYPE $device "$mtpt" $checK

	elif [ "$FS_TYPE" = "ext3" -o "$FS_TYPE" = "ext4" ]; then
		make_$FS_TYPE $device "$mtpt" $check

	elif [ "$FS_TYPE" = "reiserfs" ]; then
		make_reiserfs $device "$mtpt" $check

	elif [ "$FS_TYPE" = "reiserfs4" ]; then
		make_reiser4 $device "$mtpt" $check

	elif [ "$FS_TYPE" = "btrfs" ]; then
		make_btrfs $device "$mtpt" $check

	elif [ "$FS_TYPE" = "jfs" ]; then
		make_jfs $device "$mtpt" $check

	elif [ "$FS_TYPE" = "xfs" ]; then
		make_xfs $device "$mtpt" $check
	fi
	return $?
}

do_format_root_device() {

	local device="$1"
	local mtpt="$2"

	do_format "$device" "$mtpt"

	if [ "$DO_FORMAT" = "Skip" ]; then

		dialog --colors \
			--backtitle "Breeze::OS $RELEASE Installer" \
			--title "Breeze::OS Setup -- Formatting ($device)" \
			--msgbox "\nCannot ignore the root partition. Try again !\n" 7 65

		do_format "$device" "$mtpt"
	fi

	dialog --colors \
		--backtitle "Breeze::OS $RELEASE Installer" \
		--title "Breeze::OS Setup -- Checking drive path" \
		--infobox "\nPlease wait, accessing $DEVICE ...\n" 5 45

	# If we didn't format the partition,
	# then we don't know what fs type it is.
	# So, we will try the types we know about, and
	# let mount figure it out, if all else fails:
	#
	umount $device 2> /dev/null

	for fs in $FS_TYPE $FILESYSTEMS; do
		if mount -t $fs $device $ROOTDIR &> /dev/null; then
			FS_TYPE="$fs"
			sleep 1
			break
		fi
		sleep 1
	done

	FS_TYPE="`lsblk -n -l -o 'fstype' $device`"

	# For LVM volumes, we may have to use the device node that is exposed
	# by the devicemapper, instead of the LVM device node:
	#
	if [ -z "$FS_TYPE" ]; then
		VG="`echo "$device" | cut -f3 -d'/'`"
		LV="`echo "$device" | cut -f4 -d'/'`"
		FS_TYPE=`mount | grep -E "^/dev/mapper/$VG-$LV on " | cut -f5 -d' '`
	fi

	if [ ! -f "$TMP/etc_fstab" ]; then
		echo -n "$device" 1> "$TMP/root-device"
		write_fstab $DEVICE $MTPT $FS_TYPE "1"
	fi
	return 0
}

set_mountpoint() {
	
	local device="`echo "$1" | cut -f 1 -d ':'`"
	local ptype="`echo "$1" | cut -f 2 -d ':'`"
	local size="`echo "$1" | cut -f 3 -d ':'`"
	local mtpt="`echo "$1" | cut -f 4 -d ':'`"
	local fstype="`echo "$1" | cut -f 5 -d ':'`"
	
	if [ "$ptype" = "8200" ]; then
		write_fstab $device "swap" "swap" "0"
		return 0
	fi

	mkdir -p $ROOTDIR/$mtpt 2> /dev/null

	if [ "$mtpt" = "/efi" -o "$mtpt" = "/boot/efi" ]; then
		mkdir -p $ROOTDIR/$mtpt/EFI 2> /dev/null
	fi

	if [ "$mtpt" = "/boot" -o "$mtpt" = "/efi" -o "$mtpt" = "/boot/efi" ]; then
		if [ ! -f $TMP/boot-selected ]; then 
			echo "$device,$mtpt" 1> $TMP/boot-selected
		fi
	fi

	dialog --colors \
		--backtitle "Breeze::OS $RELEASE Installer" \
		--title "Breeze::OS Setup -- Checking drive path" \
		--infobox "\nPlease wait, accessing $device ...\n" 5 45

	for fs in $fstype $FILESYSTEMS; do
		mount -t $fs $device $ROOTDIR/$mtpt 1> /dev/null 2>&1
	
		if [ "$?" = 0 ]; then
			fstype="$fs"
			sleep 1
			break
		fi
		sleep 1
	done
	
	FS_TYPE="`mount | grep -E "^$device on " | cut -f5 -d ' '`"
	write_fstab $device $mtpt $FS_TYPE "2"

	return 0
}
	
#---------------------------------------------------------------------------
# Main starts here ...
# Before probing, activate any LVM partitions
# that may exist from before the boot:
#---------------------------------------------------------------------------

vgchange -ay 1> $TMP/lvm.log 2> $TMP/lvm.err

touch $TMP/fstab 2> /dev/null
umount $ROOTDIR 2> /dev/null

PARTNO=0
DEVIDX=""
FS_TYPE=""
DO_FORMAT=""
FILESYSTEMS="ext4 reiserfs vfat jfs xfs f2fs nilfs2 ext3 ext2"

unlink "$TMP/selected-newscheme" 2> /dev/null
touch "$TMP/selected-newscheme" 2> /dev/null

#if [ "$SMACK_ENABLED" = "yes" -a ! -s "$TMP/etc_fstab" ]; then
#	echo "smackfs /smack smackfs smackfsdef=* 0 0" 1> "$TMP/fstab"
#fi

#if [ -f "$TMP/etc_fstab" ]; then
#	DEVIDX="`grep -F "$DEVICE" $TMP/formatted-drives | cut -f2 -d'='`"
#	#DEVIDX="`wc -l "$TMP/formatted-drives" | cut -f1 -d' '`"
#fi

# Format all partitions ...
#
while read line; do

	DEVICE="`echo "$line" | cut -f 1 -d ':'`"
	PTYPE="`echo "$line" | cut -f 2 -d ':'`"
	SIZE="`echo "$line" | cut -f 3 -d ':'`"
	MTPT="`echo "$line" | cut -f 4 -d ':'`"
	FSTYPE="`echo "$line" | cut -f 5 -d ':'`"
	MODE="`echo "$line" | cut -f 6 -d ':'`"
	DEVIDX="`grep -F "$DEVICE" $TMP/formatted-drives | cut -f2 -d'='`"

	if [ "$PTYPE" = "8200" ]; then

		if cat $TMP/swap-activated | grep -q -F "$DEVICE" ; then
			d-activate-swap.sh $DEVICE
		fi

		echo "$DEVICE:$PTYPE:$SIZE:$MTPT:swap" >> $TMP/selected-newscheme
		write_fstab $DEVICE "swap" "swap" "0"
		continue
	fi

	d-select-mount.sh "CHECK" "$DEVICE" "$PTYPE" "$MTPT" "$SIZE"

	if [ "$?" = 0 ]; then
		if [ "$MTPT" = "/" -a -z "$DEVIDX" ]; then
			do_format_root_device "$DEVICE" "$MTPT"
		else
			do_format "$DEVICE" "$MTPT$DEVIDX"
		fi
		echo "$DEVICE:$PTYPE:$SIZE:$MTPT:$FS_TYPE" >> $TMP/selected-newscheme
	fi
done < "$TMP/selected-scheme"

# Select mount points for all partitions ...
#
while read line; do
	MTPT="`echo "$line" | cut -f 4 -d ':'`"
	if [ "$MTPT" != "/" -a "$MTPT" != "/swap" ]; then
		set_mountpoint "$line"
	fi
done < $TMP/selected-newscheme

if [ -f "$TMP/etc_fstab" ]; then
	/bin/cat $TMP/fstab >> $TMP/etc_fstab
else
	while read line; do

		DEVICE="`echo "$line" | cut -f1 -d ' '`"
		MTPT="`echo "$line" | cut -f2 -d ' '`"

		echo "# $DEVICE was mounted on $MTPT during installation" >> $TMP/fstab
		printf "%-12s %-20s %-12s %-28s %s %s\n" "$DEVICE" "$MTPT" \
			"udf,iso9660" "user,noauto,ro,unhide,utf8" "0" "0" >> $TMP/fstab
		echo "" >> $TMP/fstab

	done < $TMP/detected-cdroms

	echo "# /dev/fd0 mounted on /media/floppy0" >> $TMP/fstab
	printf "%-12s %-20s %-12s %-28s %s %s\n" "/dev/fd0" "/media/floppy0" \
		"auto" "rw,user,noauto" "0" "0" >> $TMP/fstab
	echo "" >> $TMP/fstab

	/bin/cat $TMP/fstab 1> $TMP/etc_fstab
fi

d-show-partitions.sh false fstab "$SELECTED_DRIVE"

exit 0

# end Breeze::OS script
