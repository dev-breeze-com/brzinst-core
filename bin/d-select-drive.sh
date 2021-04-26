#!/bin/bash
#
# GNU GENERAL PUBLIC LICENSE Version 3
#
# Copyright 2015 Pierre Innocent, Tsert Inc. All rights reserved.
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
. d-dirpaths.sh

MEDIA="$2"
ARGUMENT="$1"
SELECTED_MEDIA="$2"

DERIVED="`cat $TMP/selected-derivative 2> /dev/null`"
RELEASE="`cat $TMP/selected-release 2> /dev/null`"

GPT_MODE="`cat $TMP/selected-gpt-mode 2> /dev/null`"
DRIVE_TOTAL="`cat $TMP/drive-total 2> /dev/null`"
SELECTED_DRIVE="`cat $TMP/selected-drive 2> /dev/null`"
SELECTED_DEVICE="`cat $TMP/selected-device 2> /dev/null`"

unlink $TMP/drives 2> /dev/null
touch $TMP/drives

select_path() {

	local mtpt="$MOUNTPOINT"

	while true; do
		dialog --colors --clear \
			--backtitle "Breeze::OS $RELEASE Installer" \
			--title "Breeze::OS Setup -- Selecting Source of Packages" \
			--inputbox "\nEnter a path !" 9 55 "" 2> $TMP/selected-source-path

		if [ "$?" != 0 ]; then
			exit 1
		fi

		local path="`cat $TMP/selected-source-path`"

		if [ -f "$mtpt/$path" ]; then
			echo "$mtpt/$path" 1> $TMP/selected-source-path
			return 0
		fi

		dialog --colors --clear \
			--backtitle "Breeze::OS $RELEASE Installer" \
			--title "Breeze::OS Setup -- Selecting Source of Packages" \
			--msgbox "\nNot a valid path -- $path\n\n" 7 60
	done

	return 1
}

check_install_media() {

	RETCODE=1
	REMOUNT=true

	MEDIA="$1"
	DEVICE="$2"
	MOUNTPOINT="$3"
	LSB_RELEASE="$MOUNTPOINT/lsb-release"

	dialog --colors \
		--backtitle "Breeze::OS $RELEASE Installer" \
		--title "Breeze::OS Setup -- Select Source of Packages" \
		--infobox "\nAccessing $MEDIA $DEVICE using $MOUNTPOINT ...\n\n" 7 60

	mounted="`mount | grep -F "$device" | cut -f 3 -d ' '`"

	if [ "$mounted" != "" ]; then
		if [ "$mounted" = "$MOUNTPOINT" ]; then
			REMOUNT=false
		else
			umount $DEVICE 2> $TMP/umount.errlog
			sleep 1
		fi
	fi

	if [ "$REMOUNT" = true ]; then
		if [ "$MEDIA" = "CDROM" ]; then
			mount -o ro -t iso9660 $DEVICE $MOUNTPOINT \
				1> /dev/null 2> $TMP/mount.errlog
		else
			mount -o ro $DEVICE $MOUNTPOINT \
				1> /dev/null 2> $TMP/mount.errlog
		fi
	fi

	if [ "$?" != 0 ]; then
		dialog --colors \
			--backtitle "Breeze::OS $RELEASE Installer" \
			--title "Breeze::OS Setup -- Select Source of Packages" \
			--msgbox "\n$MEDIA $DEVICE failed to mount properly. Try again !\n\n" 7 60
		return 1
	fi

	for t in 1 2 3 4 5; do

		if [ -f "$LSB_RELEASE" ]; then
			if grep -qF 'DISTRIB_ID=Breeze::OS' $LSB_RELEASE ; then
				RETCODE=0
			fi
		fi

		if [ "$RETCODE" = 0 ]; then
			dialog --colors \
				--backtitle "Breeze::OS $RELEASE Installer" \
				--title "Breeze::OS Setup -- Select Source of Packages" \
				--msgbox "\nBreeze::OS \Z1INSTALL $MEDIA\Zn was recognized !\n\n" 7 60
			return 0
		fi
		sleep 2
	done

	dialog --colors \
		--backtitle "Breeze::OS $RELEASE Installer" \
		--title "Breeze::OS Setup -- Select Source of Packages" \
		--msgbox "\nBreeze::OS \Z1INSTALL $MEDIA\Zn was not recognized !\n\n" 7 60

	return 1
}

list_drives() {

	local size=0
	local count=1
	local cdrom=0
	local filename="$1"
	local argument="$2"

	echo "--menu \"\" 0 60 0 \\" 1> $filename

	/bin/lsblk -d -n -l -o 'kname,rm,type,model' 1> $TMP/lsblk.log

	/bin/sed -i "s/[ ][ ]*/ /g" $TMP/lsblk.log

	while read line; do

		device="`echo "$line" | cut -f 1 -d ' '`"
		removable="`echo "$line" | cut -f 2 -d ' '`"
		type="`echo "$line" | cut -f 3 -d ' '`"

		if [ "$type" = "disk" ]; then
			model="`echo "$line" | sed 's/^.*disk //g'`"
		else
			model="`echo "$line" | sed 's/^.*rom //g'`"
		fi

		hdd_sz="`grep -E "$device[^0-9]" $TMP/all-disks`"

		if [ "$SELECTED_MEDIA" = "USB" ]; then
			if [ "$type" != "disk" -o "$removable" != "1" -o -z "$hdd_sz" ]; then
				continue
			fi
		elif [ "$SELECTED_MEDIA" = "CDROM" ]; then
			if [ "$removable" != "1" ]; then
				continue
			fi
			if [ "$hdd_sz" != "" -a "$type" != "rom" ]; then
				continue
			fi
		fi

		if [ -z "$hdd_sz" -o "$type" = "rom" ]; then
			echo "/dev/$device=CDROM" >> $TMP/drives
			echo "\"/dev/$device\" \"[$count] $model [ CDROM ]\" \\" >> $filename

			if [ "$argument" = "cdroms" ]; then
				echo "/dev/$device /media/cdrom$cdrom" >> $TMP/detected-cdroms
				cdrom=$(( $cdrom + 1 ))
			fi
			count=$(( $count + 1 ))
		else
			echo "/dev/$device=DISK" >> "$TMP/drives"

			size="`echo "$hdd_sz" | sed 's/.*[:] //g'`"
			size=$(( size * 1024 / 1000000000 ))

			mounted="`mount | grep -F "$device" | cut -f 3 -d ' '`"

			if [ -z "$mounted" ]; then
				echo "\"/dev/$device\" \"[$count] $model [ ${size}G (available)]\" \\" >> $filename
			else
				echo "\"/dev/$device\" \"[$count] $model [ ${size}G (\Z1in use\Zn)]\" \\" >> $filename
			fi
			count=$(( $count + 1 ))
		fi
	done < $TMP/lsblk.log

	if [ "$count" -lt 2 -a "$argument" = "source" ]; then
		dialog --colors \
			--backtitle "Breeze::OS $RELEASE Installer" \
			--title "Breeze::OS Setup -- Select Source of Packages" \
			--msgbox "\nNo $MEDIA device was found !\n\n" 7 60
		return 1
	fi
	return 0
}

select_partition()
{
	local count=1
	local device="$1"
	local title="$2"

	lsblk -n -l -o 'kname,type,size' $device | grep -F part 1> $TMP/lsblk.log

	/bin/sed -i "s/[ ][ ]*/ /g" $TMP/lsblk.log

	echo "--menu \"\" 0 60 0 \\" 1> $TMP/disk-usb.log

	cat $TMP/lsblk.log | while read line; do
		id="`echo "$line" | cut -f 1 -d ' '`"
		sz="`echo "$line" | cut -f 3 -d ' '`"
		echo "\"/dev/$id\" \"/dev/$id [ Partition_${count} -- $sz ]\" \\" >> $TMP/disk-usb.log
		count=$(( $count + 1 ))
	done

	dialog --colors \
		--backtitle "Breeze::OS $RELEASE Installer" \
		--title "$title" \
		--file $TMP/disk-usb.log 2> $TMP/selected-partition

	return $?
}

# Main starts here ...

if [ "$MEDIA" != "$SELECTED_MEDIA" ]; then

	dialog --colors \
		--backtitle "Breeze::OS $RELEASE Installer" \
		--title "Breeze::OS Setup -- Hard Drive Selection" \
		--msgbox "\nYou may be running a computer with \Z1corrupted memory\Zn.\n\n                 Proceed anyways ?\n\n" 9 60

	if [ "$?" != 0 ]; then
		exit 1
	fi
	MEDIA="$SELECTED_MEDIA"
fi

if [ "$ARGUMENT" = "cdroms" ]; then
	unlink $TMP/detected-cdroms 1> /dev/null 2>&1
	touch $TMP/detected-cdroms 1> /dev/null 2>&1
fi

if [ "$BREEZE_PLATFORM" = "freebsd" ]; then
	sysctl kern.disks 1> $TMP/all-disks-bsd 2> /dev/null
fi

sfdisk -s 1> $TMP/all-disks 2> /dev/null

list_drives $TMP/all-drives $ARGUMENT

if [ "$?" != 0 ]; then 
	exit 1
fi

if [ "$ARGUMENT" = "cdroms" ]; then
	exit 0
elif [ "$ARGUMENT" = "rescue" ]; then
	title="Breeze::OS Rescue -- Select Your Rescue Drive"
elif [ "$ARGUMENT" = "target" ]; then
	title="Breeze::OS Setup -- Select Your Installation Drive"
elif [ "$ARGUMENT" = "boot" ]; then
	title="Breeze::OS Setup -- Select Your Boot Drive"
elif [ "$ARGUMENT" = "memboost" ]; then
	title="Breeze::OS Setup -- Select \ZbMemboost\Zn Drive"
elif [ "$ARGUMENT" = "source" ]; then
	title="Breeze::OS Setup -- Select Source of Packages"
else
	title="Breeze::OS Setup -- Hard Drive Selection"

	if [ -f "$TMP/etc_fstab" ]; then
		dialog --colors \
			--backtitle "Breeze::OS $RELEASE Installer" \
			--title "Breeze::OS Setup -- Hard Drive Selection" \
			--defaultno \
			--yesno "\nTo start selecting your partitions anew;\n\
			reset your filesystem table (Yes/No) ?" 6 70

		if [ "$?" = 0 ]; then
			unlink $TMP/boot-selected 2> /dev/null
			unlink $TMP/root-device 2> /dev/null
			unlink $TMP/etc_fstab 2> /dev/null
			unlink $TMP/fstab 2> /dev/null
		fi
	fi
fi

dialog --colors \
	--backtitle "Breeze::OS $RELEASE Installer" \
	--title "$title" \
	--file $TMP/all-drives 2> $TMP/selected-device

if [ "$?" != 0 ]; then 
	exit 1
fi

DEVICE="`cat $TMP/selected-device 2> /dev/null`"

if [ "$ARGUMENT" = "rescue" ]; then

	select_partition "$DEVICE" "$title"

	if [ "$?" = 0 ]; then
		PARTITION="`cat $TMP/selected-partition`"
		mount -o rw $PARTITION $ROOTDIR
	fi

	if [ "$?" != 0 ]; then
		dialog --colors \
			--backtitle "Breeze::OS $RELEASE Installer" \
			--title "Breeze::OS Setup -- Rescue Drive ($DEVICE)" \
			--msgbox "\nCould not mount your root partition !\n" 7 55
	fi
	exit $?
fi

if [ "$ARGUMENT" = "boot" ]; then

	DRIVE_ID="`basename $DEVICE`"

	NAME="`ls -l /dev/disk/by-id | \
		grep -F -m 1 "/$DRIVE_ID" | sed -r 's/ [-]>.*$//g'`"
	NAME="`echo "$NAME" | sed -r 's/^.*[ ]//g'`"

	echo -n "$DEVICE" 1> $TMP/selected-boot-drive
	echo -n "$NAME" 1> $TMP/boot-drive-name

	exit 0
fi

if [ "$ARGUMENT" = "target" ]; then

	echo -n "$DEVICE" 1> $TMP/selected-target

	NAME="`basename "$DEVICE"`"
	MOUNTED="`mount | grep -F "$DEVICE" | cut -d ' ' -f 3`"

	for m in $MOUNTED; do
		if [ "$m" = "/" -o "$m" = "$ROOTDIR" ]; then
			exit 0
		fi
	done

	dialog --colors \
		--backtitle "Breeze::OS $RELEASE Installer" \
		--title "Breeze::OS Setup -- Disk Partitions" \
		--defaultno \
		--yesno "\nThe selected drive is not mounted on the \Z1root filesystem\Zn.\n\
You must reselect your partitions; proceed (Yes/No) ?" 8 60

	if [ "$?" = 0 ]; then
		exit 3
	fi
	exit 1
fi

if [ "$ARGUMENT" = "source" -o "$ARGUMENT" = "memboost" ]; then

	echo -n "$DEVICE" 1> $TMP/selected-source
	echo -n "$MOUNTPOINT" 1> $TMP/selected-source-path

	MEDIA_TYPE="`grep -F "$DEVICE" $TMP/drives`"
	MEDIA_TYPE="`echo "$MEDIA_TYPE" | cut -f 2 -d '='`"

	if [ "$SELECTED_MEDIA" = "CDROM" -a "$MEDIA_TYPE" = "CDROM" ]; then
		check_install_media "CDROM" "$DEVICE" "$MOUNTPOINT"

	elif [ "$SELECTED_MEDIA" = "USB" -a "$ARGUMENT" != "memboost" ]; then
		check_install_media "USB" "$DEVICE" "$MOUNTPOINT"

	else
		select_partition "$DEVICE" "$title"

		if [ "$?" = 0 ]; then

			PARTITION="`cat $TMP/selected-partition`"

			if [ "$ARGUMENT" = "memboost" ]; then
				echo -n "$PARTITION" 1> $TMP/selected-memboost
				exit 0
			fi

			echo "$MOUNTPOINT" 1> $TMP/selected-source-path
			check_install_media "$MEDIA" "$PARTITION" "$MOUNTPOINT"

			if [ "$?" = 0 -a "$SELECTED_MEDIA" = "DISK" ]; then
				select_path $MOUNTPOINT
				exit $?
			fi
		fi
	fi
	exit "$?"
fi

SELECTED_DRIVE="$DEVICE"
echo $DEVICE 1> $TMP/selected-drive

DRIVE_ID="`basename $SELECTED_DRIVE`"
echo $DRIVE_ID 1> $TMP/drive-id

DRIVE_TOTAL="`cat $TMP/all-disks | grep -F -m 1 $DRIVE_ID`"
DRIVE_TOTAL="`echo "$DRIVE_TOTAL" | sed -r 's/^[^ ]*[ ]*//g'`"

echo "$DRIVE_TOTAL" 1> $TMP/drive-total

exit 0

# end Breeze::OS setup script
