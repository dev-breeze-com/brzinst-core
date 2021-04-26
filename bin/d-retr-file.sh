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

HOSTNAME="$1"
SOURCE="$2"
TARGET="$3"

FOLDER="$(dirname $TARGET)"
MEDIA="$(cat $TMP/selected-media 2> /dev/null)"

mkdir -p "$FOLDER"

if [ "$MEDIA" = "NETWORK" ]; then
	if [ "$SOURCE" = "web" ]; then
		ARCH="$(cat $TMP/selected-arch 2> /dev/null)"
		DERIVED="$(cat $TMP/selected-derivative 2> /dev/null)"

		archive="/archives/$DERIVED/$ARCH/All/$SOURCE"
		exec wget http::/www.breezeos.com/$archive -O $target
	else
		archive="/archives/$SOURCE"
		exec tftp -4 -m binary master.localdomain -c "get $archive $target"
	fi
fi

if [ -f $MOUNTPOINT/$source ]; then
	cp -f $MOUNTPOINT/$source $target
	exit $?
fi

exit 1

# end Breeze::OS setup script
