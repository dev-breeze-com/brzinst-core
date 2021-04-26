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
# Initialize folder paths
. d-dirpaths.sh

RETCODE=
DRIVE_ID=
DRIVE_NAME=

SECTORS=0
SECTOR_SIZE=512
DRIVE_TOTAL=0

RELEASE="`cat $TMP/selected-release 2> /dev/null`"
PRESEED="`cat $TMP/preseed-enabled 2> /dev/null`"

SELECTED_DRIVE=""
SELECTED_MEDIA="`cat $TMP/selected-media 2> /dev/null`"
SELECTED_HOSTNAME="`cat $TMP/selected-hostname 2> /dev/null`"

if [ "$SELECTED_HOSTNAME" = "" ]; then
	SELECTED_HOSTNAME="breeze"
fi

create_disk_log() {

	local bootsz=""
	local device=""
	local DEVICE="$1"
	local SFDISK_USED=false
	local part_sz=""

	sgdisk -p $DEVICE | grep -E '^[ ]+[0-9]+[ ]' 1> $TMP/sgdisk.log

	if [ ! -s $TMP/sgdisk.log ]; then
		sfdisk -l -uM $DEVICE | grep -E '^/dev/' 1> $TMP/sgdisk.log
		echo "yes" 1> $TMP/sfdisk-used
		SFDISK_USED=true
	fi

	sed -r -i "s/^[\t ]*//g" $TMP/sgdisk.log
	sed -r -i "s/[\t ][\t *]*/ /g" $TMP/sgdisk.log

	IDX=0

	while read line; do

		line="`echo "$line" | crunch`"

		if [ "$SFDISK_USED" = true ]; then

			IDX=$(( $IDX + 1 ))

			device="`echo "$line" | cut -f1 -d ' '`"
			part_sz="`echo "$line" | cut -f4 -d ' '`"
			ptype="`echo "$line" | cut -f6 -d ' '`"
			ptype="`echo "$ptype" | tr '[:lower:]' '[:upper:]'`"

		else
			IDX="`echo "$line" | cut -f1 -d ' '`"

			device="${DEVICE}$IDX"

			part_sz="`echo "$line" | cut -f4-5 -d ' '`"
			part_sz="`echo "$part_sz" | sed 's/[.][0 ]*MiB//g'`"

			if [ "`echo "$part_sz" | grep -F 'GiB'`" != "" ]; then
				part_sz="`echo "$part_sz" | sed 's/[ ]*GiB//g'`"
				part_sz="`echo "$part_sz" | sed 's/[.]//g'`"
				part_sz="${part_sz}000"
			fi
			ptype="`echo "$line" | cut -f6 -d ' '`"
			ptype="`echo "$ptype" | tr '[:lower:]' '[:upper:]'`"
		fi

		local psize="$part_sz"
		typeset -i psize

		if [ "$ptype" = "B" -o "$ptype" = "C" -o "$ptype" = "E" -o "$ptype" = "F" ]; then
			mtpt="/windows:vfat:format"
		elif [ "$ptype" = "EF00" -o "$ptype" = "EF" ]; then
			mtpt="/boot/efi:vfat:format"
		elif [ "$ptype" = "EE" -o "$ptype" = "EE" ]; then
			mtpt="/gpt:ext4:format"
		elif [ "$ptype" = "EF01" ]; then
			mtpt="/boot:unknown:format"
		elif [ "$ptype" = "EF02" ]; then
			mtpt="/bios:bios:ignore"
		elif [ "$ptype" = "8200" -o "$ptype" = "82" ]; then
			mtpt="/swap:swap:format"
		elif [ "$ptype" = "8300" -o "$ptype" = "83" ]; then
			mtpt=""
		elif [ "$ptype" = "8E00" -o "$ptype" = "8E" ]; then
			mtpt=""
			echo "lvm" 1> $TMP/selected-disktype
		elif [ "$ptype" = "FD00" -o "$ptype" = "FD" ]; then
			mtpt=""
			echo "raid" 1> $TMP/selected-disktype
		elif [ "$ptype" = "85" ]; then
			mtpt="/none:extended:ignore"
		elif [ 10 -gt "$psize" ]; then
			mtpt="/none"
		else
			mtpt=""
		fi

		if [ "$ptype" != "EF00" -a "$ptype" != "85" ]; then

			d-select-mount.sh "SELECT" "$device" "$ptype" "$mtpt" "$part_sz"

			if [ "$?" = 2 ]; then
				continue
			fi

			if [ "$?" != 0 ]; then
				return 1
			fi
			mtpt="$mtpt:$fstype:format"
		fi

		mtpt="`cat $TMP/selected-mountpoint`"
		echo "$device:$ptype:$part_sz:$mtpt" >> $TMP/selected-scheme

	done < "$TMP/sgdisk.log"

	if [ "`grep -F '/efi' $TMP/selected-scheme`" != "" ]; then
		GPT_MODE="EFI"
		bootsz="`grep -F "/efi" $TMP/selected-scheme | cut -f4 -d ':'`"

	elif [ "`grep -F ":EF02" $TMP/selected-scheme`" != "" ]; then
		GPT_MODE="GPT"
		bootsz="`grep -F "/boot" $TMP/selected-scheme | cut -f4 -d ':'`"

	elif [ "`grep -F "/boot" $TMP/selected-scheme`" != "" ]; then
		GPT_MODE="MBR"
		bootsz="`grep -F "/boot" $TMP/selected-scheme | cut -f4 -d ':'`"
	else
		GPT_MODE="MBR"
	fi

	if [ "$bootsz" = "" ]; then
		echo "0" 1> $TMP/selected-boot-size
	else
		echo "$bootsz" 1> $TMP/selected-boot-size
	fi

	echo "$GPT_MODE" 1> $TMP/selected-gpt-mode

	return 0
}

set_partition_scheme()
{
	local cmd="$1"
	local IDX=1
	local START=63
	local OFFSET=0
	local SECTORS=512000
	local FACTOR=$(( 1024000 / $2 ))
	local BOOTSZ="`cat $TMP/selected-boot-size 2> /dev/null`"
	local SWAPSZ="`cat $TMP/selected-swap-size 2> /dev/null`"
	local RESERVED="`cat $TMP/selected-reserved-size 2> /dev/null`"
	local DRIVESZ=$(( $3 / 1000 - $RESERVED ))

	if [ "$GPT_MODE" = "UEFI" ]; then
		SECTORS=$(( $BOOTSZ * $FACTOR ))
		echo "/dev/${DRIVE_ID}${IDX}:EF00:$BOOTSZ:/boot/efi:vfat:format" \
			1> $TMP/selected-scheme
		echo "63,$SECTORS,L,EF00,*" 1> $TMP/fdisk-scheme
		IDX=$(( $IDX + 1 ))

	elif [ "$GPT_MODE" = "GPT" ]; then
		SECTORS=$(( $BOOTSZ * $FACTOR ))
		echo "/dev/${DRIVE_ID}${IDX}:EF01:$BOOTSZ:/gpt:ext4:format" \
			1> $TMP/selected-scheme
		echo "63,$SECTORS,L,EF01,*" 1> $TMP/fdisk-scheme
		IDX=$(( $IDX + 1 ))

	elif [ "$BOOTSZ" -gt 0 ]; then
		SECTORS=$(( $BOOTSZ * $FACTOR ))
		echo "/dev/${DRIVE_ID}${IDX}:EF01:$BOOTSZ:/boot:ext4:format" \
			1> $TMP/selected-scheme
		echo "63,$SECTORS,L,*" 1> $TMP/fdisk-scheme
		IDX=$(( $IDX + 1 ))
	fi

	START=$(( $START + $SECTORS ))
	START=$(( $START * 8 / 8 + $OFFSET ))

	SECTORS=$(( 2 * $FACTOR ))
	echo "/dev/${DRIVE_ID}${IDX}:EF02:$SECTORS:/none" \
		>> $TMP/selected-scheme
	echo "$START,$SECTORS,L" >> $TMP/fdisk-scheme
	IDX=$(( $IDX + 1 ))

	if [ "$cmd" = "1" ]; then

		START=$(( $START + $SECTORS ))
		START=$(( $START * 8 / 8 + $OFFSET ))

		SECTORS=$(( $SWAPSZ * $FACTOR ))
		echo "/dev/${DRIVE_ID}${IDX}:8200:$SECTORS:/swap:swap:format" \
			>> $TMP/selected-scheme
		echo "$START,$SECTORS,S" >> $TMP/fdisk-scheme
		IDX=$(( $IDX + 1 ))

		START=$(( $START + $SECTORS ))
		START=$(( $START * 8 / 8 + $OFFSET ))

		SECTORS=$(( $DRIVESZ * $FACTOR * 8 / 8 ))
		echo "$START,+,E" >> $TMP/fdisk-scheme
		echo ",+,L" >> $TMP/fdisk-scheme

		echo "/dev/${DRIVE_ID}${IDX}:85:$SECTORS:/none:extended:ignore" \
			>> $TMP/selected-scheme
		IDX=$(( $IDX + 1 ))
		echo "/dev/${DRIVE_ID}${IDX}:$SECTORS:8300:/:ext4:format" \
			>> $TMP/selected-scheme

	elif [ "$cmd" = "2" ]; then

		START=$(( $START + $SECTORS ))
		START=$(( $START * 8 / 8 + $OFFSET ))

		SECTORS=$(( $SWAPSZ * $FACTOR ))
		echo "/dev/${DRIVE_ID}${IDX}:8200:$SECTORS:/swap:swap:format" \
			>> $TMP/selected-scheme
		echo "$START,$SECTORS,S" >> $TMP/fdisk-scheme
		IDX=$(( $IDX + 1 ))

		START=$(( $START + $SECTORS ))
		START=$(( $START * 8 / 8 + $OFFSET ))

		SECTORS=$(( $DRIVESZ * $FACTOR * 30 * 8 / 800 ))
		echo "$START,+,E" >> $TMP/fdisk-scheme
		echo ",$SECTORS,L" >> $TMP/fdisk-scheme

		echo "/dev/${DRIVE_ID}${IDX}:85:$SECTORS:/none:extended:ignore" \
			>> $TMP/selected-scheme
		IDX=$(( $IDX + 1 ))
		echo "/dev/${DRIVE_ID}${IDX}:8300:$SECTORS:/:$FSTYPE" \
			>> $TMP/selected-scheme
		IDX=$(( $IDX + 1 ))

		SECTORS=$(( $DRIVESZ * 70 / 100 * $FACTOR ))
		echo ",+,L" >> $TMP/fdisk-scheme

		echo "/dev/${DRIVE_ID}${IDX}:8300:$SECTORS:/home:$FSTYPE" \
			>> $TMP/selected-scheme

	elif [ "$cmd" = "3" ]; then

		START=$(( $START + $SECTORS ))
		START=$(( $START * 8 / 8 + $OFFSET ))

		SECTORS=$(( $SWAPSZ * $FACTOR ))
		echo "$START,$SECTORS,S" >> $TMP/fdisk-scheme
		echo "/dev/${DRIVE_ID}${IDX}:8200:$SECTORS:/swap:swap:format" \
			>> $TMP/selected-scheme
		IDX=$(( $IDX + 1 ))

		START=$(( $START + $SECTORS ))
		START=$(( $START * 8 / 8 + $OFFSET ))

		SECTORS=$(( $DRIVESZ * $FACTOR * 20 * 8 / 800 ))
		echo "$START,+,E" >> $TMP/fdisk-scheme
		echo ",$SECTORS,L" >> $TMP/fdisk-scheme
		echo ",$SECTORS,L" >> $TMP/fdisk-scheme

		echo "/dev/${DRIVE_ID}${IDX}:85:$SECTORS:/none:extended:ignore" \
			>> $TMP/selected-scheme
		IDX=$(( $IDX + 1 ))
		echo "/dev/${DRIVE_ID}${IDX}:8300:$SECTORS:/:ext4:format" \
			>> $TMP/selected-scheme
		IDX=$(( $IDX + 1 ))
		echo "/dev/${DRIVE_ID}${IDX}:8300:$SECTORS:/var:ext4:format" \
			>> $TMP/selected-scheme
		IDX=$(( $IDX + 1 ))

		SECTORS=$(( $DRIVESZ * 60 / 100 * $FACTOR ))
		echo ",,L" >> $TMP/fdisk-scheme

		echo "/dev/${DRIVE_ID}${IDX}:8300:$SECTORS:/home:ext4:format" \
			>> $TMP/selected-scheme

	elif [ "$cmd" = "4" ]; then

		START=$(( $START + $SECTORS ))
		START=$(( $START * 8 / 8 + $OFFSET ))

		SECTORS=$(( $SWAPSZ * $FACTOR ))
		echo "$START,$SECTORS,S" >> $TMP/fdisk-scheme
		echo "/dev/${DRIVE_ID}${IDX}:8200:$SECTORS:/swap:swap:format" \
			>> $TMP/selected-scheme
		IDX=$(( $IDX + 1 ))

		START=$(( $START + $SECTORS ))
		START=$(( $START * 8 / 8 + $OFFSET ))

		SECTORS=$(( $DRIVESZ * $FACTOR * 20 * 8 / 800 ))
		echo "$START,+,E" >> $TMP/fdisk-scheme
		echo ",$SECTORS,L" >> $TMP/fdisk-scheme
		echo ",$SECTORS,L" >> $TMP/fdisk-scheme
		echo ",$SECTORS,L" >> $TMP/fdisk-scheme

		echo "/dev/${DRIVE_ID}${IDX}:85:$SECTORS:/none:extended:ignore" \
			>> $TMP/selected-scheme
		IDX=$(( $IDX + 1 ))
		echo "/dev/${DRIVE_ID}${IDX}:8300:$SECTORS:/:ext4:format" \
			>> $TMP/selected-scheme
		IDX=$(( $IDX + 1 ))
		echo "/dev/${DRIVE_ID}${IDX}:8300:$SECTORS:/var:ext4:format" \
			>> $TMP/selected-scheme
		IDX=$(( $IDX + 1 ))
		echo "/dev/${DRIVE_ID}${IDX}:8300:$SECTORS:/share:ext4:format" \
			>> $TMP/selected-scheme
		IDX=$(( $IDX + 1 ))

		SECTORS=$(( $DRIVESZ * 40 / 100 * $FACTOR ))
		echo ",+,L" >> $TMP/fdisk-scheme
		echo "/dev/${DRIVE_ID}${IDX}:8300:$SECTORS:/home:ext4:format" \
			>> $TMP/selected-scheme
	fi
	return 0
}

# Main starts here ...

unlink $TMP/fdisk-scheme 2> /dev/null
unlink $TMP/selected-scheme 2> /dev/null

while [ 0 ]; do

	dialog --colors \
		--backtitle "Breeze::OS $RELEASE Installer" \
		--title "Breeze::OS Setup -- Installation Setup" \
		--menu "\nSelect an option below ..." 15 55 7 \
"LAPTOP" "Activate laptop devices" \
"HOSTNAME" "Select your host name" \
"SOURCE" "Select your install media" \
"DRIVES" "Select a hard drive" \
"PARTITION" "Partition selected hard drive" \
"FORMATTING" "Format selected hard drive" \
"TARGET" "Select your installation drive" 2> $TMP/retcode

	if [ "$?" = 0 ]; then
		RETCODE="`cat $TMP/retcode`"
	else
		clear
		unlink $TMP/retcode 2> /dev/null
		exit 1
	fi

	if [ "$RETCODE" = "LAPTOP" ]; then

		clear
		cat ./text/pcmcia.txt
		read command
		command="`echo $command | tr '[:upper:]' '[:lower:]'`"

		if [ "$command" = "y" .o "$command" = "yes" ]; then
			/etc/rc.d/rc.pcmcia start
		else
			/etc/rc.d/rc.pcmcia stop
		fi
		RETCODE="HOSTNAME"
	fi

	if [ "$RETCODE" = "HOSTNAME" ]; then

		dialog --colors \
			--backtitle "Breeze::OS $RELEASE Installer" \
			--title "Breeze::OS Setup -- Hostname Selection" \
			--inputbox "\nEnter a hostname (alpha-numeric characters only) !" 9 55 \
			"$SELECTED_HOSTNAME" 2> $TMP/selected-hostname

		if [ "$?" != 0 ]; then
			continue
		fi

		SELECTED_HOSTNAME="`cat $TMP/selected-hostname`"
		name_ok="`echo "$SELECTED_HOSTNAME" | grep -E '^[a-zA-Z][a-zA-Z0-9]*$'`"

		if [ "$name_ok" = "" ]; then

			unlink $TMP/selected-hostname 2> /dev/null

			dialog --colors \
				--backtitle "Breeze::OS $RELEASE Installer" \
				--title "Breeze::OS Setup -- Hostname Selection" \
				--msgbox "\nAn invalid hostname was provided !\n" 7 50

			continue
		fi

		echo "$SELECTED_HOSTNAME" 1> /etc/hostname
		echo "$SELECTED_HOSTNAME" 1> /etc/HOSTNAME
		echo "$SELECTED_HOSTNAME" 1> $TMP/etc_hostname
		echo "localdomain" 1> $TMP/selected-domain

		cp -f $BRZDIR/factory/hosts /etc/
		cp -f $BRZDIR/factory/hosts.allow /etc/
		cp -f $BRZDIR/factory/hosts.deny /etc/
		sed -i "s/kodiak_light/$SELECTED_HOSTNAME/g" /etc/hosts

		RETCODE="SOURCE"

		dialog --colors \
			--backtitle "Breeze::OS $RELEASE Installer" \
			--title "Breeze::OS Setup -- Network Configuration" \
			--yesno "\nConfigure network (yes/no) ?\n" 7 50

		if [ "$?" = 0 ]; then
			d-network.sh dialog
		fi
	fi

	if [ "$RETCODE" = "SOURCE" ]; then

		dialog --colors \
			--backtitle "Breeze::OS $RELEASE Installer" \
			--title "Breeze::OS Setup -- Source Selection" \
			--default-item "CDROM" \
			--menu "\nSelect a \Z1source\Zn for packages ..." 12 55 4 \
		"CDROM" "Retrieve packages from a CDROM" \
		"USB" "Retrieve packages from a ZIP drive" \
		"NET" "Retrieve packages from master computer" \
		"ISO" "Retrieve packages from an ISO file" \
		"DISK" "Retrieve packages from a DISK drive" 2> $TMP/selected-media
#		"WEB" "Retrieve packages from web repository"

		if [ "$?" != 0 ]; then
			echo -n "none" 1> $TMP/selected-media
			continue
		fi

		SELECTED_MEDIA="`cat $TMP/selected-media`"
		export SELECTED_MEDIA

		d-select-drive.sh cdroms "CDROM"

		if [ "$SELECTED_MEDIA" = "NET" ]; then
			d-source-net.sh
#		elif [ "$SELECTED_MEDIA" = "WEB" ]; then
#			d-source-web.sh
		else
			# SELECTED_MEDIA = USB, DISK, CDROM
			d-select-drive.sh source $SELECTED_MEDIA
		fi

		if [ "$?" = 0 ]; then
			SELECTED_SOURCE="`cat $TMP/selected-source`"
			export SELECTED_SOURCE
			RETCODE="DRIVES"
		fi
	fi

	if [ "$RETCODE" = "DRIVES" ]; then

		unlink $TMP/selected-partition-mode 2> /dev/null

		d-select-drive.sh

		if [ "$?" != 0 ]; then
			unlink $TMP/selected-drive 2> /dev/null
			continue
		fi

		SELECTED_DRIVE="`cat $TMP/selected-drive 2> /dev/null`"
		export SELECTED_DRIVE

		lsblk -n -l -o 'kname' $SELECTED_DRIVE \
			1> $TMP/lsblk.log 2> $TMP/lsblk.err

		while read device; do
			umount "/dev/$device" 2> /dev/null
		done < $TMP/lsblk.log

		DRIVE_ID="`cat $TMP/drive-id 2> /dev/null`"
		DRIVE_TOTAL="`cat $TMP/drive-total 2> /dev/null`"
		SECTOR_SIZE="`cat $TMP/sector-size 2> /dev/null`"
		GPT_MODE="`cat $TMP/selected-gpt-mode 2> /dev/null`"
		export DRIVE_TOTAL SECTOR_SIZE GPT_MODE SELECTED_DRIVE

		d-show-partitions.sh true partition $SELECTED_DRIVE
		RETCODE="`cat $TMP/disk-command`"

		unlink $TMP/selected-scheme 2> /dev/null
		touch $TMP/selected-scheme

		if [ "$RETCODE" = "FORMATTING" ]; then
			create_disk_log $SELECTED_DRIVE
		elif [ "$RETCODE" = "PARTITION" ]; then
			d-select-disktype.sh
			d-4k-drive.sh $SELECTED_DRIVE
		fi

		if [ "$?" != 0 ]; then
			RETCODE="DRIVES"
			continue
		fi
	fi

	DRIVE_TOTAL="`cat $TMP/drive-total 2> /dev/null`"
	SELECTED_DRIVE="`cat $TMP/selected-drive 2> /dev/null`"
	SECTOR_SIZE="`cat $TMP/sector-size 2> /dev/null`"
	export DRIVE_TOTAL SECTOR_SIZE GPT_MODE SELECTED_DRIVE

	if [ "$RETCODE" = "PARTITION" -a "$SELECTED_DRIVE" != "" ]; then

		touch $TMP/selected-scheme
		touch $TMP/fdisk-scheme

		dialog --colors \
			--backtitle "Breeze::OS $RELEASE Installer" \
			--title "Breeze::OS Setup -- Partitioning" \
			--menu "\nSelect a partitioning mode for /dev/$DRIVE_ID!" 11 55 3 \
		"default" "Use Default Mode" \
		"expert" "Use Expert Mode (cfdisk/cgdisk)" \
		"skip" "Skip partitioning" 2> $TMP/selected-partition-mode

		if [ "$?" != 0 ]; then
			unlink $TMP/selected-partition-mode 2> /dev/null
			continue
		fi

		PARTITION_MODE="`cat $TMP/selected-partition-mode`"
		export PARTITION_MODE

		if [ "$PARTITION_MODE" = "skip" ]; then

			create_disk_log $SELECTED_DRIVE

			if [ "$?" = 0 ]; then
				RETCODE="FORMATTING"
			fi
		elif [ "$PARTITION_MODE" = "expert" ]; then

			if [ "$GPT_MODE" = "MBR" ]; then
				if [ "$SECTOR_SIZE" = "512" ]; then
					cfdisk $SELECTED_DRIVE
				else
					cfdisk -H 224 -S 56 $SELECTED_DRIVE
				fi
			else
				cgdisk $SELECTED_DRIVE
			fi

			create_disk_log $SELECTED_DRIVE

			if [ "$?" = 0 ]; then
				RETCODE="FORMATTING"
			fi
		else
			d-select-swap-size.sh

			if [ "$?" != 0 ]; then
				RETCODE="DRIVES"
				continue
			fi

			clear
			cat ./text/scheme.txt
			read cmd

			if [ "$cmd" != "1" -a "$cmd" != "2" -a \
				"$cmd" != "3" -a "$cmd" != "4" ]; then
				RETCODE="DRIVES"
				continue
			fi

			set_partition_scheme $cmd $SECTOR_SIZE $DRIVE_TOTAL

			if [ "$GPT_MODE" = "MBR" ]; then
				d-partition.sh
			else
				d-gpt-partition.sh
			fi

			if [ "$?" = 0 ]; then
				RETCODE="`cat $TMP/disk-command 2> /dev/null`"
			fi
		fi
	fi

	if [ "$RETCODE" = "FORMATTING" -a "$SELECTED_DRIVE" != "" ]; then

		d-format-drive.sh

		if [ "$?" = 0 ]; then
			RETCODE="TARGET"
		fi
	fi

	if [ "$RETCODE" = "TARGET" ]; then

		d-select-drive.sh target

		if [ "$?" = 0 ]; then
			exit 0
		fi

		if [ "$?" = 3 ]; then
			RETCODE="PARTITION"
		fi
	fi
done

exit 1

# end Breeze::OS setup script
