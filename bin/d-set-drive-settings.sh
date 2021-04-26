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
#
. d-dirpaths.sh

SWAP_SPACE=1024
DRIVE_ID="$(basename $1)"

if [ "$PLATFORM" = "freebsd" ]; then
	VMSTAT="$(sysctl hw.realmem | crunch)"
	VMSTAT="$(echo $VMSTAT | sed 's/MemTotal:[ ]*//g')"
	VMSTAT="$(echo $VMSTAT | sed 's/[ ].*$//g')"
	VMSTAT=$(( $VMSTAT / 1000 ))
else
	VMSTAT="$(cat /proc/meminfo | grep -F MemTotal)"
	VMSTAT="$(echo $VMSTAT | sed 's/MemTotal:[ ]*//g')"
	VMSTAT="$(echo $VMSTAT | sed 's/[ ].*$//g')"
	VMSTAT=$(( $VMSTAT / 1000 ))
fi

if test $VMSTAT -lt 512; then
	SWAP_SPACE=1024
elif test $VMSTAT -lt 750; then
	SWAP_SPACE=2048
elif test $VMSTAT -lt 1000; then
	SWAP_SPACE=4096
elif test $VMSTAT -lt 4000; then
	SWAP_SPACE=5120
else
	SWAP_SPACE=$(( $VMSTAT ))
fi

#DISK_SIZE="$(cat $TMP/${DRIVE_ID}-drive-total 2> /dev/null)"

if test $DISK_SIZE -lt 5000; then
	SWAP_SPACE=256
elif test $DISK_SIZE -lt 10000; then
	SWAP_SPACE=512
elif test $DISK_SIZE -lt 20000; then
	SWAP_SPACE=1024
fi

echo "256" 1> $TMP/boot-size

if test $DISK_SIZE -ge 750000; then
	echo "0" 1> $TMP/rsrvd-blks
	echo "root-share" 1> $TMP/default-scheme
	echo "1024" 1> $TMP/boot-size

elif test $DISK_SIZE -ge 500000; then
	echo "1" 1> $TMP/rsrvd-blks
	echo "root-opt" 1> $TMP/default-scheme
	echo "512" 1> $TMP/boot-size

elif test $DISK_SIZE -ge 250000; then
	echo "2" 1> $TMP/rsrvd-blks
	echo "root-srv" 1> $TMP/default-scheme

elif test $DISK_SIZE -ge 150000; then
	echo "2" 1> $TMP/rsrvd-blks
	echo "root-var" 1> $TMP/default-scheme
else
	echo "root-home" 1> $TMP/default-scheme
	echo "5" 1> $TMP/rsrvd-blks
fi

if test $DISK_SIZE -ge 750000 ; then
	echo "4K" 1> $TMP/sector-size
else
	echo "512" 1> $TMP/sector-size
fi

echo "4096" 1> $TMP/block-size

echo "$SWAP_SPACE" 1> $TMP/swap-size

exit 0

# end Breeze::OS setup script
