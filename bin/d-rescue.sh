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
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR IMPLIED
# WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF 
# MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO
# EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, 
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
# PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
# OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, 
# WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR 
# OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF 
# ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
# ALL OTHER INSTALL SCRIPTS under install/bin HAVE THE SAME COPYRIGHT.
# EXCEPT for the modified ones which retains the Slackware copyright.
#
/bin/chmod a+rw /dev/null

#TERM=linux
RESCUE="$1"
SHELL="/bin/sh"
PATH="./:/bin:$PATH"
SERVER="http://master.localdomain:8012"

# The available uses for your hard drive are:
# - normal: use hard drive with normal partitions. 
# - lvm:     use LVM to partition the disk
# - raid:    use RAID drive partitioning method
# - crypto:  use LVM within an encrypted partition
DISKTYPE="normal"

# Original Distro
DERIVED="slackware"

RELEASE="$(grep -F CODENAME /etc/os-release)"
RELEASE="$(echo "$RELEASE" | cut -f 2 -d '=')"

# Initialize folder paths
. d-dirpaths.sh

d-select-drive.sh rescue

if [ "$?" = 0 ]; then
	SELECTED_DRIVE="$(cat $TMP/selected-drive 2> /dev/null)"
	export SELECTED_DRIVE

	BOOT_PARTITION="$(cat $TMP/selected-boot-partition 2> /dev/null)"
	export BOOT_PARTITION
fi

exit 0

# end Breeze::OS setup script

