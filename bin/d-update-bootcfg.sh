#!/bin/bash
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

DEBUG_ON=false

IS_ON=/bin/true

if [ -e /etc/init.d/functions.sh ]; then
	. /etc/init.d/functions.sh
elif [ -e /etc/init.d/functions ]; then
	. /etc/init.d/functions
fi

crunch()
{
    read answer
    echo $answer
    return 0
}

vga_screen_size()
{
	local size="$(cut -d':' -f1 "$1")"
	local depth="$(cut -d':' -f2 "$1")"
	local vga="792"

	if [ "$size" = "800x600" ]; then
		if [ "$depth" = "8" ]; then
			vga="771"
		elif [ "$1" = "16" ]; then
			vga="788"
		elif [ "$1" = "24" ]; then
			vga="789"
		fi
	elif [ "$size" = "1024x768" ]; then
		if [ "$depth" = "8" ]; then
			vga="773"
		elif [ "$1" = "16" ]; then
			vga="791"
		elif [ "$1" = "24" ]; then
			vga="792"
		fi
	elif [ "$size" = "1280x1024" ]; then
		if [ "$depth" = "8" ]; then
			vga="775"
		elif [ "$1" = "16" ]; then
			vga="794"
		elif [ "$1" = "24" ]; then
			vga="795"
		fi
	elif [ "$size" = "1600x1200" ]; then
		if [ "$depth" = "8" ]; then
			vga="796"
		elif [ "$1" = "16" ]; then
			vga="798"
		elif [ "$1" = "24" ]; then
			vga="799"
		fi
	fi
	echo "$vga"
	return 0
}

umount_device()
{
	if [ -e /var/tmp/chrooted -a -n "$BOOT_DEV" ]; then
		if [ "$ROOT_DEV" != "$BOOT_DEV" ]; then
			umount $BOOT_DEV
		fi
	fi

#	while [ $? = 0 ] ; do
#		umount /dev/tmpfs 
#	done

	unlink $TMP/initrd.images 2> /dev/null
	unlink $TMP/boot-partitions 2> /dev/null
	unlink $TMP/vmlinuzes 2> /dev/null

	return 0
}

is_module_loaded()
{
	if lsmod | grep -qF "$1" ; then
		return 0
	fi
	return 1
}

set_efibootmgr()
{
	local mode="$1"
	local device="$2"
	local ARCH="$3"
	local arch="$4"
	local entries="$(mktemp -t efi.XXXXXX)"
	local efilabel="$(echo "$EFILABEL" | sed -r 's/[ ]*\[.*\][ ]*/.*/g')"

	load_efivars

	if [ "$EFIMODE" != true ]; then
		return 1
	fi

	efibootmgr | grep -E "$efilabel" 1> $entries

	while read entry; do
		entry="$(echo "$entry" | cut -f1 -d'*' | sed -r 's/^[BOTbot0]+//g')"

		if [ -n "$entry" ]; then
			efibootmgr -b $entry -B $entry
		else
			efibootmgr -b 0 -B 0
		fi
	done < "$entries"

	unlink $entries 2> /dev/null

	if [ "$mode" = "syslinux" ]; then

		cp -af $SYSFOLDER/efi${arch}/syslinux.efi \
			/boot/EFI/BOOT/boot${ARCH}.efi

		if [ $? != 0 ]; then return 1; fi

		efibootmgr -c -d $device -p 1 -l \
			/EFI/syslinux/syslinux.efi -L "$EFILABEL"

		if [ "$UEFI" = true ]; then

			cp -af /boot/EFI/BOOT/boot${ARCH}.efi /boot/EFI/BOOT/BOOT${ARCH}.EFI

			efibootmgr --create --gpt --disk ${device} --part 1 \
				--write-signature --label "$EFILABEL [secure]" \
				--loader "\\EFI\\BOOT\\BOOT${ARCH}.EFI"
		fi
	elif [ "$mode" = "gummiboot" ]; then

		cp -af /usr/share/gummiboot/efi${arch}/gummiboot.efi \
			/boot/EFI/BOOT/boot${ARCH}.efi

		efibootmgr -c -d $device -p 1 -l \
			/EFI/gummiboot/gummiboot.efi -L "$EFILABEL"

		if [ "$UEFI" = true ]; then
			efibootmgr --create --gpt --disk ${device} --part 1 \
				--write-signature --label "$EFILABEL [secure]" \
				--loader "\\EFI\\BOOT\\BOOT${ARCH}.EFI"
		fi
	elif [ "$mode" = "grub" ]; then

		#cp -af /usr/share/grub/efi${arch}/grubx${arch}.efi \
		#cp -af /boot/EFI/slackware-14.2/grubx${arch}.efi \
		#	/boot/EFI/BOOT/BOOT${ARCH}.EFI

		if [ "$UEFI" = true ]; then
			efibootmgr --create --gpt --disk ${device} --part 1 \
				--write-signature --label "$EFILABEL [secure]" \
				--loader "\\EFI\\BOOT\\BOOT${ARCH}.EFI"
		fi
	#grub-install --efi-directory=/boot/efi --target efi-${arch} ${device}
	fi
	return 0
}

load_efivars()
{
	# To prevent inconsistencies, before accessing the EFI VAR data
	modprobe -r efivars
	if [ -e /sys/firmware/efi ]; then
		umount /sys/firmware/efi/efivars
		sync
		modprobe -r efivarfs
		modprobe efivarfs
		mount -t efivarfs efivarfs /sys/firmware/efi/efivars
	fi
	return $?
}

extract_prefix()
{
	local prefix="$1"
	local kversion="$2"

	prefix="$(echo "$prefix" | sed -r 's/vmlinuz[-]//g')"
	prefix="$(echo "$prefix" | sed -r 's/[-][0-9].*$//g')"

	if [ -z "$prefix" -o "$prefix" = "$kversion" ]; then
		echo "breeze"
	else
		echo "$prefix"
	fi
	return 0
}

extract_version()
{
	local kernel="$1"

	kernel="$(basename "$kernel")"

	if [ "$kernel" = "vmlinuz" -o "$kernel" = "vmlinuz.old" ]; then
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
		return 1
	fi
	echo "$kernel"
	return 0
}

find_initrd()
{
	local kernel="$1"
	local prefix="(initrd.img|initramfs)[-]${2}"
	local pattern="$(echo "$1" | sed 's/[-]/[-]/g')"

	local PATTERN="${prefix}[-]${pattern}[.]gz"
	if [ "$DEBUG_ON" = true ]; then
		echo "[1;34;40mUsing pattern '$PATTERN' ...[0m"
	fi
	INITRD="$(grep -E -m1 "$PATTERN" $TMP/initrd.images)"

	if [ -n "$INITRD" -a -f "$INITRD" ]; then
		echo "[1;36;40mFound initrd '$INITRD' ![0m"
		return 0
	fi

	PATTERN="(initrd.img|initramfs)[-]$pattern[.]gz"
	if [ "$DEBUG_ON" = true ]; then
		echo "[1;34;40mUsing pattern '$PATTERN' ...[0m"
	fi
	INITRD="$(grep -E -m1 "$PATTERN" $TMP/initrd.images)"

	if [ -n "$INITRD" -a -f "$INITRD" ]; then
		echo "[1;36;40mFound initrd '$INITRD' ![0m"
		return 0
	fi

	PATTERN="(initrd.img|initramfs).*$pattern"
	if [ "$DEBUG_ON" = true ]; then
		echo "[1;34;40mUsing pattern '$PATTERN' ...[0m"
	fi
	INITRD="$(grep -E -m1 "$PATTERN" $TMP/initrd.images)"

	if [ -n "$INITRD" -a -f "$INITRD" ]; then
		if echo "$INITRD" | grep -q -F "breeze" ; then
			INITRD=""
		elif [ "$2" = "huge" ] && echo "$INITRD" | grep -q -F "generic" ; then
			INITRD=""
		else
			echo "[1;36;40mFound initrd '$INITRD' ![0m"
			return 0
		fi
	fi
	echo "[1;33;40mNo valid INITRD found for $1 with prefix '$2' ![0m"
	return 1
}

create_initrd()
{
	local kernel="$1"
	local prefix="$2"

	if [ -z "$ROOT_FS" -o -z "$BOOT_FS" ]; then
		echo "[1;31;40mError: rootfs and bootfs must be specified ![0m"
		exit 1
	fi

	echo "[1;36;40mCreating initrd for kernel $kernel ...[0m"

	MODULES="scsi_mod:sd_mod:sr_mod:dm-mod:dm-crypt:usbhid:usb_storage"
	MODULES="$MODULES:ehci-hcd:uhci-hcd:xhci-hcd:ehci-pci:usbhid:hid_generic"
	MODULES="$MODULES:squashfs:fuse:xfs:jfs:reiserfs:nilfs2"

	if [ "$CRYPT" = "luks" ]; then
		# If these modules are not hardcoded ...
		MODULES="$MODULES:nls_cp437:vfat"

		# Use a VFAT formatted USB key ...
		LUKS_KEYFILE="LABEL=BRZCRYPTO:/boot/luks/"
		LUKS_OPTIONS="-C $LUKS_DEVICES -K $LUKS_KEYFILE"
	fi

	if [ "$SMACK" = true ]; then
		MODULES="$MODULES:smack"
	fi

	if [ "$EFIMODE" = true ]; then
		MODULES="$MODULES:efivarfs"
	elif is_module_loaded efivarfs ; then
		MODULES="$MODULES:efivarfs"
	fi

#	if [ -x /usr/bin/dracut ]; then
#		/usr/bin/dracut -F -c -u -L -R -k $kernel \
#			-f $ROOT_FS -r $ROOT_DEV \
#			-m "$ROOT_FS:$BOOT_FS:$MODULES" \
#			-o /boot/initramfs-${prefix}-${kernel}.img
#	else
		rm -rf /run/mkinitrd/initrd-tree 2> /dev/null
		mkdir -p /run/mkinitrd/initrd-tree

		/sbin/mkinitrd -s /run/mkinitrd/initrd-tree \
			-F -c -u -L -R -k $kernel $LUKS_OPTIONS \
			-f $ROOT_FS -r $ROOT_DEV \
			-m "$ROOT_FS:$BOOT_FS:$MODULES" \
			-o /boot/initrd.img-${prefix}-${kernel}.gz
#fi

	if [ $? != 0 ]; then
		echo "[1;31;40mError: could not create initrd ![0m"
		umount_device
		exit 1
	fi
	return 0
}

check_drive()
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

	if [ "$BOOT_MGR" = "gummiboot" ]; then
		if [ -d "/mnt/hd/EFI" ]; then
			retcode=0
		fi
	fi

	return $retcode
}

add_other()
{
	local bootloader="$1"
	local outfile="$2"
	local disklabel=""
	local device_id=""
	local device=""

	local found=false
	local number=1
	local excludes="$DEVICE"
	local patterns="$(cat /proc/mounts | grep -v '/mnt/' | cut -f1 -d' ' | crunch | tr -s '\n' '|')"

	if [ -n "$patterns" ]; then
		excludes="$excludes|$patterns"
	fi

	fdisk -l | grep -E -v "$excludes" 1> $TMP/fdisk.log

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

				elif [ "$bootloader" = "syslinux" ]; then
					echo "" >> $outfile
					echo "LABEL Windows_${MSNB}" >> $outfile
					echo "  MENU LABEL Windows $disklabel:$device_id" >> $outfile
					echo "  COM32 chain.c32" >> $outfile
					echo "  APPEND $disklabel:$device_id" >> $outfile

				elif [ "$bootloader" = "grub" ]; then
					devnb=1
					partid="$(echo "$bootable" | sed 's/[^0-9]*//g')"
					bootable="$(echo "$bootable" | sed -r 's/\/dev\/[sh]d|[0-9]*//g')"

					for f in a b c d e f; do
						if [ "$f" = "$bootable" ]; then
							break
						fi
						devnb=$(( $devnb + 1 ))
					done

					echo "" >> $BOOT_LIST
					echo "menuentry \"Windows NT/2000, Windows95\" {" >> $BOOT_LIST
					echo "   set root=(hd$devnb,$partid)" >> $BOOT_LIST
					echo "   chainloader +1" >> $BOOT_LIST
					echo "}" >> $BOOT_LIST
					echo "" >> $BOOT_LIST

					#PREV_DEVICE_ID="$DEVICE_ID"
					#FOUND=false
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
			if [ -n "$device" ]; then
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

list_all_partitions()
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

list_lilo_kernels()
{
	local kernel_version=""

	while read kernel; do

		kernel="$(basename "$kernel")"

		if [ -z "kernel" -o "$kernel" = "vmlinuz" -o "$kernel" = "vmlinuz.old" ]; then
			continue
		fi

		kernel_version="$(extract_version "$kernel")"
		kernel_prefix="$(extract_prefix "$kernel" "$kernel_version")"

		if [ -z "$kernel_version" -o ! -d "/lib/modules/$kernel_version" ]; then
			continue
		fi

		if echo "$KERNELS" | grep -q -F "$kernel_version" ; then
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

		if find_initrd "$kernel_version" "$kernel_prefix" ; then
			echo "  initrd = $INITRD" >> $BOOT_LIST
		fi

		KERNELS="$KERNELS $kernel_version"
		echo "  read-only" >> $BOOT_LIST

	done < $TMP/vmlinuzes

	return 0
}

write_lilo_conf()
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

	if [ -n "$WINDOWS" ]; then
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

list_gummiboot_kernels()
{
	local kernel=""
	local kernel_version=""
	local kernel_prefix=""

	while read kernel; do

		kernel="$(basename "$kernel")"

		if [ -z "kernel" -o "$kernel" = "vmlinuz" -o "$kernel" = "vmlinuz.old" ]; then
			continue
		fi

		kernel_version="$(extract_version "$kernel")"
		kernel_prefix="$(extract_prefix "$kernel" "$kernel_version")"

		if [ -z "$kernel_version" -o ! -d "/lib/modules/$kernel_version" ]; then
			continue
		fi

		if echo "$KERNELS" | grep -q -F "$kernel_version" ; then
			continue
		fi

		DISTRO="Breeze::OS GNU/Linux ($kernel_version)"
		BOOT_LIST="/boot/EFI/loader/entries/${kernel}.conf"

		echo "# Gummiboot entry begins" 1> $BOOT_LIST
		echo "#" >> $BOOT_LIST
		echo "TITLE $DISTRO" >> $BOOT_LIST
		echo "VERSION $kernel" >> $BOOT_LIST
		echo "LINUX /$kernel" >> $BOOT_LIST

		if find_initrd "$kernel_version" "$kernel_prefix" ; then
			if [ -f "$INITRD" ]; then
				INITRD="$(basename $INITRD)"
				echo "INITRD /$INITRD" >> $BOOT_LIST
			fi
		fi

		echo "OPTIONS ROOT=$ROOT_UUID ro quiet" >> $BOOT_LIST
		echo "# GUMMIBOOT entry ends" >> $BOOT_LIST

		KERNELS="$KERNELS $kernel_version"
		NUMBER=$(( $NUMBER + 1 ))

	done < $TMP/vmlinuzes

	return 0
}

write_gummiboot_conf()
{
	MSNB=1
	NUMBER=1

	echo "# GUMMIBOOT bootable partition config begins" 1> $BOOT_LIST
	echo "#" >> $BOOT_LIST
	echo "timeout 30" >> $BOOT_LIST
	echo "default breeze-${DEFLT_KERNEL}" >> $BOOT_LIST
	echo "splash BreezeOS.bmp" >> $BOOT_LIST
	echo "background #000000" >> $BOOT_LIST
	echo "# GUMMIBOOT bootable partition config ends" >> $BOOT_LIST

	while read line; do
		if check_drive "$line" ; then
			list_gummiboot_kernels
		fi
	done < $TMP/boot-partitions

	#add_other gummiboot $BOOT_LIST

	if [ "$ARCH" = "amd64" -o "$ARCH" = "x86_64"  ]; then
		BOOT_LIST="/boot/EFI/loader/entries/shellx64.conf"
		echo "# Gummiboot entry begins" 1> $BOOT_LIST
		echo "#" >> $BOOT_LIST
		echo "TITLE UEFI Shell" >> $BOOT_LIST
		echo "LINUX /EFI/Shellx64.efi" >> $BOOT_LIST
		echo "" >> $BOOT_LIST
		echo "# GUMMIBOOT entry ends" >> $BOOT_LIST
	else
		BOOT_LIST="/boot/EFI/loader/entries/shellx32.conf"
		echo "# Gummiboot entry begins" 1> $BOOT_LIST
		echo "#" >> $BOOT_LIST
		echo "TITLE UEFI Shell" >> $BOOT_LIST
		echo "LINUX /EFI/Shellx32.efi" >> $BOOT_LIST
		echo "" >> $BOOT_LIST
		echo "# GUMMIBOOT entry ends" >> $BOOT_LIST
	fi

	BOOT_LIST="/boot/EFI/loader/entries/memtest86.conf"
	echo "# Gummiboot entry begins" 1> $BOOT_LIST
	echo "#" >> $BOOT_LIST
	echo "TITLE Memtest86+" >> $BOOT_LIST
	echo "LINUX /memtest86+/memtest.bin" >> $BOOT_LIST
	echo "" >> $BOOT_LIST
	echo "# GUMMIBOOT entry ends" >> $BOOT_LIST

#	echo "LABEL hwinfo" >> $BOOT_LIST
#	echo "  MENU LABEL Hardware Info" >> $BOOT_LIST
#	echo "  COM32 hdt.c32" >> $BOOT_LIST
#	echo "" >> $BOOT_LIST

#	echo "LABEL poweroff" >> $BOOT_LIST
#	echo "  MENU LABEL Power Off" >> $BOOT_LIST
#	echo "  COMBOOT_ poweroff.com" >> $BOOT_LIST
#	echo "  COM poweroff.c32" >> $BOOT_LIST
#	echo "" >> $BOOT_LIST

	echo "[1;32;40mUpdated the GUMMIBOOT config file ![0m"
	return 0
}

list_grub_kernels()
{
	local kernel_version=""

	echo "" 1> $BOOT_LIST
	echo "# Linux bootable partition config begins" >> $BOOT_LIST

	while read kernel; do

		kernel="$(basename "$kernel")"

		if [ -z "kernel" -o "$kernel" = "vmlinuz" -o "$kernel" = "vmlinuz.old" ]; then
			continue
		fi

		kernel_version="$(extract_version "$kernel")"
		kernel_prefix="$(extract_prefix "$kernel" "$kernel_version")"

		if [ -z "$kernel_version" -o ! -d "/lib/modules/$kernel_version" ]; then
			continue
		fi

		if echo "$KERNELS" | grep -q -F "$kernel_version" ; then
			continue
		fi

		if find_initrd "$kernel_version" "$kernel_prefix" ; then

			if [ -f "$INITRD" ]; then

				initrd="$(basename $INITRD)"

				cat "/boot/EFI/BOOT/kernelentry.cfg" | sed \
					-e "s/@VGA@/$VGA/g" \
					-e "s/@ROOTUUID@/$ROOTUUID/g" \
					-e "s/@BOOTUUID@/$BOOTUUID/g" \
					-e "s/@BRZ_KERNEL@/$kernel/g" \
					-e "s/@BRZ_INITRD@/\/boot\/$initrd/g" \
					>> $BOOT_LIST

				echo "" >> $BOOT_LIST
			fi
		fi
		KERNELS="$KERNELS $kernel_version"
	done < $TMP/vmlinuzes

#	touch $TMP/fdisk.log
#
#	if [ -n "$SRC_DEV" ]; then
#		fdisk -l | grep -E -v "$excludes" 1> $TMP/fdisk.log
#	fi
#
#	MSNB=1
#	NUMBER=1
#	FOUND=false
#	WINDOWS=false
#
#	while read line; do
#
#		if [ -z "$line" ]; then
#			continue
#		fi
#
#		if [ "$FOUND" = true ]; then
#
#			if echo "$line" | grep -q -i -E 'NTFS|FAT' ; then
#
#				devnb=1
#				devid="$(echo "$line" | cut -f1 -d' ')"
#				partid="$(echo "$devid" | sed 's/[^0-9]*//g')"
#				devid="$(echo "$devid" | sed -r 's/\/dev\/[sh]d|[0-9]*//g')"
#
#				for f in a b c d e f; do
#					if [ "$f" = "$devid" ]; then
#						break
#					fi
#					devnb=$(( $devnb + 1 ))
#				done
#
#				echo "" >> $BOOT_LIST
#				echo "menuentry \"Windows NT/2000, Windows95\" {" >> $BOOT_LIST
#				echo "   set root=(hd$devnb,$partid)" >> $BOOT_LIST
#				echo "   chainloader +1" >> $BOOT_LIST
#				echo "}" >> $BOOT_LIST
#				echo "" >> $BOOT_LIST
#
#				PREV_DEVICE_ID="$DEVICE_ID"
#				FOUND=false
#			fi
#		fi
#
#		if echo "$line" | grep -q -F -i 'Disk identifier:' ; then
#			DEVICE_ID="$(echo "$line" | sed -r 's/.*[ ][ ]*//g')"
#			FOUND=true
#		fi
#	done < $TMP/fdisk.log

	return 0
}

write_grub_default()
{
	cp -af /etc/default/grub /etc/default/grub.${DATE} 2> /dev/null

	if [ "$EFIMODE" = true ]; then
		cat "/boot/EFI/BOOT/grub.default" | sed \
			-e "s/@VGA@/$VGA/g" \
			-e "s/@SPLASH@/\/boot\/EFI\/BOOT\/theme\/splash.png/g" \
			>> /etc/default/grub
	else
		cat "/boot/EFI/BOOT/grub.default" | sed \
			-e "s/@VGA@/$VGA/g" \
			-e "s/@SPLASH@/\/boot\/grub\/splash.png/g" \
			>> /etc/default/grub
	fi

	if [ "$CRYPT" = "luks" ]; then
		echo "" >> /etc/default/grub
		echo "GRUB_CRYPTODISK_ENABLE=y" >> /etc/default/grub
	fi
	return 0
}

write_grub_conf()
{
	echo "" 1> $BOOT_LIST
	echo "# GRUB bootable partition config begins" 1> $BOOT_LIST

	head -n5 /etc/grub.d/40_custom 1> $BOOT_LIST

	MSNB=1
	NUMBER=1

	while read line; do
		if check_drive "$line" ; then
			list_grub_kernels
		fi
	done < $TMP/boot-partitions

	add_other grub $BOOT_LIST

	echo "" >> $BOOT_LIST
	echo "# Linux bootable partition config ends" >> $BOOT_LIST
	echo "" >> $BOOT_LIST

	cp -f $BOOT_LIST /etc/grub.d/40_custom
}

list_syslinux_kernels()
{
	local prefix=".."
	local kernel_version=""
	local kernel_prefix=""

	if [ "$EFIMODE" = true ]; then
		prefix="../.."
	fi

	while read kernel; do

		kernel="$(basename "$kernel")"

		if [ -z "kernel" -o "$kernel" = "vmlinuz" -o "$kernel" = "vmlinuz.old" ]; then
			continue
		fi

		kernel_version="$(extract_version "$kernel")"
		kernel_prefix="$(extract_prefix "$kernel" "$kernel_version")"

		if [ -z "$kernel_version" -o ! -d "/lib/modules/$kernel_version" ]; then
			continue
		fi

		if echo "$KERNELS" | grep -q -F "$kernel_version" ; then
			continue
		fi

		DISTRO="Breeze::OS GNU/Linux ($kernel_version)"

		echo "" >> $BOOT_LIST
		echo "LABEL Linux_$NUMBER" >> $BOOT_LIST
		echo "  MENU LABEL $DISTRO" >> $BOOT_LIST
		echo "  LINUX $prefix/$kernel" >> $BOOT_LIST

		if [ -z "$ROOT_UUID" ]; then
			echo "  APPEND root=$ROOT_DEV $BOOT_OPTS" >> $BOOT_LIST
		else
			echo "  APPEND root=UUID=$ROOT_UUID $BOOT_OPTS" >> $BOOT_LIST
		fi

		if find_initrd "$kernel_version" "$kernel_prefix" ; then
			if [ -f "$INITRD" ]; then
				echo "  INITRD $prefix/$(basename $INITRD)" >> $BOOT_LIST
			fi
		fi

		KERNELS="$KERNELS $kernel_version"
		NUMBER=$(( $NUMBER + 1 ))

	done < $TMP/vmlinuzes

	return 0
}

write_syslinux_conf()
{
	local prefix=".."

	echo "" 1> $BOOT_LIST
	echo "# SYSLINUX bootable partition config begins" 1> $BOOT_LIST

	MSNB=1
	NUMBER=1

	if [ "$EFIMODE" = true ]; then
		prefix="../.."
	fi

	while read line; do
		if check_drive "$line" ; then
			list_syslinux_kernels
		fi
	done < $TMP/boot-partitions

	add_other syslinux $BOOT_LIST

	echo "" >> $BOOT_LIST
	echo "LABEL Memtest" >> $BOOT_LIST
	echo "  MENU LABEL Memtest86+" >> $BOOT_LIST
	echo "  LINUX $prefix/memtest86+/memtest.bin" >> $BOOT_LIST
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

	echo "[1;32;40mUpdated the SYSLINUX config file ![0m"

	if [ "$EFIMODE" = true ]; then
		cp -af $BOOT_LIST /boot/EFI/BOOT/
		cp -af $BOOT_CFG /boot/EFI/BOOT/
	fi

	return 0
}

copy_theme()
{
	local bootmgr="$1"
	local themename="$2"
	local suffix="$3"

	local logodir="/boot/$bootmgr/themes/$themename"
	local bootcfg="/boot/$bootmgr/${bootmgr}.${suffix}"
	local destdir="/boot/$bootmgr"
	local logo=""

	if [ "$EFIMODE" = true ]; then
		logodir="/boot/EFI/$bootmgr/themes/$themename"
		bootcfg="/boot/EFI/$bootmgr/${bootmgr}.${suffix}"
		destdir="/boot/EFI/BOOT/"
	fi

	cp -af $logodir/${bootmgr}.${suffix} $bootcfg

	if [ ! -e $bootcfg ]; then
		echo "[1;33;40mno such file -- $bootcfg ![0m"
		return 1
	fi

	sed -i -r "s/BreezeOS/$themename/g" $bootcfg

	if [ -f "$logodir/splash.jpg" ]; then
		logo=splash.jpg
	elif [ -f "$logodir/splash.png" ]; then
		logo=splash.png
	elif [ -f "$logodir/splash.bmp" ]; then
		logo=splash.bmp
	fi

	local logoimg="$logodir/$logo"

	if [ -f "$logodir/splash.dat" ]; then
		cp -f "$logodir/splash.dat" $destdir/
	fi

	if [ -f "$logoimg" ]; then
		cp -f "$logoimg" $destdir/
		sed -i -r "s/(breeze|splash)[.](png|jpg)/$logo/g" $bootcfg
	fi
	return 0
}

print_usage()
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

VGA="792"
TMP="/tmp"
INITRD=""
RAID_OPTS=""
BOOT_OPTS=""

KERNELS=""
KERNAME="breeze"
DEFLT_KERNEL=""

DEVICE=""
ROOT_FS=""
ROOT_DEV=""
ROOT_UUID=""

CRYPT=""
BOOT_FS=""
BOOT_DEV=""
BOOT_UUID=""
BOOT_DIR="/boot"
BOOT_MGR="syslinux"
PART_TYPE=""

UEFI=false
EFIMODE=false
EFILABEL=""

LVM=false
FORCE=false
SMACK=false
CONFIG=false
RESCUE=false
ALL_OSES=false
ALWAYS_YES=false
#ALL_KERNELS=false

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

		"-E"|"-efilabel"|"--efilabel")
			EFILABEL="$2"
			shift 2 ;;

		"-e"|"-efi"|"--efi")
			UEFI=true
			shift 1 ;;

		"-L"|"-lvm"|"--lvm")
			LVM=true
			shift 1 ;;

		"-r"|"-rescue"|"--rescue")
			RESCUE=true
			shift 1 ;;

		"-s"|"-smack"|"--smack")
			SMACK=true
			shift 1 ;;

		"-a"|"-all"|"--all")
			ALL_OSES=true
			shift 1 ;;

		"-k"|"-kernel"|"--kernel")
			DEFLT_KERNEL="$2"
			shift 2 ;;

		"-K"|"-kername"|"--kername")
			KERNAME="$2"
			shift 2 ;;

#		"-A"|"-kernels"|"--kernels")
#			ALL_KERNELS=true
#			shift 1 ;;

		"-t"|"-type"|"--type")
			BOOT_MGR="$2"
			shift 2 ;;

		"-g"|"-ptype"|"--ptype")
			PART_TYPE="$(echo $2 | tr '[:upper:]' '[:lower:]')"
			[ "$PART_TYPE" = "s-uefi" ] && UEFI=true
			shift 2 ;;

		"-l"|"-luks"|"--luks")
			CRYPT="luks"
			LUKS_DEVICES="$2"

			if ! echo "$2" | grep -qF '/dev/' ; then
				echo "Error: Invalid LUKS devices !"
				exit 1
			fi
			shift 2 ;;

		"-u"|"-uuid"|"--uuid")
			ROOT_UUID="$2"
			shift 2 ;;

		"-U"|"-bootuuid"|"--bootuuid")
			BOOT_UUID="$2"
			shift 2 ;;

		"-d"|"-dev"|"--dev")
			DEVICE="$2"
			shift 2 ;;

		"-b"|"-bootdir"|"--bootdir")
			BOOT_DIR="$2"
			shift 2 ;;

		"-R"|"-rootdev"|"--rootdev")
			ROOT_DEV="$2"
			shift 2 ;;

		"-B"|"-bootdev"|"--bootdev")
			BOOT_DEV="$2"
			shift 2 ;;

		"-o"|"-opts"|"--opts")
			BOOT_OPTS="$2"
			shift 2 ;;

		"-p"|"-partno"|"--partno")
			PART_NO="$2"
			shift 2 ;;

		"-S"|"-size"|"--size")
			VGA="$(vga_screen_size $2)"
			shift 2 ;;

		"-D"|"-debug"|"--debug")
			DEBUG_ON=true
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

DERIVATIVE="$(grep -F 'SOURCE_DISTRO=' /etc/brzpkg/os-release | cut -f2 -d'=')"
DVERSION="$(grep -F 'VERSION=' /etc/brzpkg/os-release | cut -f2 -d'=')"

if [ -z "$BOOT_MGR" ]; then
	echo "[1;31;40mError: Must specify a boot loader ![0m"
	exit 1
fi

if [ -z "$DEFLT_KERNEL" ]; then
	echo "[1;31;40mError: The default kernel must be specified ![0m"
	exit 1
fi

if [ "$PART_TYPE" = "uefi" -o "$PART_TYPE" = "s-uefi" ]; then
	if [ -e /sys/firmware/efi ]; then
		EFIMODE=true
	fi
	PART_TYPE="gpt"
fi

if [ "$EFIMODE" = false ]; then
	if [ "$UEFI" = true -o "$BOOT_CFG" = "gummiboot" ]; then
		echo "[1;31;40mError: Cannot setup secure UEFI in BIOS mode ![0m"
		exit 1
	fi
fi

if [ ! -d /lib/modules/$DEFLT_KERNEL ]; then
	echo "No modules found for kernel '$DEFLT_KERNEL' !"
	exit 1
fi

find /boot/ -maxdepth 1 -type f | \
	egrep '/(initrd.img|initramfs)[-].*' 1> $TMP/initrd.images

ARCH="$(grep -F 'ARCHITECTURE=' /etc/brzpkg/os-release | cut -f2 -d'=')"

if [ -z "$ARCH" ]; then ARCH="$(uname -m)"; fi

if [ "$ARCH" != "amd64" -a "$ARCH" != "x86-64" ]; then
	BOOTLOADERS="lilo,syslinux,grub"
fi

if ! echo "$BOOTLOADERS" | grep -qF "$BOOT_MGR" ; then
	echo "[1;31;40mError: Invalid boot loader specified -- '$BOOT_MGR' !"
	exit 1
fi

if [ "$LVM" = false ]; then
	if pvscan | grep -q -E '/dev/[sh][d][a-z]|/dev/mapper' ; then
		LVM=true
	fi
fi

BOOT_OPTS="$BOOT_OPTS ro quiet vga=$VGA"

if [ "$DERIVATIVE" = "devuan" ]; then
	if [ -z "$EFILABEL" ]; then
		EFILABEL="Breeze::OS [devuan] $DVERSION"
	fi
elif [ "$DERIVATIVE" = "gentoo" ]; then

	if [ -z "$EFILABEL" ]; then
		EFILABEL="Breeze::OS [gentoo] $DVERSION"
	fi

	BOOT_OPTS="$BOOT_OPTS ro quiet vga=$VGA console=tty1 consoleblank=0"

	if [ "$LVM" = true ]; then
		BOOT_OPTS="$BOOT_OPTS dolvm domdadm"
	fi

	if [ -d /boot/memtest86plus/ -a ! -e /boot/memtest86+/ ]; then
		cd /boot
		ln -s ./memtest86plus ./memtest86+
		cd /
	fi
else
	if [ -z "$EFILABEL" ]; then
		EFILABEL="Breeze::OS [slack] $DVERSION"
	fi
fi

if [ "$BOOT_MGR" = "grub" ]; then
	# load the device-mapper kernel module without which
	# grub-probe does not reliably detect disks and partitions
	DM_MOD="$(find /lib/modules/$DEFLT_KERNEL -name '*.ko' | grep -E -m1 'dm[_-]*mod')"

	if [ -n "$DM_MOD" ]; then
		modprobe "$(basename $DM_MOD '.ko')"
	fi
fi

if [ -z "$DEVICE" -a -n "$ROOT_DEV" ]; then
	DEVICE="$(echo $ROOT_DEV | sed 's/[0-9]*//g')"
fi

if [ -z "$DEVICE" -o -z "$ROOT_DEV" ]; then

	if [ "$ALWAYS_YES" = true ]; then
		echo "[1;33;40mMust specify both drive and root device ![0m"
		exit 1
	fi

	ROOT_DEV="$(cat /proc/mounts | grep -v rootfs | grep -F ' / ' | cut -f1 -d' ' | crunch)"

	if [ -z "$ROOT_DEV" -a -n "$DEVICE" ]; then
		ROOT_DEV="$(blkid | grep -F "$DEVICE" | grep -F 'ROOT_' | cut -f1 -d':')"
	fi

	if [ -z "$ROOT_DEV" ]; then

		while true; do
			echo "[1;33;40mNo root device found -- Please specify one: [0m"

			read ROOT_DEV

			if [ -n "$ROOT_DEV" ]; then
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

	if [ "$ALWAYS_YES" = true ]; then
		echo "[1;33;40mMust specify partition type -- mbr or gpt ![0m"
		exit 1
	fi

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
	ROOT_DEV="$(cat /proc/mounts | grep -v rootfs | grep -F ' / ' | cut -f1 -d' ')"
fi

if [ -z "$BOOT_DEV" ]; then

	if [ "$ALWAYS_YES" = true ]; then
		echo "[1;33;40mMust specify a boot device ![0m"
		exit 1
	fi

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

		if [ $? != 0 ]; then
			echo "Failed to mount the boot partition $BOOT_DEV !"
			umount_device
			exit 1
		fi
		echo "Mounted the boot partition $BOOT_DEV !"
		sleep 1
	fi
	sync
fi

if [ -z "$ROOT_UUID" -a -n "$ROOT_DEV" ]; then
	ROOT_UUID="$(lsblk -n -o uuid $ROOT_DEV)"

	if [ -z "$ROOT_UUID" ]; then
		ROOT_UUID="$(blkid -s UUID -o value $ROOT_DEV)"
	fi
fi

if [ -z "$BOOT_UUID" -a -n "$BOOT_DEV" ]; then
	BOOT_UUID="$(lsblk -n -o uuid $BOOT_DEV)"

	if [ -z "$BOOT_UUID" ]; then
		BOOT_UUID="$(blkid -s UUID -o value $BOOT_DEV)"
	fi
fi

if [ -z "$ROOT_FS" -a -n "$ROOT_DEV" ]; then
	ROOT_FS="$(lsblk -n -o fstype $ROOT_DEV)"

	if [ -z "$ROOT_FS" ]; then
		ROOT_FS="$(blkid -s TYPE -o value $ROOT_DEV)"
	fi
fi

if [ -z "$BOOT_FS" -a -n "$BOOT_DEV" ]; then
	BOOT_FS="$(lsblk -n -o fstype $BOOT_DEV)"

	if [ -z "$BOOT_FS" ]; then
		BOOT_FS="$(blkid -s TYPE -o value $BOOT_DEV)"
	fi
fi

DEVID="$(basename $DEVICE)"
VENDOR="$(lsblk -n -o vendor $DEVICE 2> /dev/null | crunch)"
MODEL="$(lsblk -n -o model $DEVICE 2> /dev/null | crunch)"
SERIAL="$(lsblk -n -o serial $DEVICE 2> /dev/null | crunch)"

if [ -n "$MODEL" ]; then
    DEVMODEL="$(echo ${MODEL} | sed 's/[ -]/_/g')"
fi

if [ -z "$DEVMODEL" ]; then
   DEVMODEL="$(ls -l /dev/disk/by-id | fgrep -m1 $DEVID)"
   DEVMODEL="$(echo "$DEVMODEL" | sed 's/[ ]*->.*//g')"
   DEVMODEL="$(echo "$DEVMODEL" | sed 's/^.*[ ]//g')"
fi

echo "[1;36mMODEL [0m= $DEVMODEL"
echo "[1;36mTYPE  [0m= $PART_TYPE"
echo "[1;36mEFI   [0m= $EFIMODE"
echo "[1;36mDEVICE[0m= $DEVICE"
echo "[1;36mBOOT  [0m=[ '$BOOT_DEV', '$BOOT_FS' ]"
echo "[1;36mROOT  [0m=[ '$ROOT_DEV', '$ROOT_FS' ]"

if [ -z "$ROOT_DEV" ]; then
	echo "Root device was not specified !"
	umount_device
	exit 1
fi

if ls /boot/kernel-vmlinuz* 2> /dev/null | grep -qF 'kernel-' ; then
	rename 'kernel-' '' /boot/kernel-vmlinuz* 2> /dev/null
fi

ls -t /boot/vmlinuz-* | grep -v '.old' 1> $TMP/vmlinuzes

#find /boot/ -maxdepth 1 -type f | \
#	egrep '/vmlinuz[-]' | grep -v '.old' 1> $TMP/vmlinuzes

find /boot/ -maxdepth 1 -type f | \
	egrep '/(initrd.img|initramfs)[-].*' 1> $TMP/initrd.images

cat $TMP/vmlinuzes | grep -F "$DEFLT_KERNEL" 1> $TMP/vmlinuzes.new
cat $TMP/vmlinuzes >> $TMP/vmlinuzes.new
mv $TMP/vmlinuzes.new $TMP/vmlinuzes

if [ "$EFIMODE" = true -a "$BOOT_FS" != "vfat" ]; then
	echo "[1;31;40mFilesystem of boot device must be vfat ![0m"
	umount_device
	exit 1
fi

if [ "$ALWAYS_YES" = false ]; then

	if echo "$ROOT_DEV" | grep -qF '/dev/mapper/luks' ; then
		if [ -z "$CRYPT" ]; then
			CRYPT="luks"
			LUKSNAME="$(basename $ROOT_DEV)"
			LUKS_DEVICES="$ROOT_DEV:$LUKSNAME"
		fi
	fi

	if [ "$DEBUG_ON" = true ]; then
		echo "------------------"
		cat $TMP/vmlinuzes
		echo "------------------"
	fi

	echo ""
	echo -n "Use the above settings (y/n) ? "
	read answer

	if [ "$answer" != "y" ]; then
		echo "Exiting !"
		umount_device
		exit 1
	fi
fi

if [ ! -s $TMP/vmlinuzes ]; then
	echo "No Linux kernels were found !"
	umount_device
	exit 1
fi

list_all_partitions

if ! find_initrd "$DEFLT_KERNEL" "$KERNAME" ; then
	create_initrd "$DEFLT_KERNEL" "$KERNAME"
elif [ "$FORCE" = true ]; then
	create_initrd "$DEFLT_KERNEL" "$KERNAME"
fi

#if [ "$ALL_KERNELS" = true ]; then
#
#	cat $TMP/vmlinuzes | while read kernel; do
#
#		if echo "$kernel" | egrep -q "${DEFLT_KERNEL}$" ; then
#			continue
#		fi
#
#		kernel_version="$(extract_version "$kernel")"
#		kernel_prefix="$(extract_prefix "$kernel" "$kernel_version")"
#
#		if [ -z "$kernel_version" -o ! -d "/lib/modules/$kernel_version" ]; then
#			continue
#		fi
#
#		if ! find_initrd "$kernel_version" "$kernel_prefix" ; then
#			create_initrd "$kernel" "$kernel_prefix"
#		fi
#	done
#fi

find /boot/ -maxdepth 1 -type f | \
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
			cp -af /usr/share/lilo /boot/
		fi
	fi

	cp -af /usr/share/lilo/themes/$BOOT_THEME /boot/lilo/themes/
	copy_theme "$BOOT_MGR" "$BOOT_THEME" "conf"

	if [ ! -f /boot/lilo/lilo.conf ]; then
		echo "Failed to locate lilo.conf !"
		umount_device
		exit 1
	fi

	write_lilo_conf

	if [ "$CONFIG" = false ]; then
		/sbin/lilo -b $DEVICE 2> $TMP/lilo.err
	fi
elif [ "$BOOT_CFG" = "gummiboot" ]; then

	BOOT_LIST="/boot/EFI/loader/loader.conf"
	mkdir -p /boot/EFI/BOOT/
	mkdir -p /boot/EFI/gummiboot/
	mkdir -p /boot/EFI/loader/entries

	write_gummiboot_conf

	if [ "$CONFIG" = true ]; then
		umount_device
		exit 0
	fi

	cp -au /usr/lib/gummiboot/gummibootx64.efi /boot/EFI/gummiboot/

	echo "[1;33;40mRemoving GUMMIBOOT boot manager entries ![0m"
	gummiboot --path /boot remove

	echo "[1;33;40mInstalling GUMMIBOOT boot manager ![0m"
	gummiboot --path /boot install

	if [ "$?" = 0 ]; then
		if [ "$ARCH" = "amd64" -o "$ARCH" = "x86-64" ]; then
			set_efibootmgr gummiboot $DEVICE "X64" "64"
		else
			set_efibootmgr gummiboot $DEVICE "X32" "32"
		fi
	fi
elif [ "$BOOT_MGR" = "syslinux" ]; then

	export EXTLINUX_THEME="BreezeOS"

	if [ -e /usr/lib/syslinux ]; then
		SYSFOLDER=/usr/lib/syslinux/modules
	elif [ -e /usr/share/syslinux ]; then
		SYSFOLDER=/usr/share/syslinux
	fi

	if [ -e $SYSFOLDER/mbr/mbr.bin ]; then
		mbrfile=$SYSFOLDER/mbr/mbr.bin
		gptmbrfile=$SYSFOLDER/mbr/gptmbr.bin
		altmbrfile=$SYSFOLDER/mbr/altmbr.bin
	else
		mbrfile=$SYSFOLDER/mbr.bin
		gptmbrfile=$SYSFOLDER/gptmbr.bin
		altmbrfile=$SYSFOLDER/altmbr.bin
	fi

	if [ "$EFIMODE" = true ]; then
		mkdir -p /boot/EFI/BOOT
		mkdir -p /boot/EFI/syslinux/themes
		SYSLINUX=/boot/EFI/syslinux

		BOOT_LIST="/boot/EFI/syslinux/bootlist.cfg"
		BOOT_CFG="/boot/EFI/syslinux/syslinux.cfg"
	else
		mkdir -p /boot/syslinux/themes
		SYSLINUX=/boot/syslinux

		if [ ! -e /boot/extlinux ]; then
			cd /boot
			ln -s syslinux extlinux
			cd -
		fi
		BOOT_LIST="/boot/syslinux/bootlist.cfg"
		BOOT_CFG="/boot/syslinux/syslinux.cfg"
	fi

	cp $BOOT_LIST ${BOOT_LIST}.${DATE} 2> /dev/null

	if [ "$CONFIG" = true ]; then
		write_syslinux_conf
		umount_device
		exit 0
	fi

	cp $BOOT_CFG ${BOOT_CFG}.${DATE} 2> /dev/null
	cp -af /usr/share/syslinux/themes/$BOOT_THEME $SYSLINUX/themes/
	copy_theme "$BOOT_MGR" "$BOOT_THEME" "cfg"

	write_syslinux_conf

	if [ -e /usr/share/hwdata/pci.ids ]; then
		cp -af /usr/share/hwdata/pci.ids $SYSLINUX/
	fi

	if [ "$EFIMODE" = true ]; then

		if [ -e $SYSFOLDER/efi64/syslinux.efi ]; then
			cp -af $SYSFOLDER/efi64/syslinux.efi $SYSLINUX/
			cp -af $SYSFOLDER/efi64/syslinux.efi \
				/boot/EFI/BOOT/bootx64.efi
		elif [ -e /usr/lib/SYSLINUX.EFI/efi64/syslinux.efi ]; then
			cp -af /usr/lib/SYSLINUX.EFI/efi64/syslinux.efi $SYSLINUX/
			cp -af /usr/lib/SYSLINUX.EFI/efi64/syslinux.efi \
				/boot/EFI/BOOT/bootx64.efi
		else
			echo "Failed to install extlinux on $BOOT_DEV !"
			umount_device
			exit 1
		fi

		cp -af $SYSFOLDER/efi64/*.c32 $SYSLINUX/
		cp -af $SYSFOLDER/efi64/ldlinux.e64 $SYSLINUX/
		cp -af $SYSFOLDER/efi64/ldlinux.e64 /boot/EFI/BOOT/
		cp -af $SYSFOLDER/efi64/{hdt,chain,vesamenu,menu,poweroff}.c32 \
			/boot/EFI/BOOT/
		cp -af $SYSFOLDER/efi64/{libcom32,libutil,libmenu}.c32 \
			/boot/EFI/BOOT/
	else
		cp -af $SYSFOLDER/*.c32 $SYSLINUX/
		cp -af $SYSFOLDER/*.com $SYSLINUX/
	fi

	if [ -f "/proc/mdstat" ]; then
		if [ "$(stat -c %t $BOOT_DEV)" = "9" ]; then 
			RAID_OPTS="--raid"
		fi
	fi

	if [ "$EFIMODE" = true ]; then
		syslinux $RAID_OPTS --install $BOOT_DEV
	else
		extlinux $RAID_OPTS --install /boot/syslinux 2> $TMP/syslinux.err
	fi

	if [ $? != 0 ]; then
		echo "Failed to install extlinux on $BOOT_DEV !"
		umount_device
		exit 1
	fi

	if [ "$PART_TYPE" = "mbr" -o "$PART_TYPE" = "dos" ]; then
		echo "[1;34;40mCopying BIOS MBR to $DEVICE ![0m"
		dd bs=440 count=1 conv=notrunc if=${mbrfile} of=$DEVICE

	elif [ "$PART_TYPE" = "gpt" -o "$EFIMODE" = true ]; then
		echo "[1;34;40mCopying GPT MBR to $DEVICE ![0m"

		if [ -x sgdisk -a -n "$PART_NO" ]; then
			echo "Setting partition $PART_NO on $DEVICE, using sgdisk !"
			sgdisk $DEVICE --attributes=${PART_NO}:set:2
		fi

		if [ $? = 0 ]; then
			dd bs=440 count=1 conv=notrunc if=${gptmbrfile} of=$DEVICE
		fi
	else
		printf "\x${PART_NO}" | cat ${altmbrfile} - | \
			dd bs=440 count=1 iflag=fullblock conv=notrunc of=$DEVICE
	fi

	if [ "$EFIMODE" = true ]; then
		if [ "$ARCH" = "amd64" -o "$ARCH" = "x86-64" ]; then
			set_efibootmgr syslinux $DEVICE "X64" "64"
		else
			set_efibootmgr syslinux $DEVICE "X32" "32"
		fi
	fi
elif [ "$BOOT_MGR" = "grub" ]; then

	export GRUB_THEME="BreezeOS"

	if [ "$EFIMODE" = true ]; then
		BOOT_CFG="/boot/EFI/BOOT/grub.cfg"
		BOOT_LIST="/boot/EFI/BOOT/bootlist.cfg"

		if [ ! -e /boot/EFI/BOOT/theme/ ]; then
			cp -a /usr/share/brzinst/factory/EFI /boot/
		fi
	else
		mkdir -p /boot/grub/
		BOOT_CFG="/boot/grub/grub.cfg"
		BOOT_LIST="/boot/grub/bootlist.cfg"

		export GRUB_DEVICE="$DEVICE"
		export GRUB_DEVICE_UUID="$ROOT_UUID"
	fi

	cp -af $BOOT_LIST ${BOOT_LIST}.${DATE} 2> /dev/null

	cp $BOOT_CFG ${BOOT_CFG}.${DATE} 2> /dev/null

	write_grub_default

	if [ "$CONFIG" = true ]; then
		if [ "$EFIMODE" = true ]; then
			write_grub_conf
		else
			grub-mkconfig -o $BOOT_CFG
		fi
		umount_device
		exit 0
	fi

	copy_theme "$BOOT_MGR" "$BOOT_THEME" "cfg"

	if [ "$EFIMODE" = true ]; then

		grub-install --target=x86_64-efi \
			--efi-directory=/boot --bootloader-id=breezeos \
		--boot-directory=/boot --debug

		if [ $? = 0 ]; then
			if [ "$ARCH" = "amd64" -o "$ARCH" = "x86-64" ]; then
				set_efibootmgr grub $DEVICE "X64" "64"
			else
				set_efibootmgr grub $DEVICE "X32" "32"
			fi
		fi
	else
		grub-install ${DEVICE}
	fi

	if [ $? = 0 ]; then
		if [ "$EFIMODE" = true ]; then
			grub-mkconfig -o $BOOT_CFG
			#write_grub_conf
		else
			grub-mkconfig -o $BOOT_CFG
		fi
	fi
fi

if [ $? != 0 ]; then
	echo "[1;31;40mInstallation of the boot loader failed ![0m"
	umount_device
	exit 1
fi

umount_device

echo "[1;36;40mYour $BOOT_MGR boot loader has been installed ![0m"
echo "[1;33;30mRemember to set your boot order in your BIOS ![0m"

exit 0

# end Breeze::OS setup script
