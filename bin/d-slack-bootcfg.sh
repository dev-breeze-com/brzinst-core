#!/bin/bash
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
# d-bootcfg.sh LILO/GRUB2 boot configuration <dev@tsert.com>
#
TMP=/tmp
ROOTDIR=/

umount_device() {
	if [ "$BOOTDIR" != "/" ]; then
		umount $BOOTDEV
	fi
	return 0
}

write_lilo_conf() {

	cp -a /boot/lilo/breeze.bmp /boot/
	cat /boot/lilo/lilo.conf 1> /etc/lilo.conf

	DRIVE_NAME="`cat $TMP/boot-drive-name 2> /dev/null`"
	sed -i -r "s/%drive[-]name%/$DRIVE_NAME/g" /etc/lilo.conf

	echo "" 1> $BOOTLIST
	echo "# LILO bootable partition config begins" >> $BOOTLIST

	while read kernel; do

		kernel="`basename "$kernel"`"

		if [ "$kernel" = "vmlinuz" -o "$kernel" = "vmlinuz.old" ]; then
			continue
		fi

		KERNEL="`echo "$kernel" | sed -r 's/vmlinuz[-]//g'`"

		echo "" >> $BOOTLIST
		echo "image = /boot/$kernel" >> $BOOTLIST
#		echo "  root = /dev/disk/by-id/$DRIVE_NAME-part${PART_NO}" >> $BOOTLIST
		echo "  root = ${DEVICE}${PART_NO}" >> $BOOTLIST
		echo "  label = $KERNEL" >> $BOOTLIST
		echo "  read-only" >> $BOOTLIST

		echo "" >> $BOOTLIST
		echo "image = /boot/$kernel" >> $BOOTLIST
#		echo "  root = /dev/disk/by-id/$DRIVE_NAME-part${PART_NO}" >> $BOOTLIST
		echo "  root = ${DEVICE}${PART_NO}" >> $BOOTLIST
		echo "  label = RE_$KERNEL" >> $BOOTLIST
		echo "  read-only" >> $BOOTLIST

	done < $TMP/vmlinuzes

	if [ "$WINDOWS" != "" ]; then
		echo "" >> $BOOTLIST
		echo "other = $WINDOWS" >> $BOOTLIST
		echo "  label = Windows" >> $BOOTLIST
		echo "  boot-as = 0x80" >> $BOOTLIST
	fi

	echo "" >> $BOOTLIST
	echo "# LILO bootable partition config ends" >> $BOOTLIST

	cat $BOOTLIST >> /etc/lilo.conf

	return 0
}

write_grub_conf() {

	cp -f /etc/grub.d/40_custom /etc/grub.d/old_40_custom

	head -n5 /etc/grub.d/40_custom 1> $BOOTLIST

	if [ "$BOOTDEV" = "" -a "$BOOTDIR" = "" ]; then
#		set root=(hd0,5)
#		linux /boot/vmlinuz-linux-libre root=/dev/sda5
#		initrd /boot/initramfs-linux-libre.img
#		boot
		return 0
	fi

	MENUENTRY="`mktemp $TMP/grub.XXXXXX`"

	echo "" >> $BOOTLIST
	echo "# Linux bootable partition config begins" >> $BOOTLIST

	while read kernel; do

		kernel="`basename "$kernel"`"

		if [ "$kernel" = "vmlinuz" -o "$kernel" = "vmlinuz.old" ]; then
			continue
		fi

		KERNEL="`echo "$kernel" | sed -r 's/vmlinuz[-]//g'`"

#	GRUB_CMDLINE_LINUX_DEFAULT="quiet splash vga=792"
#	With a separate boot partition ...
#	set root=(hd0,5)
#	linux /vmlinuz-linux-libre root=/dev/sda6
#	initrd /initramfs-linux-libre.img
#	boot

		cp -a /etc/grub.d/menu-entry-linux.cfg $MENUENTRY

		sed -i -r "s/%menu[-]entry%/Linux $KERNEL/g" $MENUENTRY
		sed -i -r "s/%root[-]uuid%/$UUID/g" $MENUENTRY
		sed -i -r "s/%boot[-]uuid%/$BOOTUUID/g" $MENUENTRY

		if [ -f "/boot/initrd.img-$KERNEL" ]; then
			sed -i -r "s/^#[\t ]*initrd/	initrd/g" $MENUENTRY
			sed -i -r "s/%initrd%/initrd.img-$KERNEL/g" $MENUENTRY
		fi

		cat $MENUENTRY >> $BOOTLIST

		if [ "$RESCUE" = true ]; then

			cp -a /etc/grub.d/menu-entry-linux.cfg $MENUENTRY

			sed -i -r "s/%menu[-]entry%/Linux $KERNEL/g" $MENUENTRY
			sed -i -r "s/%root[-]uuid%/$UUID/g" $MENUENTRY
			sed -i -r "s/%boot[-]uuid%/$BOOTUUID/g" $MENUENTRY

			if [ -f "/boot/initrd.img-$KERNEL" ]; then
				sed -i -r "s/^#[\t ]*initrd/	initrd/g" $MENUENTRY
				sed -i -r "s/%initrd%/initrd.img-$KERNEL/g" $MENUENTRY
			fi
			echo "" >> $BOOTLIST
			cat $MENUENTRY >> $BOOTLIST
		fi
	done < $TMP/vmlinuzes

	fdisk -l | fgrep -v "$SRCDEV" 1> $TMP/fdisk.log

	NUMBER=1
	FOUND=false
	WINDOWS=false

	while read line; do

		if [ "$line" = "" ]; then
			continue
		fi

		if [ "$FOUND" = true ]; then
			if [ "`echo "$line" | grep -i -E 'NTFS|FAT'`" != "" ]; then
				devnb=1
				devid="`echo "$line" | cut -f1 -d' '`"
				partid="`echo "$devid" | sed 's/[^0-9]*//g'`"
				devid="`echo "$devid" | sed -r 's/\/dev\/[sh]d|[0-9]*//g'`"

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

		if [ "`echo "$line" | fgrep -i 'Disk identifier:'`" != "" ]; then
			DEVICE_ID="`echo "$line" | sed -r 's/.*[ ][ ]*//g'`"
			FOUND=true
		fi
	done < $TMP/fdisk.log

	echo "" >> $BOOTLIST
	echo "# Linux bootable partition config ends" >> $BOOTLIST
	echo "" >> $BOOTLIST

	cp -f $BOOTLIST /etc/grub.d/40_custom
	return 0
}

write_syslinux_conf() {

	echo "" 1> $BOOTLIST
	echo "# SYSLINUX bootable partition config begins" 1> $BOOTLIST

	NUMBER=1

	while read kernel; do

		kernel="`basename "$kernel"`"

		if [ "$kernel" = "vmlinuz" -o "$kernel" = "vmlinuz.old" ]; then
			continue
		fi

		KERNEL="`echo "$kernel" | sed -r 's/vmlinuz[-]//g'`"

		echo "" >> $BOOTLIST
		echo "LABEL Linux_$NUMBER" >> $BOOTLIST
		echo "  MENU LABEL Linux $KERNEL" >> $BOOTLIST
		echo "  LINUX /boot/$kernel" >> $BOOTLIST

		if [ -f "/boot/initrd.img-$KERNEL" ]; then
			echo "  INITRD /boot/initrd.img-$KERNEL" >> $BOOTLIST
		fi

		echo "  APPEND root=UUID=$UUID ro quiet" >> $BOOTLIST
	#	echo "  APPEND root=UUID=$UUID ro quiet nopat vt.default_utf8=1" >> $BOOTLIST
		NUMBER=$(( $NUMBER + 1 ))

		if [ "$RESCUE" = true ]; then

			echo "" >> $BOOTLIST
			echo "LABEL Linux_$NUMBER" >> $BOOTLIST
			echo "  MENU LABEL Rescue Linux $KERNEL" >> $BOOTLIST
			echo "  LINUX /boot/$kernel" >> $BOOTLIST

			if [ -f "/boot/initrd.img-$KERNEL" ]; then
				echo "  INITRD /boot/initrd.img-$KERNEL" >> $BOOTLIST
			fi

			echo "  APPEND root=UUID=$UUID ro quiet vt.default_utf8=1 rescue=true" >> $BOOTLIST

			NUMBER=$(( $NUMBER + 1 ))
		fi
	done < $TMP/vmlinuzes

	fdisk -l | fgrep -v "$SRCDEV" 1> $TMP/fdisk.log

	NUMBER=1
	FOUND=false
	WINDOWS=false

	while read line; do

		if [ "$line" = "" ]; then
			continue
		fi

		if [ "$FOUND" = true ]; then
			if [ "`echo "$line" | grep -i -E 'NTFS|FAT'`" != "" ]; then
				echo "" >> $BOOTLIST
				echo "LABEL Windows_$NUMBER" >> $BOOTLIST
				echo "  MENU LABEL Windows" >> $BOOTLIST
				echo "  COM32 chain.c32" >> $BOOTLIST
				echo "  APPEND mbr:$DEVICE_ID" >> $BOOTLIST
				PREV_DEVICE_ID="$DEVICE_ID"
				FOUND=false
			fi
		fi

		if [ "`echo "$line" | fgrep -i 'Disk identifier:'`" != "" ]; then
			DEVICE_ID="`echo "$line" | sed -r 's/.*[ ][ ]*//g'`"
			FOUND=true
		fi
	done < $TMP/fdisk.log

	echo "" >> $BOOTLIST
	echo "LABEL Memtest" >> $BOOTLIST
	echo "  MENU LABEL Memtest86+" >> $BOOTLIST
	echo "  LINUX /boot/memtest86+/memtest.bin" >> $BOOTLIST

	echo "" >> $BOOTLIST
	echo "# SYSLINUX bootable partition config ends" >> $BOOTLIST

	return 0
}

# Main starts here ...

SRCDEV="`cat $TMP/selected-source 2> /dev/null`"

if [ "$EUID" -gt 0 ]; then
	echo "You must execute only as root !"
	exit 1
fi

MBR=true
UUID=""
RESCUE=false
PART_NO=""
BOOTDEV=""
BOOTDIR=""
BOOTCFG="grub"
BOOTUUID=""
GPTMODE="mbr"

print_usage() {
	echo "Usage: d-bootcfg.sh -t <lilo/grub> [ -r ] -d <device> -b <bootdir> -B <bootdev> -p <partno> -g <gptmode> -u <uuid> -U <boot-uuid>"
	echo "  where <device> is the boot device, and"
	echo "  where <type> is the boot config type, and"
	echo "  where <bootdir> is the boot directory (/boot), and"
	echo "  where <bootdev> is the boot device (/boot), and"
	echo "  where <partno> is the boot partition no, and"
	echo "  where <uuid> is the uuid of the root device, and"
	echo "  where <boot-uuid> is the uuid of the boot device, and"
	echo "  where <gptmode> is the partitioning mode <mbr/gpt/uefi>, and"
	echo "  where <rescue> stands for use of rescue boot entries."
	return 0
}

while [ $# -gt 0 ]; do
	case $1 in
		"-t"|"-type"|"--type")
			shift 1
			BOOTCFG=$1
			shift 1 ;;

		"-m"|"-mbr"|"--mbr")
			MBR=true
			shift 1 ;;

		"-g"|"-gpt"|"--gpt")
			shift 1
			GPTMODE="$1"
			shift 1 ;;

		"-u"|"-uuid"|"--uuid")
			shift 1
			UUID="$1"
			shift 1 ;;

		"-U"|"-boot-uuid"|"--boot-uuid")
			shift 1
			BOOTUUID="$1"
			shift 1 ;;

		"-d"|"-dev"|"--dev")
			shift 1
			DEVICE="$1"
			shift 1 ;;

		"-b"|"-bootdir"|"--bootdir")
			shift 1
			BOOTDIR="$1"
			shift 1 ;;

		"-B"|"-bootdev"|"--bootdev")
			shift 1
			BOOTDEV="$1"
			shift 1 ;;

		"-p"|"-partno"|"--partno")
			shift 1
			PART_NO="$1"
			shift 1 ;;

		"-r"|"-rescue"|"--rescue")
			RESCUE=true
			shift 1 ;;

		*)
			print_usage
			exit 1
	esac
done

if [ "$DEVICE" = "" -o "$PART_NO" = "" ]; then
	print_usage
	exit 1
fi

if [ "$BOOTUUID" = "" ]; then
	BOOTUUID="$UUID"
fi

dialog --colors \
	--backtitle "Breeze::OS $RELEASE Installer" \
	--title "Breeze::OS Setup -- Boot Loader Installation" \
	--infobox "\nPlease wait ... Installing your \Z1Boot Loader\Zn" 5 55

if [ "$BOOTDEV" != "" -a "$BOOTDIR" != "" -a "$BOOTDIR" != "/" ]; then

	if [ "`mount | fgrep 'on / '`" = "" ]; then
		mount $BOOTDEV $BOOTDIR &> $TMP/mount.err
	else
		mounted="`mount | fgrep "$BOOTDEV"`"

		if [ "$mounted" = "" ]; then
			mount $BOOTDEV $BOOTDIR
		fi
	fi

	if [ "$?" != 0 ]; then
		dialog --colors \
			--backtitle "Breeze::OS $RELEASE Installer" \
			--title "Breeze::OS Setup -- Boot Loader Installation" \
			--msgbox "\nFailed to mount the boot partition $BOOTDEV !" 7 55

		exit 1
	fi
	sleep 1
	mounted="`mount | fgrep "$BOOTDEV"`"
	echo "$BOOTDEV = $BOOTDIR == '$mounted'"
fi

if [ "$BOOTCFG" = "lilo" ]; then
	BOOTLIST="/boot/lilo/bootlist.cfg"
	mkdir -p /boot/lilo/

elif [ "$BOOTCFG" = "syslinux" ]; then
	BOOTLIST="/boot/syslinux/bootlist.cfg"
	mkdir -p /boot/syslinux/
else
	BOOTLIST="/boot/grub/bootlist.cfg"
	mkdir -p /boot/grub2

	if [ ! -e /boot/grub ]; then
		cd /boot/
		ln -sf grub2 grub
		cd /
	fi
fi

if [ "$?" != 0 ]; then
	umount_device

	dialog --colors \
		--backtitle "Breeze::OS $RELEASE Installer" \
		--title "Breeze::OS Setup -- Boot Loader Installation" \
		--msgbox "\nCould not create the boot folder !" 7 55

	exit 1
fi

find /boot/ -maxdepth 1 -type f -name 'vmlinuz-*' 1> $TMP/vmlinuzes

if [ "$?" != 0 -o ! -s $TMP/vmlinuzes ]; then

	echo "############# mount"
	mount
	echo "############# ls -l /boot"
	ls -l /boot
	echo "############# ls -l $TMP/vmlinuzes"
	ls -l $TMP/vmlinuzes
	echo "############# cat /proc/partitions"
	cat /proc/partitions
	echo "#############"
	umount_device
	echo "#############"
	sleep 20

	dialog --colors \
		--backtitle "Breeze::OS $RELEASE Installer" \
		--title "Breeze::OS Setup -- Boot Loader Installation" \
		--msgbox "\nNo Linux kernels were found !" 7 55

	exit 1
fi

if [ "$BOOTCFG" = "lilo" ]; then
	write_lilo_conf
elif [ "$BOOTCFG" = "syslinux" ]; then
	write_syslinux_conf
elif [ "$BOOTCFG" = "grub" ]; then
	write_grub_conf
fi

if [ "$BOOTCFG" = "lilo" ]; then
	/sbin/lilo -b $DEVICE 2> $TMP/lilo.err

elif [ "$BOOTCFG" = "syslinux" ]; then
	#   extlinux --stupid --install /boot/syslinux 2> $TMP/syslinux.err
	extlinux --install /boot/syslinux 2> $TMP/syslinux.err

	if [ "$?" = 0 ]; then
		MENUC32="/boot/syslinux/menu.c32"

		if [ ! -e "$MENUC32" -o ! -s "$MENUC32" ]; then
			cp -a /usr/share/syslinux/*.c32 /boot/syslinux/
		fi

		if [ "$MBR" = true ]; then
			/bin/dd bs=440 count=1 conv=notrunc \
				if=/usr/share/syslinux/mbr.bin \
				of=$DEVICE
		else
			printf "\x${PART_NO}" | \
				/bin/cat /usr/share/syslinux/altmbr.bin - | \
				/bin/dd bs=440 count=1 iflag=fullblock conv=notrunc of=$DEVICE
		fi
	fi
elif [ "$BOOTCFG" = "grub" ]; then

	if [ "$BOOTDEV" = "" ] && [ "$BOOTDIR" = "" -o "$BOOTDIR" = "/" ]; then
		grub-install --target=i386-pc --recheck --debug $DEVICE 2> $TMP/grub.err

	elif [ "$GPTMODE" = "mbr" -o "$MBR" = true ]; then
		grub-install --directory=/usr/lib/grub/i386-pc --target=i386-pc --recheck --force --debug ${DEVICE}1
#		grub-install --directory=/usr/lib/grub/i386-pc --target=i386-pc --boot-directory=$BOOTDIR --recheck --force --debug ${DEVICE}1

		if [ -e /boot/grub/i386-pc/core.img ]; then
			chattr +i /boot/grub/i386-pc/core.img
		else
			umount_device
			dialog --colors \
				--backtitle "Breeze::OS $RELEASE Installer" \
				--title "Breeze::OS Setup -- Boot Loader Installation" \
				--msgbox "\nNo /boot/grub/i386-pc/core.img were found !" 7 55
			exit 1
		fi

#		grub-install --target=i386-pc --boot-directory=$BOOTDIR --recheck --debug $DEVICE 2> $TMP/grub.err
#	elif [ "$GPTMODE" = "gpt" ]; then
#		grub-install --target=i386-pc --force --recheck --debug $DEVICE
#	elif [ "$GPTMODE" = "uefi" ]; then
#		grub-install --target=x86_64-efi --efi-directory=$BOOTDIR --bootloader-id=breeze_grub --force --recheck --debug $DEVICE
	fi

	if [ "$?" = 0 ]; then
		grub-mkconfig -o /boot/grub/grub.cfg

		if [ "$?" = 0 ]; then
			mkdir -p /boot/grub/locale
			cp -a /usr/share/locale/en\@quot/LC_MESSAGES/grub.mo \
				/boot/grub/locale/en.mo
			grub-set-default 0
		fi
	fi
fi

if [ "$?" != 0 ]; then
	umount_device

	dialog --colors \
		--backtitle "Breeze::OS $RELEASE Installer" \
		--title "Breeze::OS Setup -- Boot Loader Installation" \
		--msgbox "\nInstallation of the \Z1boot loader\Zn failed !\n" 7 55

	exit 1
fi

if [ "$?" != 0 ]; then
	umount_device

	dialog --colors \
		--backtitle "Breeze::OS $RELEASE Installer" \
		--title "Breeze::OS Setup -- Boot Loader Installation" \
		--msgbox "\nInstallation of the \Z1boot loader\Zn failed !\n" 7 55

	exit 1
fi

umount_device

dialog --colors \
	--backtitle "Breeze::OS $RELEASE Installer" \
	--title "Breeze::OS Setup -- Boot Loader Installation" \
	--msgbox "\nYour \Z1$BOOTCFG\Zn boot loader has been installed !\n\n\
Remember to set your \Z1boot order\Zn in your \Z1BIOS\Zn !\n\n" 9 55

exit 0

# end Breeze::OS setup script
