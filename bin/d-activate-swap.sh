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

EXIT_CODE=1
FORCE_ACTIVATE=$2
SWAP_PARTITION=$1
SWAP_ACTIVATED="`cat $TMP/swap-activated 2> /dev/null`"

DERIVED="`cat $TMP/selected-derivative 2> /dev/null`"
RELEASE="`cat $TMP/selected-release 2> /dev/null`"

if [ "$SWAP_ACTIVATED" != "" ]; then
	SWAP_ACTIVATED="`echo $SWAP_ACTIVATED | grep $SWAP_PARTITION`"
fi

if [ "$SWAP_PARTITION" != "" -a -z "$SWAP_ACTIVATED" ]; then

	dialog --clear --colors \
		--backtitle "Breeze::OS $RELEASE Installer" \
		--title "Breeze::OS $RELEASE Setup (v0.9.0)" \
		--menu "\nSwap space is used as additional virtual memory.\n\
Use \Z1$SWAP_PARTITION\Zn as additional swap space !" 12 55 3 \
	"create" "Create swap space" \
	"activate" "Activate swap space" \
	"skip" "Continue without swap space" 2> $TMP/swap-command

	if [ "`cat $TMP/swap-command`" = "create" ]; then

		d-swapon.sh --check $SWAP_PARTITION

		EXIT_CODE=$?

		if [ "$EXIT_CODE" = 0 ]; then
			if [ ! -f $TMP/swap-activated ]; then
				/bin/touch $TMP/swap-activated
			fi
			echo "$SWAP_PARTITION" >> $TMP/swap-activated
		fi
	elif [ "`cat $TMP/swap-command`" = "activate" ]; then

		d-swapon.sh $SWAP_PARTITION
		EXIT_CODE=$?

		if [ "$EXIT_CODE" = 0 ]; then
			if [ ! -f $TMP/swap-activated ]; then
				/bin/touch $TMP/swap-activated
			fi
			echo "$SWAP_PARTITION" >> $TMP/swap-activated
		fi
	elif [ "`cat $TMP/swap-command`" = "skip" ]; then
		EXIT_CODE=0
	fi

	VMSTAT="`cat /proc/meminfo | grep -F MemTotal`"
	VMSTAT="`echo $VMSTAT | sed 's/MemTotal:[ ]*//g'`"
	VMSTAT="`echo $VMSTAT | sed 's/[ ].*$//g'`"
	VMSTAT=$(( $VMSTAT / 1000 ))

	if test "$VMSTAT" -lt 512; then

		dialog --clear --colors \
			--backtitle "Breeze::OS $RELEASE Installer" \
			--title "Breeze::OS $RELEASE Setup (v0.9.0)" \
			--yesno "\nTo make your \Z1low memory\Zn computer more responsive;\n
use a \Z4USB memory key\Zn as additional swap space ?" 8 55 2> $TMP/retcode

		if [ "$?" = 0 ]; then

			./d-select-drive.sh memboost

			if [ "$?" != 0 ]; then
				exit 0
			fi

			dialog --clear --colors \
				--backtitle "Breeze::OS $RELEASE Installer" \
				--title "Breeze::OS $RELEASE Setup (v0.9.0)" \
				--yesno "\nIf the drive was already partitioned, proceed ?" 7 55 2> $TMP/retcode

			if [ "$?" != 0 ]; then
				exit 0
			fi

			MEMBOOST="`cat $TMP/selected-memboost`"
			d-swapon.sh --memboost $MEMBOOST
			EXIT_CODE=$?
		fi
	fi
fi

exit $EXIT_CODE

# end Breeze::OS script

