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

OFF=false
CHECK=false
SWAPSPACE=""
DISK_TYPE="$(extract_value scheme 'disk-type')"

while [ $# -gt 0 ]; do
	case $1 in
		"check"|"--check")
			CHECK=true
			shift 1 ;;

		"off"|"--off")
			OFF=true
			shift 1 ;;

		*)
			if [ -z "$SWAPSPACE" ]; then
				SWAPSPACE="$1"
			else
				SWAPSPACE="$1 $SWAPSPACE"
			fi
			shift 1 ;;
	esac
done

if [ -z "$SWAPSPACE" ]; then
	exit 1
fi

if [ "$OFF" = true ]; then
	swapoff $SWAPSPACE 1> /dev/null 2> /dev/null
	exit $?
fi

echo "INSTALLER: MESSAGE L_CREATING_SWAP_SPACE"
sync; sleep 0.5

if [ "$CHECK" = true ]; then
	mkswap -c $SWAPSPACE 1> /dev/null 2> $TMP/mkswap.err
else
	mkswap $SWAPSPACE 1> /dev/null 2> $TMP/mkswap.err
fi

if [ "$?" = 0 ]; then
	if [ "$DISK_TYPE" != "lvm" ]; then
		echo "INSTALLER: MESSAGE L_ACTIVATING_SWAP_SPACE"
		sync; sleep 0.5
		swapon -p 32767 $SWAPSPACE 1> /dev/null 2> $TMP/swapon.err
	fi
fi

exit $?

# end Breeze::OS setup script
