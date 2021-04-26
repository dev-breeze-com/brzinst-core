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
. d-dirpaths.sh

DERIVED="`cat $TMP/selected-derivative 2> /dev/null`"
RELEASE="`cat $TMP/selected-release 2> /dev/null`"
NETWORK="`cat $TMP/selected-network 2> /dev/null`"

export TERM=linux-c
export LANGUAGE=C.UTF-8

if [ "$NETWORK" != "router" -o \
	! -s /etc/resolv.conf -o \
	! -x $ROOTDIR/sbin/pkg-manager.sh -o \
	! -s "$BRZDIR/factory/upgrade.lst" ]; then
	exit 0
fi

dialog --colors \
	--backtitle "Breeze::OS $RELEASE Installer" \
	--title "Breeze::OS Setup -- Updating Packages" \
	--yesno "\nSome popular packages may be newer on the repository.\nDo you wish to upgrade now (y/n) ? " 7 55

if [ "$?" = 0 ]; then

	while read pkg; do
		dialog --colors \
			--backtitle "Breeze::OS $RELEASE Installer" \
			--title "Breeze::OS Setup -- Updating Packages" \
			--yesno "\nDo you wish to upgrade \Z1$pkg\Zn now (y/n) ? " 7 55

		if [ "$?" = 0 ]; then
			$ROOTDIR/sbin/pkg-manager.sh -U -T $ROOTDIR -P current "$pkg"
		fi
	done < "$BRZDIR/factory/upgrade.lst"
fi

exit 0

# end Breeze::OS setup script

