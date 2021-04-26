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

SELECTED_DRIVE="$1"

EFI="`cat $TMP/efi-enabled 2> /dev/null`"
DISKTYPE="`cat $TMP/selected-disktype 2> /dev/null`"
GPT_MODE="`cat $TMP/selected-gpt-mode 2> /dev/null`"
RELEASE="`cat $TMP/selected-release 2> /dev/null`"

if [ -z "$SELECTED_DRIVE" ]; then
	SELECTED_DRIVE="`cat $TMP/selected-drive 2> /dev/null`"
fi

/bin/lsblk -d -n -l -o 'phy-sec' $SELECTED_DRIVE | \
	grep -E '[0-9]+' 1> $TMP/sector-size

SECTOR_SIZE="`cat "$TMP/sector-size" | sed -r 's/[\t\n ]+//g'`"

dialog --colors \
	--backtitle "Breeze::OS $RELEASE Installer" \
	--title "Breeze::OS Setup -- Disk Sector Size ($SELECTED_DRIVE)" \
	--default-item "$SECTOR_SIZE" \
	--menu "\nIf your drive is \Z1newer\Zn than \Z12010\Zn and \Z1larger\Zn than \Z1750 GB\Zn; then it may be a \Z14K\Zn drive. Most drives have, either a\n\Z1512\Zn or \Z14K\Zn sector size. The installer sees your drive having a sector size of \Z1$SECTOR_SIZE\Zn KB.\n\nSelect the right value, if erroneous ?" 15 60 2 \
"512" "512 Sector Size" \
"4K" "4K Sector Size" 2> $TMP/sector-size

if [ "$?" != 0 ]; then
	echo "512" 1> $TMP/sector-size
	exit 1
fi

cat << EOF > $TMP/tempscript
dialog --colors \\
	--backtitle "Breeze::OS $RELEASE Installer" \\
	--title "Breeze::OS Setup -- Partitioning Mode ($SELECTED_DRIVE)" \\
	--default-item "$GPT_MODE" \\
	--menu "\n\Z1UEFI\Zn stands for Unified Extensible Firmware Interface; and should only be used, if you have a computer preloaded with Windows which is \Z1newer\Zn than 2010; and you want to do the installation on the primary hard drive.\n\n\Z1GPT\Zn stands for GUID Partitioning Table; and allows hard drives greater than 2TB to be partitioned. \Z1GPT\Zn works with computers \Z1older\Zn than 2010; but should be selected for computers \Z1newer\Zn than 2010.\n\nSelect \Z1MBR\Zn, if you want to run a \Z1standalone\Zn Linux system; and your \ZbBIOS\Zn allows non-secure boot.\n\nSelect your partitioning mode ?" 22 78 3 \\
"MBR" "Standard partitioning for computers older than 2010" \\
"GPT" "Modern partitioning to create partitions > 1TB" \\
EOF

if [ "$EFI" = "yes" ]; then
	echo "\"UEFI\" \"UEFI partitioning for computers newer than 2010\" \\" >> $TMP/tempscript
else
	echo "\"UEFI\" \"UEFI partitioning not enabled for this version\" \\" >> $TMP/tempscript
fi

echo "2> $TMP/selected-gpt-mode" >> $TMP/tempscript

. $TMP/tempscript

if [ "$?" != 0 ]; then
	exit 1
fi

GPT_MODE="`cat $TMP/selected-gpt-mode 2> /dev/null`"

#if [ "$GPT_MODE" = "UEFI" -a "$EFI" = "no" ]; then
#	GPT_MODE="MBR"
#	dialog --colors \
#		--backtitle "Breeze::OS $RELEASE Installer" \
#		--title "Breeze::OS Setup -- Boot Partition Size" \
#		--msgbox "\nCannot select \Z1UEFI\Zn -- Selecting \Z1MBR\Zn instead !" 7 55
#	echo "MBR" 1> $TMP/selected-gpt-mode
#fi

#	--menu "\n\Z1UEFI\Zn and our method of partitoning mandates the presence of a boot partition, whose recommended size is \Z1256M\Zn.\n\nYou may choose \Z1no separate\Zn boot partition, only if your partitioning mode was \Z1MBR\Zn.\n\n

dialog --colors \
	--backtitle "Breeze::OS $RELEASE Installer" \
	--title "Breeze::OS Setup -- Boot Partition Size" \
	--default-item "256" \
	--menu "\n\Z1UEFI\Zn and our method of partitoning mandates the presence of a boot partition, whose recommended size is \Z1256M\Zn.\n\nSelect the boot partition size !" 15 55 3 \
"128" "A boot partition of 128M" \
"192" "A boot partition of 192M" \
"256" "A boot partition of 256M" 2> $TMP/selected-boot-size

exit $?

# end Breeze::OS setup script
