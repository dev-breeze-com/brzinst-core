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

RESERVED=256
SWAP_SPACE=1024

BOOTSZ="`cat $TMP/selected-boot-size 2> /dev/null`"
DISKSZ="`cat $TMP/drive-total 2> /dev/null`"
echo -n "$BOOTSZ" 1> $TMP/selected-reserved-size

VMSTAT="`cat /proc/meminfo | grep -F MemTotal`"
VMSTAT="`echo $VMSTAT | sed 's/MemTotal:[ ]*//g'`"
VMSTAT="`echo $VMSTAT | sed 's/[ ].*$//g'`"
VMSTAT=$(( $VMSTAT / 1000 ))
DISKSZ=$(( $DISKSZ / 1000 ))

if test "$VMSTAT" -lt 512; then
	SWAP_SPACE=512
elif test "$VMSTAT" -lt 1024; then
	SWAP_SPACE=1024
elif test "$VMSTAT" -lt 8096; then
	SWAP_SPACE=2048
elif test "$VMSTAT" -gt 8096; then
	SWAP_SPACE=4096
fi

if test "$DISKSZ" -lt 10000; then
	SWAP_SPACE=256
fi

dialog --colors --clear \
	--backtitle "Breeze::OS $RELEASE Installer" \
	--title "Breeze::OS Setup -- Swap Partition Size" \
	--default-item "$SWAP_SPACE" \
	--menu "\nSwap space is used as additional virtual memory.\nThe size of your swap space \Z1must be\Zn at least double the size of your physical memory; up to a maximum of \Z14 GB\Zn" 16 60 6 \
"256" "Swap partition of size 256 MB" \
"512" "Swap partition of size 512 MB" \
"1024" "Swap partition of size 1 GB" \
"2048" "Swap partition of size 2 GB" \
"4096" "Swap partition of size 2 GB" 2> $TMP/selected-swap-size

if [ "$?" != 0 ]; then
	RESERVED=$(( $BOOTSZ + $SWAP_SPACE ))
	echo -n "$RESERVED" 1> $TMP/selected-reserved-size
	exit 1
fi

SWAP_SPACE="`cat $TMP/selected-swap-size 2> /dev/null`"

RESERVED=$(( $BOOTSZ + $SWAP_SPACE ))

echo -n "$RESERVED" 1> $TMP/selected-reserved-size

exit 0

# end Breeze::OS setup script
