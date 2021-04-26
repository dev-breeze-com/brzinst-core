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
if [ "$EUID" -gt 0 ]; then
	echo "d-update-bootcfg.sh: execute only as root !"
	exit 1
fi

DATE=$(date -I)

IS_ON=/bin/true

if [ -e /etc/init.d/functions.sh ]; then
	. /etc/init.d/functions.sh
elif [ -e /etc/init.d/functions ]; then
	. /etc/init.d/functions
fi

function crunch()
{
    read answer
    echo $answer
    return 0
}

function umount_device()
{
	if [ -e /var/tmp/chrooted -a ! -z "$BOOT_DEV" ]; then
		if [ "$ROOT_DEV" != "$BOOT_DEV" ]; then
			umount $BOOT_DEV
		fi
	fi

	while [ "$?" = 0 ] ; do
		umount /dev/tmpfs 
	done

	unlink $TMP/initrd.images 2> /dev/null
	unlink $TMP/boot-partitions 2> /dev/null
	unlink $TMP/vmlinuzes 2> /dev/null

	return 0
}

function is_module_loaded()
{
	if lsmod | grep -qF "$1" ; then
		return 0
	fi
	return 1
}

function set_efibootmgr()
{
	local mode="$1"
	local device="$2"
	local ARCH="$3"
	local arch="$4"

	efibootmgr --create --gpt --disk ${device} --part 1 \
		--write-signature --label "BreezeOS" \
		--loader "\\EFI\\BOOT\\BOOT${ARCH}.EFI"

	if [ "$mode" = "syslinux" ]; then

		cp -a /usr/share/syslinux/efi${arch}/syslinux.efi \
			/boot/efi/EFI/BOOT/BOOT${ARCH}.EFI

	elif [ "$mode" = "gummiboot" ]; then

		cp -a /usr/share/syslinux/efi${arch}/syslinux.efi \
			/boot/efi/EFI/BOOT/BOOT${ARCH}.EFI

	elif [ "$mode" = "grub" ]; then

		grub2-install --efi-directory=/boot/efi --target efi-${arch} ${device}

		cp -a /boot/efi/EFI/factory/grubx${arch}.efi \
			/boot/efi/EFI/BOOT/BOOT${ARCH}.EFI
	fi
	return 0
}

function load_efivars()
{
	# To prevent inconsistencies, before accessing the EFI VAR data
	modprobe -r efivars
	umount /sys/firmware/efi/efivars
	sync
	modprobe -r efivarfs
	modprobe efivarfs
	mount -t efivarfs efivarfs /sys/firmware/efi/efivars

	return $?
}

function extract_version()
{
	local kernel="$1"

	kernel="$(basename "$kernel")"

	if [ "$kernel" = "vmlinuz" -o "$kernel" = "vmlinuz.old" ]; then
		echo ""
		return 1
	fi

	if echo "$kernel" | egrep -q '^vmlinuz[-](x86|amd64)' ; then
		kernel="$(echo "$kernel" | sed -r 's/vmlinuz[-](x86[-]|amd64[-])?//g')"
	else
		kernel="$(echo "$kernel" | sed -r 's/^[^0-9]*//g')"
	fi

	if [ -z "$kernel" ]; then
		kernel="$(echo "$kernel" | sed -r 's/^.*vmlinuz[-]//g')"
	fi

	if [ -z "$kernel" ]; then
		echo ""
		return 1
	fi
	echo "$kernel"
	return 0
}

function find_initrd()
{
	local kernel="$1"
	local pattern="$(echo "$1" | sed 's/[-]/[-]/g')"

	INITRD="$(grep -E -m1 "(initrd.img|initramfs)[-]$pattern[.]gz" $TMP/initrd.images)"

	if [ -n "$INITRD" -a -f "$INITRD" ]; then
		#echo "$pattern"
		#echo "$INITRD"
		return 0
	fi

	INITRD="$(grep -E -m1 "(initrd.img|initramfs).*$pattern$" $TMP/initrd.images)"

	if [ -n "$INITRD" -a -f "$INITRD" ]; then
		return 0
	fi
	return 1
}

function create_initrd()
{
	local kernel="$1"

	if [ -z "$ROOT_FS" -o -z "$BOOT_FS" ]; then
		echo "Error: rootfs and bootfs must be specified !"
		exit 1
	fi

	echo "[1;36;40mCreating initrd for kernel $kernel ...[0m"

	MODULES="scsi_mod:sd_mod:sr_mod:dm-mod:dm-crypt:usbhid:usb_storage"
	MODULES="$MODULES:ehci-hcd:uhci-hcd:xhci-hcd:ehci-pci"
	MODULES="$MODULES:squashfs:fuse"

	if [ "$SMACK" = true ]; then
		MODULES="$MODULES:smack"
	elif [ "$EFI" = true ]; then
		MODULES="$MODULES:efivarfs"
	elif is_module_loaded efivarfs ; then
		MODULES="$MODULES:efivarfs"
	fi

	if [ -x /usr/bin/dracut ]; then
		/usr/bin/dracut -c -u -L -R -k $kernel \
			-f $ROOT_FS -r $ROOT_DEV \
			-m "$ROOT_FS:$BOOT_FS:$MODULES" \
			-o /boot/initramfs-${KERNAME}-${kernel}.img
	else
		/sbin/mkinitrd -c -u -L -R -k $kernel \
			-f $ROOT_FS -r $ROOT_DEV \
			-m "$ROOT_FS:$BOOT_FS:$MODULES" \
			-o /boot/initrd.img-${KERNAME}-${kernel}.gz
	fi

	if [ "$?" != 0 ]; then
		echo "Error: could not create initrd !"
		umount_device
		exit 1
	fi
	return 0
}

function check_drive()
{
	local line="$1"
	local retcode=0

	BOOT_DEV="$(echo "$line" | cut -f 1 -d,)"
	BOOT_UUID="$(echo "$line" | cut -f 2 -d,)"
	ROOT_DEV="$(echo "$line" | cut -f 3 -d,)"
	ROOT_UUID="$(echo "$line" | cut -f 4 -d,)"

	if ! echo "$BOOT_DEV" | grep -qF "$DEVICE" ; then

		retcode=1

		mkdir -p /mnt/hd
		mount $BOOT_DEV /mnt/hd ; sync

		find /mnt/hd/ -type f | \
			egrep '/(initrd.img|initramfs)[-].*' 1> $TMP/initrd.images

		find /mnt/hd/ -type f | \
			egrep '/vmlinuz[-]|/kernel[-]vmlinuz' 1> $TMP/vmlinuzes

		umount $BOOT_DEV ; sync

		if [ -s $TMP/initrd.images -a -s $TMP/vmlinuzes ]; then
			retcode=0
		fi
	fi

	if [ "$PART_TYPE" = "uefi" -a "$BOOT_MGR" = "gummiboot" ]; then
		if [ -d "/mnt/hd/EFI" ]; then
			retcode=0
		fi
	fi

	return $retcode
}

function add_other()
{
	local bootloader="$1"
	local outfile="$2"
	local disklabel=""
	local device_id=""
	local device=""
	local found=false
	local number=1
	local excludes="$DEVICE"

	if [ ! -z "$SRC_DEV" ]; then
		excludes="$excludes|$SRC_DEV"
	fi

	fdisk -l 1> $TMP/fdisk.log

	while read line; do

		if [ -z "$line" ]; then
			continue
		fi

		if [ "$found" = true ]; then
			if echo "$line" | grep -qiE '[*].*NTFS|FAT' ; then
				local bootable="$(echo "$line" | cut -f1 -d' ')"

				if [ "$bootloader" = "lilo" ]; then
					echo "" >> $outfile
					echo "other = $bootable" >> $outfile
					echo "  label = Windows_${MSNB}" >> $outfile
					echo "  table = $device" >> $outfile
				else
					echo "" >> $outfile
					echo "LABEL Windows_${MSNB}" >> $outfile
					echo "  MENU LABEL Windows $disklabel:$device_id" >> $outfile
					echo "  COM32 chain.c32" >> $outfile
					echo "  APPEND $disklabel:$device_id" >> $outfile
				fi
				disklabel=""
				device_id=""
				device=""
				found=false
				MSNB=$(( $MSNB + 1 ))
			fi
		fi

		if echo "$line" | grep -qEi '^Disk label type:' ; then
			disklabel="$(echo "$line" | sed -r 's/^.*[ ][ ]*//g')"

			if [ "$disklabel" = "dos" ]; then
				disklabel="mbr"
			else
				disklabel="gpt"
			fi
		elif echo "$line" | grep -qEi '^Disk identifier:' ; then
			if [ ! -z "$device" ]; then
				if ! echo "$device" | grep -qE "$excludes" ; then
					device_id="$(echo "$line" | sed -r 's/^.*[ ][ ]*//g')"
					found=true
				fi
			fi
		elif echo "$line" | grep -qEi '^Disk /dev/' ; then
			device="$(echo "$line" | sed -r 's/[:].*$//g')"
			device="$(echo "$device" | cut -f 2 -d' ')"

			if ! echo "$device" | grep -qE "$excludes" ; then
				found=true
			fi
		fi
	done < $TMP/fdisk.log

	return 0
}

function list_all_partitions()
{
	echo "$BOOT_DEV,$BOOT_UUID,$ROOT_DEV,$ROOT_UUID" 1> $TMP/boot-partitions

	if [ "$ALL_OSES" = false ]; then
		return 0
	fi

	lsblk -nl -o 'kname,rm,type,fstype,uuid,label' | \
		grep -F 'part' | grep -F '-' | grep -v -F 'swap' | \
		sed -r 's/[ ][ ]*/ /g' 1> $TMP/partitions

	while read line; do

		removable="$(echo "$line" | cut -f 2 -d' ')"
		if [ "$removable" = "1" ]; then continue; fi

		fstype="$(echo "$line" | cut -f 4 -d' ')"
		if [ -z "$fstype" ]; then continue; fi

		uuid="$(echo "$line" | cut -f 5 -d' ')"
		if [ -z "$uuid" ]; then continue; fi

		device="/dev/$(echo "$line" | cut -f 1 -d' ')"

		if [ "$device" = "$BOOT_DEV" -o "$device" = "$ROOT_DEV" ]; then
			continue
		fi

		label="$(echo "$line" | cut -f 6 -d' ')"
		if [ -z "$label" ]; then continue; fi

		if echo "$label" | grep -qE '^BOOT' ; then
			LINE="$device,$uuid"

		elif echo "$label" | grep -qE '^ROOT' ; then
			echo "$LINE,$device,$uuid" >> $TMP/boot-partitions
			LINE=""

		elif [ "$fstype" = "vfat" ]; then

			drive="$(echo "$device" | sed 's/[0-9]*//g')"
			partno="$(echo "$device" | sed 's/^[^0-9]*//g')"
			bootable="$(sgdisk -A ${partno}:get:2 $drive | grep -E "^$partno:")"

			if [ "$bootable" = "4:2:1" ]; then
				echo "$device,$uuid,$device,$uuid" >> $TMP/boot-partitions
				LINE=""
			else
				bootable="$(sfdisk -l $drive | grep -F '*' | cut -f1 -d' ')"

				if [ "$bootable" = "$device" ]; then
					echo "$device,$uuid,$device,$uuid" >> $TMP/boot-partitions
					LINE=""
				fi
			fi
		elif echo "$device" | grep -qE '[hs]d[a-z]1' ; then
			echo "$device,$uuid,$device,$uuid" >> $TMP/boot-partitions
			LINE=""
		fi
	done < $TMP/partitions

	return 0
}

function list_lilo_kernels()
{
	local kernel_version=""

	while read kernel; do

		kernel="$(basename "$kernel")"

		if [ "$kernel" = "vmlinuz" -o "$kernel" = "vmlinuz.old" ]; then
			continue
		fi

		kernel_version="$(extract_version "$kernel")"

		if [ -z "$kernel_version" -o ! -d "/lib/modules/$kernel_version" ]; then
			continue
		fi

		echo "" >> $BOOT_LIST
		echo "image = /boot/$kernel" >> $BOOT_LIST

		if [ -z "$ROOT_UUID" ]; then
			echo "  root = $ROOT_DEV" >> $BOOT_LIST
		else
			echo "  root = /dev/disk/by-id/$DEVMODEL-part${PART_NB}" >> $BOOT_LIST
		fi

		echo "  label = $kernel_version" >> $BOOT_LIST

		if find_initrd "$kernel_version" ; then
			echo "  initrd = $INITRD" >> $BOOT_LIST
		fi

		echo "  read-only" >> $BOOT_LIST

	done < $TMP/vmlinuzes

	return 0
}

function write_lilo_conf()
{
	local theme=false

	LILOCONF="/etc/lilo.conf"

	if [ -f $LILOCONF ]; then
		cp $LILOCONF ${LILOCONF}.sav
		unlink $LILOCONF 2> /dev/null
	fi

	touch $LILOCONF 2> /dev/null

	while read line; do

		if echo "$line" | grep -qF '# LiLO Theme begins here ...' ; then
			echo "$line" >> $LILOCONF
			theme=true
			continue

		elif echo "$line" | grep -qF '# LiLO Theme ends here ...' ; then
			cat /boot/lilo/themes/$BOOT_THEME/theme.dat >> $LILOCONF
			echo "#" >> $LILOCONF
			echo "$line" >> $LILOCONF
			theme=false

		elif [ "$theme" = false ]; then
			if echo "$line" | grep -qE '^boot[ ]*=' ; then
				echo "$line" | \
					sed "s/%drive[-]name%/$DEVMODEL/g" >> $LILOCONF
			else
				echo "$line" >> $LILOCONF
			fi
		fi
	done < /boot/lilo/lilo.conf

	echo "" 1> $BOOT_LIST
	echo "# LILO bootable partition config begins" >> $BOOT_LIST

	local PART_NB="$(echo "$ROOT_DEV" | sed 's/[^0-9]//g')"

	MSNB=1
	NUMBER=1

	while read line; do
		if check_drive "$line" ; then
			list_lilo_kernels
		fi
	done < $TMP/boot-partitions

	add_other lilo $BOOT_LIST

	if [ ! -z "$WINDOWS" ]; then
		echo "" >> $BOOT_LIST
		echo "other = $WINDOWS" >> $BOOT_LIST
		echo "  label = Windows" >> $BOOT_LIST
		echo "  boot-as = 0x80" >> $BOOT_LIST
	fi

	echo "" >> $BOOT_LIST
	echo "# LILO bootable partition config ends" >> $BOOT_LIST

	cat $BOOT_LIST >> $LILOCONF

	echo "Updated the LILO config file !"
	return 0
}

function list_grub_kernels()
{
	local kernel_version=""

	MENUENTRY="$(mktemp $TMP/grub.XXXXXX)"

	echo "" >> $BOOTLIST
	echo "# Linux bootable partition config begins" >> $BOOTLIST

	while read kernel; do

		kernel="$(basename "$kernel")"

		if [ "$kernel" = "vmlinuz" -o "$kernel" = "vmlinuz.old" ]; then
			continue
		fi

		kernel_version="$(extract_version "$kernel")"

		if [ -z "$kernel_version" -o ! -d "/lib/modules/$kernel_version" ]; then
			continue
		fi

		cp -a /etc/grub.d/menu-entry-linux.cfg $MENUENTRY

		if find_initrd "$kernel_version" ; then

			if [ -f "$INITRD" ]; then

				sed -i -r "s/%menu[-]entry%/Linux $kernel_version/g" $MENUENTRY
				sed -i -r "s/%root[-]uuid%/$UUID/g" $MENUENTRY
				sed -i -r "s/%boot[-]uuid%/$BOOTUUID/g" $MENUENTRY

				sed -i -r "s/^#[\t ]*initrd/	initrd/g" $MENUENTRY
				sed -i -r "s/%initrd%/$INITRD/g" $MENUENTRY

				echo "" >> $BOOTLIST
				cat $MENUENTRY >> $BOOTLIST
			fi
		fi

		if [ "$RESCUE" = true ]; then

			cp -a /etc/grub.d/menu-entry-linux.cfg $MENUENTRY

			if [ -f "$INITRD" ]; then

				sed -i -r "s/%menu[-]entry%/Linux $kernel_version/g" $MENUENTRY
				sed -i -r "s/%root[-]uuid%/$UUID/g" $MENUENTRY
				sed -i -r "s/%boot[-]uuid%/$BOOTUUID/g" $MENUENTRY

				sed -i -r "s/^#[\t ]*initrd/	initrd/g" $MENUENTRY
				sed -i -r "s/%initrd%/$INITRD/g" $MENUENTRY

				echo "" >> $BOOTLIST
				cat $MENUENTRY >> $BOOTLIST
			fi
		fi
	done < $TMP/vmlinuzes

	fdisk -l | grep -F -v "$SRCDEV" 1> $TMP/fdisk.log

	MSNB=1
	NUMBER=1
	FOUND=false
	WINDOWS=false

	while read line; do

		if [ -z "$line" ]; then
			continue
		fi

		if [ "$FOUND" = true ]; then

			if echo "$line" | grep -q -i -E 'NTFS|FAT' ; then

				devnb=1
				devid="$(echo "$line" | cut -f1 -d' ')"
				partid="$(echo "$devid" | sed 's/[^0-9]*//g')"
				devid="$(echo "$devid" | sed -r 's/\/dev\/[sh]d|[0-9]*//g')"

				for f in a b c d e f; do
					if [ "$f" = "$devid" ]; then
						break
					fi
					devnb=$(( $devnb + 1 ))
				done

				echo "" >> $BOOTLIST
				echo "menuentry \"Windows NT/2000, Windows95\" {" >> $BOOTLIST
				echo "   set root=(hd$devnb,$partid)" >> $BOOTLIST
				echo "   chainloader +1" >> $BOOTLIST
				echo "}" >> $BOOTLIST
				echo "" >> $BOOTLIST

				PREV_DEVICE_ID="$DEVICE_ID"
				FOUND=false
			fi
		fi

		if echo "$line" | grep -q -F -i 'Disk identifier:' ; then
			DEVICE_ID="$(echo "$line" | sed -r 's/.*[ ][ ]*//g')"
			FOUND=true
		fi
	done < $TMP/fdisk.log

	echo "" >> $BOOTLIST
	echo "# Linux bootable partition config ends" >> $BOOTLIST
	echo "" >> $BOOTLIST

	cp -f $BOOTLIST /etc/grub.d/40_custom
	return 0
}

function write_grub_conf()
{
	copy_theme "$BOOT_MGR" "$BOOT_THEME"

	echo "" 1> $BOOT_LIST
	echo "# GRUB bootable partition config begins" 1> $BOOT_LIST

	head -n5 /etc/grub.d/40_custom 1> $BOOTLIST

	MSNB=1
	NUMBER=1

	while read line; do
		if check_drive "$line" ; then
			list_grub_kernels
		fi
	done < $TMP/boot-partitions

	add_other grub $BOOT_LIST
}

function list_syslinux_kernels()
{
	local kernel_version=""

	while read kernel; do

		kernel="$(basename "$kernel")"

		if [ "$kernel" = "vmlinuz" -o "$kernel" = "vmlinuz.old" ]; then
			continue
		fi

		kernel_version="$(extract_version "$kernel")"

		if [ -z "$kernel_version" -o ! -d "/lib/modules/$kernel_version" ]; then
			continue
		fi

		DISTRO="Breeze::OS GNU/Linux ($kernel_version)"

		echo "" >> $BOOT_LIST
		echo "LABEL Linux_$NUMBER" >> $BOOT_LIST
		echo "  MENU LABEL $DISTRO" >> $BOOT_LIST
		echo "  LINUX ../$kernel" >> $BOOT_LIST

		if [ -z "$ROOT_UUID" ]; then
			echo "  APPEND root=$ROOT_DEV $BOOT_OPTS" >> $BOOT_LIST
		else
			echo "  APPEND root=UUID=$ROOT_UUID $BOOT_OPTS" >> $BOOT_LIST
		fi

		if find_initrd "$kernel_version" ; then
			if [ -f "$INITRD" ]; then
				echo "  INITRD ../$(basename $INITRD)" >> $BOOT_LIST
			fi
		fi

		NUMBER=$(( $NUMBER + 1 ))

#		if [ "$RESCUE" = true ]; then
#
#			echo "" >> $BOOT_LIST
#			echo "LABEL Linux_$NUMBER" >> $BOOT_LIST
#			echo "  MENU LABEL $DISTRO Rescue" >> $BOOT_LIST
#			echo "  LINUX ../$kernel" >> $BOOT_LIST
#
#			if [ -z "$ROOT_UUID" ]; then
#				echo "  APPEND root=$ROOT_DEV ro quiet single" >> $BOOT_LIST
#			else
#				echo "  APPEND root=UUID=$ROOT_UUID ro quiet single $BOOT_OPTS rescue/enable=true" >> $BOOT_LIST
#			fi
#
#			if [ -f "$INITRD" ]; then
#				echo "  INITRD ../$(basename $INITRD)" >> $BOOT_LIST
#			fi
#			NUMBER=$(( $NUMBER + 1 ))
#		fi
	done < $TMP/vmlinuzes

	return 0
}

function write_syslinux_conf()
{
	copy_theme "$BOOT_MGR" "$BOOT_THEME"

	echo "" 1> $BOOT_LIST
	echo "# SYSLINUX bootable partition config begins" 1> $BOOT_LIST

	MSNB=1
	NUMBER=1

	while read line; do
		if check_drive "$line" ; then
			list_syslinux_kernels
		fi
	done < $TMP/boot-partitions

	add_other syslinux $BOOT_LIST

	echo "" >> $BOOT_LIST
	echo "LABEL Memtest" >> $BOOT_LIST
	echo "  MENU LABEL Memtest86+" >> $BOOT_LIST
	echo "  LINUX ../memtest86+/memtest.bin" >> $BOOT_LIST
	echo "" >> $BOOT_LIST

	echo "LABEL hwinfo" >> $BOOT_LIST
	echo "  MENU LABEL Hardware Info" >> $BOOT_LIST
	echo "  COM32 hdt.c32" >> $BOOT_LIST
	echo "" >> $BOOT_LIST

#	echo "LABEL reboot" >> $BOOT_LIST
#	echo "  MENU LABEL Reboot" >> $BOOT_LIST
#	echo "  COM32 reboot.c32" >> $BOOT_LIST
#	echo "" >> $BOOT_LIST

	echo "LABEL poweroff" >> $BOOT_LIST
	echo "  MENU LABEL Power Off" >> $BOOT_LIST
#	echo "  COMBOOT_ poweroff.com" >> $BOOT_LIST
	echo "  COM poweroff.c32" >> $BOOT_LIST
	echo "" >> $BOOT_LIST

#	echo "MENU CLEAR" >> $BOOT_LIST
	echo "# SYSLINUX bootable partition config ends" >> $BOOT_LIST

	echo "Updated the SYSLINUX config file !"

	return 0
}

function copy_theme()
{
	local logodir="/boot/$1/themes/$2"
	local destdir="/boot/$1"
	local bootcfg="/boot/$1/${1}.cfg"
	local logo=""

	cp $destdir/${bootcfg}.factory $bootcfg

	sed -i -r "s/BreezeOS/$2/g" $bootcfg

	if [ -f "$logodir/splash.jpg" ]; then
		logo=splash.jpg
	elif [ -f "$logodir/splash.png" ]; then
		logo=splash.png
	fi

	local logoimg="$logodir/$logo"

	if [ -f "$logoimg" -a "$logoimg" -nt "$destdir/$logo" ]; then
		cp -f "$logoimg" $destdir/
		sed -i -r "s/splash[.](png|jpg)/$logo/g" $bootcfg
	fi
	return 0
}

function print_usage()
{
	echo "Usage: d-update-bootcfg.sh [ -rf ] -t <lilo|syslinux|grub|gummiboot> -k <kernel> -d <device> [ -a all -b <bootdir> -B <bootdev> -p <partno> -g <gptmode> -u <uuid> -U <bootuuid> ]"
	echo "  <all> to list all oses,"
	echo "  <kernel> is the kernel version,"
	echo "  <device> is the boot device,"
	echo "  <type> is the boot config type,"
	echo "  <rootdev> is the root device (/),"
	echo "  <bootdir> is the boot directory (/boot),"
	echo "  <bootdev> is the boot device (/boot),"
	echo "  <partno> is the boot partition no,"
	echo "  <uuid> is the uuid of the root device,"
	echo "  <bootuuid> is the uuid of the boot device,"
	echo "  <gptmode> is the partitioning mode <mbr/gpt/uefi>,"
	echo "  <rescue> stands for use of rescue boot entries."
	echo ""

	return 0
}

# Main starts here ...

if [ "$EUID" -gt 0 ]; then
	echo "You must execute only as root !"
	exit 1
fi

TMP="/tmp"
INITRD=""
RAID_OPTS=""
BOOT_OPTS=""
DEFLT_KERNEL=""
KERNAME="breeze"

DEVICE=""
ROOT_FS=""
ROOT_DEV=""
ROOT_UUID=""

EFI=false
LVM=false
CRYPT=false
FORCE=false
SMACK=false
CONFIG=false
RESCUE=false
ALL_OSES=false
ALWAYS_YES=false
#ALL_KERNELS=false

BOOT_FS=""
BOOT_UUID=""
BOOT_DEV=""
BOOT_DIR="/boot"
BOOT_MGR="syslinux"
PART_TYPE=""

while [ $# -gt 0 ]; do
	case $1 in
		"-f"|"-force"|"--force")
			FORCE=true
			shift 1 ;;

		"-y"|"--yes")
			ALWAYS_YES=true
			shift 1 ;;

		"-c"|"-cfg"|"--cfg")
			CONFIG=true
			shift 1 ;;

		"-e"|"-efi"|"--efi")
			EFI=true
			shift 1 ;;

		"-s"|"-smack"|"--smack")
			SMACK=true
			shift 1 ;;

		"-a"|"-all"|"--all")
			ALL_OSES=true
			shift 1 ;;

		"-k"|"-kernel"|"--kernel")
			shift 1
			DEFLT_KERNEL="$1"
			shift 1 ;;

		"-K"|"-kername"|"--kername")
			shift 1
			KERNAME="$1"
			shift 1 ;;

#		"-A"|"-kernels"|"--kernels")
#			ALL_KERNELS=true
#			shift 1 ;;

		"-t"|"-type"|"--type")
			shift 1
			BOOT_MGR=$1
			shift 1 ;;

		"-g"|"-ptype"|"--ptype")
			shift 1
			PART_TYPE="$1"
			shift 1 ;;

		"-crypt"|"--crypt")
			CRYPT=true
			shift 1 ;;

		"-lvm"|"--lvm")
			LVM=true
			shift 1 ;;

		"-u"|"-uuid"|"--uuid")
			shift 1
			ROOT_UUID="$1"
			shift 1 ;;

		"-U"|"-bootuuid"|"--bootuuid")
			shift 1
			BOOT_UUID="$1"
			shift 1 ;;

		"-d"|"-dev"|"--dev")
			shift 1
			DEVICE="$1"
			shift 1 ;;

		"-b"|"-bootdir"|"--bootdir")
			shift 1
			BOOT_DIR="$1"
			shift 1 ;;

		"-R"|"-rootdev"|"--rootdev")
			shift 1
			ROOT_DEV="$1"
			shift 1 ;;

		"-B"|"-bootdev"|"--bootdev")
			shift 1
			BOOT_DEV="$1"
			shift 1 ;;

		"-o"|"-opts"|"--opts")
			shift 1
			BOOT_OPTS="$1"
			shift 1 ;;

		"-p"|"-partno"|"--partno")
			shift 1
			PART_NO="$1"
			shift 1 ;;

		"-S"|"-srcdev"|"--srcdev")
			shift 1
			SRC_DEV="$(echo "$1" | sed 's/[0-9]*//g')"
			shift 1 ;;

		"-r"|"-rescue"|"--rescue")
			RESCUE=true
			shift 1 ;;

		"-h"|"-help"|"--help")
			print_usage
			shift 1 ;;

		*)
			echo "d-bootcfg.sh: invalid argument $1"
			print_usage
			exit 1
	esac
done

BOOTLOADERS="lilo,syslinux,grub,gummiboot"

DERIVATIVE="$(cat /etc/brzpkg/os-release | grep -F SOURCE_DISTRO | cut -f2 -d'=')"

if [ -z "$BOOT_MGR" ]; then
	echo "Error: Must specify a boot loader !"
	exit 1
fi

if [ -z "$DEFLT_KERNEL" ]; then
	echo "Error: The default kernel must be specified !"
	exit 1
fi

if [ ! -d /lib/modules/$DEFLT_KERNEL ]; then
	echo "No modules found for kernel '$DEFLT_KERNEL' !"
	exit 1
fi

ARCH="$(grep -F 'ARCHITECTURE=' /etc/brzpkg/os-release | cut -f2 -d'=')"

if [ -z "$ARCH" ]; then ARCH="$(uname -m)"; fi

if [ "$ARCH" != "amd64" -a "$ARCH" != "x86-64" ]; then
	BOOTLOADERS="lilo,syslinux,grub"
fi

if ! echo "$BOOTLOADERS" | grep -qF "$BOOT_MGR" ; then
	echo "Error: Invalid boot loader specified -- '$BOOT_MGR' !"
	exit 1
fi

if [ "$LVM" = false ]; then
	if pvscan | grep -q -E '/dev/[sh][d][a-z]|/dev/mapper' ; then
		LVM=true
	fi
fi

if [ -z "$DERIVATIVE" ]; then
	DERIVATIVE="$(cat /etc/brzpkg/os-release | grep -E '^ID=' | cut -f2 -d'=')"
fi

BOOT_OPTS="$BOOT_OPTS ro quiet vga=792"

if [ "$DERIVATIVE" = "gentoo" ]; then

	BOOT_OPTS="$BOOT_OPTS ro quiet vga=792 console=tty1 consoleblank=0"

	if [ "$LVM" = true ]; then
		BOOT_OPTS="$BOOT_OPTS dolvm domdadm"
	fi

	if [ -d /boot/memtest86plus/ -a ! -e /boot/memtest86+/ ]; then
		cd /boot
		ln -s ./memtest86plus ./memtest86+
		cd /
	fi
fi

if [ "$BOOT_MGR" = "grub" ]; then
	# load the device-mapper kernel module without which
	# grub-probe does not reliably detect disks and partitions
	DM_MOD="$(find /lib/modules/$DEFLT_KERNEL -name '*.ko' | grep -E -m1 'dm[_-]*mod')"

	if [ ! -z "$DM_MOD" ]; then
		modprobe "$(basename $DM_MOD '.ko')"
	fi
fi

if [ -z "$DEVICE" -a ! -z "$ROOT_DEV" ]; then
	DEVICE="$(echo $ROOT_DEV | sed 's/[0-9]*//g')"
fi

if [ -z "$DEVICE" -o -z "$ROOT_DEV" ]; then

	ROOT_DEV="$(cat /proc/mounts | grep -F ' / ' | cut -f1 -d' ' | crunch)"

	if [ -z "$ROOT_DEV" -a ! -z "$DEVICE" ]; then
		ROOT_DEV="$(blkid | grep -F "$DEVICE" | grep -F 'ROOT_' | cut -f1 -d':')"
	fi

	if [ -z "$ROOT_DEV" ]; then

		while true; do
			echo "[1;34;40mNo root device found -- Please specify one: [0m"

			read ROOT_DEV

			if [ ! -z "$ROOT_DEV" ]; then
				break
			fi
		done
	else
		echo "[1;34;40mFound root device '$ROOT_DEV' ![0m"
	fi

	DEVICE="$(echo $ROOT_DEV | sed 's/[0-9]*//g')"

	if echo "$DEVICE" | grep -qE '/dev/[hs]d[a-z]$|/dev/dm[-][0-9]+$' ; then
		echo -n "Using $DEVICE as bootloader target drive, proceed (y/n) ? "
		read answer
		if [ "$answer" != "y" ]; then
			exit 0
		fi
	else
		echo -n "Specify bootloader target drive (e.g. /dev/sda) : "
		read DEVICE
		if ! echo "$DEVICE" | grep -qE '/dev/[hs]d[a-z]$' ; then
			echo "Invalid name for device '$DEVICE' !"
			exit 0
		fi
	fi
fi

if [ -z "$PART_NO" ]; then PART_NO="1"; fi

if [ -z "$PART_TYPE" ]; then

	PART_TYPE="$(blkid -s PTTYPE -o value $DEVICE)"

	if [ -z "$PART_TYPE" ]; then
		tmpfile="$(mktemp)"

		fdisk -l ${DEVICE} 1> $tmpfile

		if grep -qE "${DEVICE}1.*GPT" $tmpfile ; then
			PART_TYPE="gpt"
		else
			PART_TYPE="mbr"
		fi

		if [ -e /var/tmp/chrooted -a "$PART_TYPE" = "mbr" ]; then

			echo "Detected '$PART_TYPE' as partition type for $DEVICE"
			echo "If not the right partition type, enter the right one !"
			echo ""
			echo -n "Enter 'gpt' or 'mbr' or Press <return> to quit : "
			read PART_TYPE

			if [ "$PART_TYPE" != "mbr" -a "$PART_TYPE" != "gpt" ]; then
				exit 0
			fi
		fi
		unlink $tmpfile
	fi
fi

PART_TYPE="$(echo $PART_TYPE | tr '[:upper:]' '[:lower:]')"

if [ -z "$BOOT_DIR" ]; then BOOT_DIR="/boot"; fi

if [ -z "$BOOT_DEV" ]; then
	BOOT_DEV="$(cat /proc/mounts | grep -F ' /boot ' | cut -f1 -d' ')"
fi

if [ -z "$ROOT_DEV" ]; then
	ROOT_DEV="$(cat /proc/mounts | grep -F ' / ' | cut -f1 -d' ')"
fi

if [ -z "$BOOT_DEV" ]; then

	echo -n "No boot device found -- Please specify one [$ROOT_DEV]: "
	read BOOT_DEV

	if [ -z "$BOOT_DEV" ]; then
		BOOT_DEV="$ROOT_DEV"
		BOOT_DIR="/"
	fi
fi

if [ "$ROOT_DEV" != "$BOOT_DEV" ]; then

	if ! cat /proc/mounts | grep -F ' /boot ' | grep -qF "$DEVICE" ; then

		mount $BOOT_DEV $BOOT_DIR

		if [ "$?" != 0 ]; then
			echo "Failed to mount the boot partition $BOOT_DEV !"
			umount_device
			exit 1
		fi
		echo "Mounted the boot partition $BOOT_DEV !"
		sleep 1
	fi
	sync
fi

if [ -z "$ROOT_UUID" -a ! -z "$ROOT_DEV" ]; then
	ROOT_UUID="$(lsblk -n -o uuid $ROOT_DEV)"

	if [ -z "$ROOT_UUID" ]; then
		ROOT_UUID="$(blkid -s UUID -o value $ROOT_DEV)"
	fi
fi

if [ -z "$BOOT_UUID" -a ! -z "$BOOT_DEV" ]; then
	BOOT_UUID="$(lsblk -n -o uuid $BOOT_DEV)"

	if [ -z "$BOOT_UUID" ]; then
		BOOT_UUID="$(blkid -s UUID -o value $BOOT_DEV)"
	fi
fi

if [ -z "$ROOT_FS" -a ! -z "$ROOT_DEV" ]; then
	ROOT_FS="$(lsblk -n -o fstype $ROOT_DEV)"

	if [ -z "$ROOT_FS" ]; then
		ROOT_FS="$(blkid -s TYPE -o value $ROOT_DEV)"
	fi
fi

if [ -z "$BOOT_FS" -a ! -z "$BOOT_DEV" ]; then
	BOOT_FS="$(lsblk -n -o fstype $BOOT_DEV)"

	if [ -z "$BOOT_FS" ]; then
		BOOT_FS="$(blkid -s TYPE -o value $BOOT_DEV)"
	fi
fi

DEVID="$(basename $DEVICE)"
VENDOR="$(lsblk -n -o vendor $DEVICE | crunch 2> /dev/null)"
MODEL="$(lsblk -n -o model $DEVICE | crunch)"
SERIAL="$(lsblk -n -o serial $DEVICE | crunch)"

if [ ! -z "$MODEL" ]; then
    DEVMODEL="$(echo ${MODEL} | sed 's/[ -]/_/g')"
fi

if [ -z "$DEVMODEL" ]; then
   DEVMODEL="$(ls -l /dev/disk/by-id | fgrep -m1 $DEVID)"
   DEVMODEL="$(echo "$DEVMODEL" | sed 's/[ ]*->.*//g')"
   DEVMODEL="$(echo "$DEVMODEL" | sed 's/^.*[ ]//g')"
fi

echo "MODEL='$DEVMODEL'"
echo "TYPE=[ '$PART_TYPE' ]"
echo "DEVICE=[ '$DEVICE' ]"
echo "BOOT=[ '$BOOT_DEV', '$BOOT_FS' ]"
echo "ROOT=[ '$ROOT_DEV', '$ROOT_FS' ]"

if [ -z "$ROOT_DEV" ]; then
	echo "Root device was not specified !"
	umount_device
	exit 1
fi

rename 'kernel-' '' /boot/kernel-vmlinuz* 2> /dev/null

find /boot/ -type f | egrep '/vmlinuz[-]' | grep -v '.old' 1> $TMP/vmlinuzes

if [ "$ALWAYS_YES" = false ]; then

	cat $TMP/vmlinuzes | grep -F "$DEFLT_KERNEL" 1> $TMP/vmlinuzes.new
	cat $TMP/vmlinuzes
	echo "------------------"

	echo -n "Use the above settings (y/n) ? "
	read answer

	if [ "$answer" != "y" ]; then
		echo "Exiting !"
		umount_device
		exit 1
	fi
	#mv $TMP/vmlinuzes.new $TMP/vmlinuzes
fi

if [ ! -s $TMP/vmlinuzes ]; then
	echo "No Linux kernels were found !"
	umount_device
	exit 1
fi

list_all_partitions

if ! find_initrd "$DEFLT_KERNEL" ; then
	create_initrd "$DEFLT_KERNEL"
fi

#if [ "$ALL_KERNELS" = true ]; then
#
#	cat $TMP/vmlinuzes | while read kernel; do
#
#		if echo "$kernel" | egrep -q "${DEFLT_KERNEL}$" ; then
#			continue
#		fi
#
#		kernel="$(extract_version "$kernel")"
#		echo "kernel $kernel"
#
#		if [ -z "$kernel" -o ! -d "/lib/modules/$kernel" ]; then
#			continue
#		fi
#
#		if ! find_initrd "$kernel" ; then
#			create_initrd "$kernel"
#		fi
#	done
#fi

find /boot/ -maxdepth 2 -type f | \
	egrep '/(initrd.img|initramfs)[-].*' 1> $TMP/initrd.images

if [ -z "$BOOT_THEME" ]; then
	BOOT_THEME="BreezeOS"
fi

if [ "$BOOT_MGR" = "lilo" ]; then

	BOOT_LIST="/boot/lilo/bootlist.cfg"
	cp $BOOT_LIST ${BOOT_LIST}.${DATE}

	mkdir -p /boot/lilo

	if [ ! -f /boot/lilo/lilo.conf ]; then
		if [ -d /usr/share/lilo ]; then
			cp -au /usr/share/lilo /boot/
		fi
	fi

	if [ ! -f /boot/lilo/BreezeOS.bmp ]; then
		SPLASH=/boot/lilo/themes/$LILO_THEME/splash.bmp

		if [ -z "$LILO_THEME" -o ! -f "$SPLASH" ]; then
			cp /boot/lilo/themes/BreezeOS/splash.bmp /boot/lilo/BreezeOS.bmp
			cp /boot/lilo/themes/BreezeOS/splash.dat /boot/lilo/BreezeOS.dat
		else
			cp /boot/lilo/themes/$LILO_THEME/splash.bmp /boot/lilo/BreezeOS.bmp
			cp /boot/lilo/themes/$LILO_THEME/splash.dat /boot/lilo/BreezeOS.dat
		fi
	fi

	if [ ! -f /boot/lilo/lilo.conf ]; then
		echo "Failed to locate lilo.conf !"
		umount_device
		exit 1
	fi

	write_lilo_conf

	if [ "$CONFIG" = false ]; then
		/sbin/lilo -b $DEVICE 2> $TMP/lilo.err
	fi
elif [ "$BOOT_MGR" = "syslinux" ]; then

	export EXTLINUX_THEME="BreezeOS"

	BOOT_LIST="/boot/syslinux/bootlist.cfg"
	cp $BOOT_LIST ${BOOT_LIST}.${DATE}

	mkdir -p /boot/syslinux
	mkdir -p /boot/EFI/BOOT/
	mkdir -p /boot/efi/EFI/BOOT/

	if [ ! -e /boot/extlinux ]; then
		cd /boot
		ln -s syslinux extlinux
		cd /
	fi

	write_syslinux_conf

	if [ "$CONFIG" = true ]; then
		exit 0
	fi

	if [ -f /usr/share/syslinux/vesamenu.c32 ]; then
		mbrfile=/usr/share/syslinux/mbr.bin
		gptmbrfile=/usr/share/syslinux/gptmbr.bin
		altmbrfile=/usr/share/syslinux/altmbr.bin

		if [ ! -f /boot/syslinux/vesamenu.c32 ]; then
			cp -au /usr/share/hwdata/pci.ids /boot/syslinux/

			if [ "$PART_TYPE" != "uefi" ]; then
				cp -au /usr/share/syslinux/*.c32 /boot/syslinux/
				cp -au /usr/share/syslinux/*.com /boot/syslinux/
			fi
		fi
	else
		mbrfile=/usr/lib/syslinux/mbr.bin
		gptmbrfile=/usr/lib/extlinux/gptmbr.bin
		altmbrfile=/usr/lib/syslinux/altmbr.bin

		if [ ! -f /boot/syslinux/vesamenu.c32 ]; then
			cp -au /usr/share/misc/pci.ids /boot/syslinux/

			if [ "$PART_TYPE" != "uefi" ]; then
				cp -au /usr/lib/syslinux/*.c32 /boot/syslinux/
				cp -au /usr/lib/syslinux/*.com /boot/syslinux/
				cp -au /usr/lib/extlinux/*.c32 /boot/syslinux/
			fi
		fi
	fi

	if [ -f "/proc/mdstat" ]; then
		if [ "$(stat -c %t $BOOT_DEV)" = "9" ]; then 
			RAID_OPTS="--raid"
		fi
	fi

	extlinux $RAID_OPTS --install /boot/syslinux 2> $TMP/syslinux.err

	if [ "$?" != 0 ]; then
		echo "Failed to install extlinux on $DEVICE !"
		umount_device
		exit 1
	fi

	if [ "$PART_TYPE" = "mbr" -o "$PART_TYPE" = "dos" ]; then
		dd bs=440 count=1 conv=notrunc if=${mbrfile} of=$DEVICE

	elif [ "$PART_TYPE" = "gpt" ]; then

		if [ -x sgdisk -a ! -z "$PART_NO" ]; then
			echo "Setting partition $PART_NO on $DEVICE, using sgdisk !"
			sgdisk $DEVICE --attributes=${PART_NO}:set:2
		fi

		if [ "$?" = 0 ]; then
			dd bs=440 count=1 conv=notrunc if=${gptmbrfile} of=$DEVICE
		fi
	elif [ "$EFI" = true ]; then

		mount -t efivars efivars /sys/firmware/efi/efivars

		if [ "$ARCH" = "amd64" -o "$ARCH" = "x86-64" ]; then
			set_efibootmgr syslinux $DEVICE "X64" "64"
		else
			set_efibootmgr syslinux $DEVICE "X32" "32"
		fi
	else
		printf "\x${PART_NO}" | cat ${altmbrfile} - | \
			dd bs=440 count=1 iflag=fullblock conv=notrunc of=$DEVICE
	fi
elif [ "$BOOT_MGR" = "grub" ]; then

	export GRUB_THEME="BreezeOS"

	BOOT_LIST="/boot/grub/grub.cfg"
	cp $BOOT_LIST ${BOOT_LIST}.${DATE}

	mkdir -p /boot/grub/
	mkdir -p /boot/EFI/BOOT/
	mkdir -p /boot/efi/EFI/BOOT/

	export GRUB_DEVICE="$DEVICE"
	export GRUB_DEVICE_UUID="$ROOT_UUID"

	if [ "$RESCUE" = true ]; then
		echo "GRUB_DISABLE_RECOVERY=false" >> /etc/default/grub
	fi

	if [ "$CRYPT" = true ]; then
		echo "GRUB_CRYPTODISK_ENABLE=y" >> /etc/default/grub
	fi

	if [ "$CONFIG" = false ]; then

		if [ "$EFI" = false ]; then
			grub2-install ${DEVICE}
		else
			mount -t efivars efivars /sys/firmware/efi/efivars

			if [ "$ARCH" = "amd64" -o "$ARCH" = "x86-64" ]; then
				set_efibootmgr grub $DEVICE "X64" "64"
			else
				set_efibootmgr grub $DEVICE "X32" "32"
			fi
		fi
	fi
	grub2-mkconfig -o /boot/grub/grub.cfg
fi

if [ "$?" != 0 ]; then
	echo "[1;31;40mInstallation of the boot loader failed ![0m"
	umount_device
	exit 1
fi

umount_device

if [ "$CONFIG" = true ]; then
	echo "[1;32;40mYour $BOOT_MGR boot loader has been configured ![0m"
else
	echo "[1;36;40mYour $BOOT_MGR boot loader has been installed ![0m"
fi

echo "Remember to set your boot order in your BIOS !"

exit 0

# end Breeze::OS setup script
