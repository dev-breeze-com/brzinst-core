#!/bin/bash
#
# GNU GENERAL PUBLIC LICENSE Version 3
#
# d-grub2.sh GRub2 boot configuration <dev@tsert.com>
# Copyright 2015, Pierre Innocent, Tsert Inc. All Rights Reserved
#
PROMPT="$1"

# Initialize folder paths
. d-dirpaths.sh

DRIVE_NAME="`cat $TMP/drive-model 2> /dev/null`"
BOOT_DEVICE="`cat $TMP/root-device 2> /dev/null`"
BOOT_PARTITION="`cat $TMP/boot-partition 2> /dev/null`"
SELECTED_DRIVE="`cat $TMP/selected-target 2> /dev/null`"
GPT_MODE="`cat $TMP/selected-partition-mode 2> /dev/null`"

DERIVED="`cat $TMP/selected-derivative 2> /dev/null`"
RELEASE="`cat $TMP/selected-release 2> /dev/null`"

ROOT_FS="`lsblk -n -l -o 'fstype' $ROOT_DEVICE`"
DRIVE_ID="`basename $SELECTED_DRIVE`"

umount $MOUNTPOINT
unlink $TMP/boot-configured 2> /dev/null

if [ "$PROMPT" != "gui" ]; then

	d-info-prompt.sh bootcfg

	if [ "$?" != 0 ]; then
		exit 1
	fi

	BOOT_BLOCK="`cat $TMP/selected-target 2> /dev/null`"

	dialog --colors \
		--backtitle "Breeze::OS $RELEASE Installer" \
		--title "Breeze::OS Installation -- GRub Boot Loader Installation" \
		--infobox "\nPlease wait ... Setting your \Z4Boot parameters\Zn" 7 55
fi

cp -f ./images/breeze-grub.jpg \
	/usr/share/images/desktop-base/

mkdir -p $ROOTDIR/boot/

cp -af $BRZDIR/factory/grub $ROOTDIR/boot/

if [ "$GPT_MODE" = "MBR" ]; then
	grub-install --target=i386-pc --force --recheck --debug $SELECTED_DRIVE
elif [ "$GPT_MODE" = "GPT" ]; then
	grub-install --target=i386-pc --force --recheck --debug $SELECTED_DRIVE
elif [ "$GPT_MODE" = "UEFI" ]; then
	grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=breeze_grub --force --recheck --debug $SELECTED_DRIVE
fi

if [ "$?" != 0 ]; then

	if [ "$PROMPT" = "gui" ]; then
		echo "L_BOOT_INSTALL_FAILURE"
		exit 1
	fi

	dialog --colors \
		--backtitle "Breeze::OS $RELEASE Installer" \
		--title "Breeze::OS Installation -- GRub Install Failure" \
		--msgbox "\nWas \Z1unable\Zn to set your \Z4boot device\Zn" 6 55

	exit 1
fi

if [ "$DERIVED" = "debian" ]; then

	chroot $ROOTDIR /usr/sbin/update-grub

	if [ "$?" != 0 ]; then

		if [ "$PROMPT" = "gui" ]; then
			echo "L_BOOT_SETUP_FAILURE"
			exit 1
		fi

		dialog --colors \
			--backtitle "Breeze::OS $RELEASE Installer" \
			--title "Breeze::OS Installation -- GRub Update Failure" \
			--msgbox "\nWas \Z1unable\Zn to update your \Z4boot settings\Zn" 6 60

		exit 1
	fi

	chroot $ROOTDIR mkdir -p /boot/efi/EFI/boot 2> /dev/null
	chroot $ROOTDIR mkdir -p /boot/efi/EFI/breeze 2> /dev/null
	chroot $ROOTDIR cp -f /boot/efi/EFI/debian/grubx64.efi \
		/boot/efi/EFI/boot/bootx64.efi
fi

echo -n "yes" 1> $TMP/boot-configured

if [ "$PROMPT" = "gui" ]; then
	echo "GRUB" 1> $TMP/boot-configured
	echo "L_BIOS_BOOT_ORDER"
	exit 0
fi

dialog --colors \
	--backtitle "Breeze::OS $RELEASE Installer" \
	--title "Breeze::OS Installation -- GRub Boot Loader Installation" \
	--msgbox "\nYour \Z4Grub boot loader\Zn has been \Zrinstalled\Zn !\n\n\
Remember to set your \Z1boot order\Zn in your \Z1BIOS\Zn !\n\n" 9 55

exit 0

# end Breeze::OS setup script
