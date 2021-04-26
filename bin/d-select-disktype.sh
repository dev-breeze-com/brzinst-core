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

DISKTYPE="`cat $TMP/selected-disktype 2> /dev/null`"
RELEASE="`cat $TMP/selected-release 2> /dev/null`"

dialog --colors \
	--backtitle "Breeze::OS $RELEASE Installer" \
	--title "Breeze::OS Setup -- Disk Type Selection ($SELECTED_DRIVE)" \
	--default-item "$DISKTYPE" \
	--menu "\nSelect the main purpose for which the drive will be used.\n\nUse a \Z1normal\Zn setup if the main purpose is as a desktop drive. For other purposes, such as encrypted volumes; use an \Z1LVM\Zn setup.\n\nSelect disk type ?" 18 65 3 \
"lvm" "LVM disk partitioning and formatting" \
"normal" "Normal disk partitioning and formatting" 2> $TMP/selected-disktype

#--menu "\nSelect the main purpose for which the drive will be used.\n\nUse a \Z1normal\Zn setup if the main purpose is as a desktop drive. Use a \Z1RAId\Zn setup, if the drive is to be used as a redundant NAS drive. For other purposes, such as encrypted volumes; use an \Z1LVM\Zn setup.\n\nSelect disk type ?" 18 65 3 \
#"raid" "RAID disk partitioning and formatting" \

exit $?

# end Breeze::OS setup script
