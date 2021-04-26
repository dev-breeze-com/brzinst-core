#!/bin/bash
#
# GNU GENERAL PUBLIC LICENSE -- Version 3
#
# Copyright 2013 Pierre Innocent, Tsert Inc., All Rights Reserved
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
# d-bootcfg.sh SYSLINUX/LILO/GRUB/GRUB2 boot configuration <dev@tsert.com>
#
TMP=/tmp
ROOTDIR=/

if [ "$EUID" -gt 0 ]; then
	echo "You must execute only as root !"
	exit 1
fi

MBR=false
RESCUE=false

while [ $# -gt 0 ]; do
	case $1 in
		"-t"|"-type"|"--type")
			shift 1
			BOOT_TYPE=$1
			shift 1 ;;

		"-m"|"-mbr"|"--mbr")
			MBR=true
			shift 1 ;;

		"-u"|"-uuid"|"--uuid")
			shift 1
			UUID="$1"
			shift 1 ;;

		"-b"|"-boot"|"--boot")
			shift 1
			BOOT_DRIVE="$1"
			shift 1 ;;

		"-p"|"-partno"|"--partno")
			shift 1
			PART_NO="$1"
			shift 1 ;;

		"-r"|"-rescue"|"--rescue")
			RESCUE=true
			shift 1 ;;

		*)
			echo "Usage: d-syslinux-update.sh [ -R ] -B <device> -P <partno>"
			echo "  where <device> is the boot drive; and"
			echo "  where <partno> is the boot partition; and"
			echo "  where option R stands for use of rescue boot entries."
			exit 1
	esac
done

if [ "$BOOT_DRIVE" = "" -o "$PART_NO" = "" ]; then
	echo "Usage: d-syslinux-update.sh [ -R ] -B <drive> -P <partno>"
	echo "  where <device> is the boot drive; and"
	echo "  where <partno> is the boot partition; and"
	echo "  where option R stands for use of rescue boot entries."
	exit 1
fi

dialog --colors \
	--backtitle "Breeze::OS $RELEASE Installer" \
	--title "Breeze::OS Setup -- Boot Loader Installation" \
	--infobox "\nPlease wait ... Installing your \Z1Boot Loader\Zn" 5 55

device="`mount | grep -F '/boot' | cut -f1 -d ' '`" 

if [ "$device" = "" ]; then
	device=${BOOT_DRIVE}1
	mount -t ext4 $device /boot
else
	umount $device
	sleep 1
	mount -t ext4 $device /boot
fi

if [ "$?" != 0 ]; then
	dialog --colors \
		--backtitle "Breeze::OS $RELEASE Installer" \
		--title "Breeze::OS Setup -- Boot Loader Installation" \
		--infobox "\nFailed to mount the boot partition $device !" 5 55

	exit 1
fi

mkdir -p /boot/syslinux/

extlinux --stupid --install /boot/syslinux

if [ "$?" != 0 ]; then

	dialog --colors \
		--backtitle "Breeze::OS $RELEASE Installer" \
		--title "Breeze::OS Setup -- Boot Loader Installation" \
		--infobox "\nSyslinux failed to install properly !" 5 55

	umount $device
	sleep 1
	exit 1
fi

MENUC32="/boot/syslinux/menu.c32"

if [ ! -e "$MENUC32" -o ! -s "$MENUC32" ]; then
	cp -a /usr/share/syslinux/*.c32 /boot/syslinux/
fi

if [ "$MBR" = true ]; then
	/bin/dd bs=440 count=1 conv=notrunc \
		if=/usr/share/syslinux/mbr.bin \
		of=$BOOT_DRIVE
else
	printf "\x${PART_NO}" | \
		/bin/cat /usr/share/syslinux/altmbr.bin - | \
		/bin/dd bs=440 count=1 iflag=fullblock conv=notrunc of=$BOOT_DRIVE
fi

if [ "$?" != 0 ]; then
	dialog --colors \
		--backtitle "Breeze::OS $RELEASE Installer" \
		--title "Breeze::OS Setup -- Boot Loader Installation" \
		--msgbox "\nInstallation of the \Z1boot loader\Zn failed !\n" 7 55

	umount $device
	sleep 1
	exit 1
fi

find /boot/ -type f -name 'vmlinuz-*' 1> /boot/syslinux/vmlinuzes

if [ "$?" != 0 -o ! -s /boot/syslinux/vmlinuzes ]; then

	dialog --colors \
		--backtitle "Breeze::OS $RELEASE Installer" \
		--title "Breeze::OS Setup -- Boot Loader Installation" \
		--msgbox "\nNo Linux kernels were found !" 7 55

	umount $device
	sleep 1
	exit 1
fi

#UUID="`lsblk -n -l -o 'uuid' "$BOOT_DRIVE${PART_NO}"`"

SYSLINUX_CONF="/boot/syslinux/bootlist.cfg"

echo "# Linux bootable partition config begins" 1> $SYSLINUX_CONF

NUMBER=1

while read kernel; do

	kernel="`basename "$kernel"`"
	echo "Processing $kernel"

	if [ "$kernel" = "vmlinuz" -o "$kernel" = "vmlinuz.old" ]; then
		continue
	fi

	KERNEL="`echo "$kernel" | sed -r 's/vmlinuz[-]//g'`"

	echo "" >> $SYSLINUX_CONF
	echo "LABEL Linux_$NUMBER" >> $SYSLINUX_CONF
	echo "  MENU LABEL Linux $KERNEL" >> $SYSLINUX_CONF
	echo "  LINUX /boot/$kernel" >> $SYSLINUX_CONF

	if [ -f "/boot/initrd.img-$KERNEL" ]; then
		echo "  INITRD /boot/initrd.img-$KERNEL" >> $SYSLINUX_CONF
	fi

	echo "  APPEND root=UUID=$UUID ro quiet vt.default_utf8=1" >> $SYSLINUX_CONF
#	echo "  APPEND root=UUID=$UUID ro quiet nopat vt.default_utf8=1" >> $SYSLINUX_CONF
	NUMBER=$(( $NUMBER + 1 ))

	if [ "$RESCUE" = true ]; then

		echo "" >> $SYSLINUX_CONF
		echo "LABEL Linux_$NUMBER" >> $SYSLINUX_CONF
		echo "  MENU LABEL Rescue Linux $KERNEL" >> $SYSLINUX_CONF
		echo "  LINUX /boot/$kernel" >> $SYSLINUX_CONF

		if [ -f "/boot/initrd.img-$KERNEL" ]; then
			echo "  INITRD /boot/initrd.img-$KERNEL" >> $SYSLINUX_CONF
		fi

		echo "  APPEND root=UUID=$UUID ro quiet vt.default_utf8=1 rescue/enable=true" >> $SYSLINUX_CONF

		NUMBER=$(( $NUMBER + 1 ))
	fi
done < /boot/syslinux/vmlinuzes

fdisk -l 1> /boot/syslinux/fdisk.log

NUMBER=1
FOUND=false
WINDOWS=false

while read line; do

	if [ "$line" = "" ]; then
		continue
	fi

	if [ "$FOUND" = true ]; then
		if [ "`echo "$line" | grep -i -E 'NTFS|FAT'`" != "" ]; then
			echo "" >> $SYSLINUX_CONF
			echo "LABEL Windows_$NUMBER" >> $SYSLINUX_CONF
			echo "  MENU LABEL Windows" >> $SYSLINUX_CONF
			echo "  COM32 chain.c32" >> $SYSLINUX_CONF
			echo "  APPEND mbr:$DEVICE_ID" >> $SYSLINUX_CONF
			PREV_DEVICE_ID="$DEVICE_ID"
			FOUND=false
		fi
	fi

	if [ "`echo "$line" | grep -F -i 'Disk identifier:'`" != "" ]; then
		DEVICE_ID="`echo "$line" | sed -r 's/.*[ ][ ]*//g'`"
		FOUND=true
	fi
done < /boot/syslinux/fdisk.log

echo "" >> $SYSLINUX_CONF
echo "LABEL Memtest" >> $SYSLINUX_CONF
echo "  MENU LABEL Memtest86+" >> $SYSLINUX_CONF
echo "  LINUX /boot/memtest86+/memtest.bin" >> $SYSLINUX_CONF

echo "" >> $SYSLINUX_CONF
echo "# Linux bootable partition config ends" >> $SYSLINUX_CONF

umount $device
sleep 1

exit 0

# end Breeze::OS setup script
