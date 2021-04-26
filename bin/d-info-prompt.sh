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

# Load settings ...
. d-selected-options.sh

OPTION="$1"

KERNEL="$(cat $TMP/selected-kernel 2> /dev/null)"
DEVICE="$(cat $TMP/selected-device 2> /dev/null)"
DESKTOP="$(cat $TMP/selected-desktop 2> /dev/null)"
BOOTMGR="$(cat $TMP/selected-bootmgr 2> /dev/null)"
GPT_MODE="$(cat $TMP/selected-gpt-mode 2> /dev/null)"
DERIVED="$(cat $TMP/selected-derivative 2> /dev/null)"
RELEASE="$(cat $TMP/selected-release 2> /dev/null)"
NB_PACKAGES="$(cat $TMP/nb-packages 2> /dev/null)" 
DISK_SPACE="$(cat $TMP/total-footprint 2> /dev/null)" 

outfile="$TMP/$OPTION.txt"
textfile="./text/$OPTION.txt"

cp -f "$textfile" "$outfile"

USERNAME="$(cat $TMP/system-username 2> /dev/null)"

TARGET="$(cat $TMP/selected-target | sed -r 's/\//\\\\\//g')"
SOURCE="$(cat $TMP/selected-source | sed -r 's/\//\\\\\//g')"

LOCALE="$(cat $TMP/selected-locale 2> /dev/null)"
TIMEZONE="$(cat $TMP/selected-timezone | sed -r 's/\//\\\\\//g')"
SOURCE_PATH="$(cat $TMP/selected-source-path | sed -r 's/\//\\\\\//g')"

SELECTED_KERNEL="$(uname -snrm 2> /dev/null)"
SELECTED_NET="$(cat $TMP/selected-network 2> /dev/null)"
SELECTED_GATEWAY="$(cat $TMP/selected-gateway 2> /dev/null)"
SELECTED_NAMESERVER="$(cat $TMP/selected-nameserver 2> /dev/null)"

if [ "$OPTION" = "unpack" -o  "$OPTION" = "config" ]; then

	if [ "$USERNAME" = "" ]; then
		USERNAME="was left unset"
	fi

	if [ "$SELECTED_GATEWAY" = "" ]; then
		SELECTED_GATEWAY="unknown"
	fi

	if [ "$SELECTED_NAMESERVER" = "" ]; then
		SELECTED_NAMESERVER="unknown"
	fi

	sed -i -r "s/%username%/$USERNAME/g" $outfile

	sed -i -r "s/%hostname%/$SELECTED_HOSTNAME/g" $outfile
	sed -i -r "s/%gateway%/$SELECTED_GATEWAY/g" $outfile
	sed -i -r "s/%nameserver%/$SELECTED_NAMESERVER/g" $outfile

	sed -i -r "s/%locale%/$LOCALE/g" $outfile
	sed -i -r "s/%timezone%/$TIMEZONE/g" $outfile

	sed -i -r "s/%desktop%/$SELECTED_DESKTOP/g" $outfile
	sed -i -r "s/%workgroup%/$SELECTED_WORKGROUP/g" $outfile
	sed -i -r "s/%internet%/$SELECTED_NET/g" $outfile
	sed -i -r "s/%kernel%/$SELECTED_KERNEL/g" $outfile
	sed -i -r "s/%bootmgr%/$BOOTMGR/g" $outfile

	sed -i -r "s/%source[-]drive%/$SOURCE/g" $outfile
	sed -i -r "s/%target[-]drive%/$TARGET/g" $outfile
	sed -i -r "s/%source[-]path%/$SOURCE_PATH/g" $outfile

	sed -i -r "s/%nb[-]packages%/$NB_PACKAGES/g" $outfile
	sed -i -r "s/%disk[-]space%/$DISK_SPACE/g" $outfile
	sed -i -r "s/%release%/$RELEASE/g" $outfile

elif [ "$OPTION" = "boot" -o "$OPTION" = "bootcfg" ]; then

	DEVICE="$(cat $TMP/boot-partition 2> /dev/null)"

	BOOT_DRIVE="$(cat $TMP/boot-drive 2> /dev/null)"
	BOOT_PARTITION="$(echo $DEVICE | sed -r 's/\//\\\\\//g')"
	BOOT_LOCATION="$(cat $TMP/boot-location | sed -r 's/\//\\\\\//g')"

	DRIVE_NAME="$(cat $TMP/boot-drive-name 2> /dev/null)"
	DRIVE_MODEL="$(lsblk -n -l -o 'model' $BOOT_DRIVE)"
	ROOT_FS="$(lsblk -n -l -o 'fstype' $DEVICE)"
	DRIVE_ID="$(basename $BOOT_DRIVE)"
	PART_NO="$(echo "$DEVICE" | sed -r 's/[^0-9]*//g')"

	sed -i -r "s/%device%/\/dev\/$DRIVE_ID/g" $outfile
	sed -i -r "s/%model%/$DRIVE_MODEL/g" $outfile
	sed -i -r "s/%boot[-]location%/$BOOT_LOCATION/g" $outfile
	sed -i -r "s/%boot[-]partition%/$BOOT_PARTITION/g" $outfile
	sed -i -r "s/%gptmode%/MBR/g" $outfile
	sed -i -r "s/%filesystem%/$ROOT_FS/g" $outfile

fi

clear; cat "$outfile"; read cmd

if [ "$(echo "$cmd" | tr '[:upper:]' '[:lower:]')" = "y" ]; then
	exit 0
fi

exit 1

