#!/bin/bash
#
# GNU GENERAL PUBLIC LICENSE -- Version 3
#
# Copyright 2013 Pierre Innocent, Tsert Inc., All Rights Reserved
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

SWAP_SPACE=1024

DISKSZ="$(cat $TMP/drive-total 2> /dev/null)"

VMSTAT="$(cat /proc/meminfo | grep -F MemTotal)"
VMSTAT="$(echo $VMSTAT | sed 's/MemTotal:[ ]*//g')"
VMSTAT="$(echo $VMSTAT | sed 's/[ ].*$//g')"
VMSTAT=$(( $VMSTAT / 1000 ))

if test "$VMSTAT" -lt 512; then
	SWAP_SPACE=1024
elif test "$VMSTAT" -lt 1000; then
	SWAP_SPACE=2048
else
	SWAP_SPACE=$(( $VMSTAT * 2 + 2048 ))
	GBYTES=$(( $SWAP_SPACE / 1024 ))
	SWAP_SPACE=$(( $GBYTES * 1024 ))
fi

if test "$DISKSZ" -lt 5000; then
	SWAP_SPACE=256
elif test "$DISKSZ" -lt 10000; then
	SWAP_SPACE=512
elif test "$DISKSZ" -lt 20000; then
	SWAP_SPACE=1024
fi

echo "$SWAP_SPACE" 1> $TMP/swap-size

exit 0

# end Breeze::OS setup script
