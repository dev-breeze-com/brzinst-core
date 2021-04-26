#!/bin/bash
#
# GNU GENERAL PUBLIC LICENSE Version 3
#
# Copyright 1993, 1999, 2002 Patrick Volkerding, Moorhead, MN.
# Copyright 2009  Patrick J. Volkerding, Sebeka, MN, USA
# Modified by dev@breeze.tsert.com
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

KEYMAPS="/etc/keymaps.tar.gz"
COUNTRY="$(cat $TMP/selected-country 2> /dev/null)"
LAYOUT="$(cat $TMP/selected-layout 2> /dev/null)"

VARIANT="$(echo "$LAYOUT" | tr '[:upper:]' '[:lower:]')"
COUNTRY="$(echo "$COUNTRY" | tr '[:upper:]' '[:lower:]')"

KEYMAP="$VARIANT/$COUNTRY"
keymap="$(grep -E -m1 "^$VARIANT=$COUNTRY" $BRZDIR/factory/kbd-variants.lst)"

if [ "$keymap" = "" ]; then
	keymap="$(grep -E -m1 "$VARIANT" $BRZDIR/factory/kbd-variants.lst)"
fi

if [ "$keymap" = "" ]; then
	unlink $TMP/selected-kbd-variant 2> /dev/null
else
	keymap="$(echo "$keymap" | cut -f1 -d '=')"
	echo -n "$keymap" 1> $TMP/selected-kbd-variant
fi

keymap="$(grep -E -m1 "^$KEYMAP.map" $BRZDIR/factory/keymaps.lst)"

if [ "$keymap" = "" ]; then
	keymap="$(grep -E -m1 "^$KEYMAP" $BRZDIR/factory/keymaps.lst)"
fi

keymap="$(echo $keymap | sed 's/\.map\.gz//g')"
BMAP="$(basename $keymap)".bmap

tar -xzOf "$KEYMAPS" "$BMAP" 1> /dev/null

if [ "$?" != 0 ]; then
	exit 1
fi

tar -xzOf "$KEYMAPS" "$BMAP" | loadkmap

if [ "$?" = 0 ]; then
	exit 0
fi

#tar -xzOf "$KEYMAPS" us.bmap | loadkmap
#echo "qwerty/us" 1> $TMP/selected-keymap

exit 1

# end Breeze::OS setup script
