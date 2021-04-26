#!/bin/bash
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
. d-dirpaths.sh $DISTRO

# Load settings ...
. d-selected-options.sh

ARCH="$(cat $TMP/selected-arch 2> /dev/null)"
KERNEL="$(cat $TMP/selected-kernel 2> /dev/null)"
DEVICE="$(cat $TMP/selected-device 2> /dev/null)"
DESKTOP="$(cat $TMP/selected-desktop 2> /dev/null)"
GPT_MODE="$(cat $TMP/selected-gpt-mode 2> /dev/null)"
DISTRO="$(cat $TMP/selected-distro 2> /dev/null)"
RELEASE="$(cat $TMP/selected-release 2> /dev/null)"

outfile=$TMP/$1.txt
textfile=./install/text/$1.txt

/bin/cp -f "$textfile" "$outfile"

USERNAME="$(cat $TMP/system-username 2> /dev/null)"

TARGET="$(cat $TMP/selected-target | sed -r 's/\//\\\\\//g')"
SOURCE="$(cat $TMP/selected-source | sed -r 's/\//\\\\\//g')"

LOCALE="$(cat $TMP/selected-locale 2> /dev/null)"
TIMEZONE="$(cat $TMP/selected-timezone | sed -r 's/\//\\\\\//g')"
SOURCE_PATH="$(cat $TMP/selected-source-path | sed -r 's/\//\\\\\//g')"

SELECTED_KERNEL="$(uname -snrm)"
SELECTED_NET="$(cat $TMP/selected-network)"
SELECTED_GATEWAY="$(cat $TMP/selected-gateway)"
SELECTED_NAMESERVER="$(cat $TMP/selected-nameserver)"

if [ "$USERNAME" = "" ]; then
	USERNAME="was left unset"
fi

if [ "$SELECTED_GATEWAY" = "" ]; then
	SELECTED_GATEWAY="unknown"
fi

if [ "$SELECTED_NAMESERVER" = "" ]; then
	SELECTED_NAMESERVER="unknown"
fi

/bin/sed -i -r "s/%username%/$USERNAME/g" $outfile

/bin/sed -i -r "s/%hostname%/$SELECTED_HOSTNAME/g" $outfile
/bin/sed -i -r "s/%gateway%/$SELECTED_GATEWAY/g" $outfile
/bin/sed -i -r "s/%nameserver%/$SELECTED_NAMESERVER/g" $outfile

/bin/sed -i -r "s/%locale%/$LOCALE/g" $outfile
/bin/sed -i -r "s/%timezone%/$TIMEZONE/g" $outfile

/bin/sed -i -r "s/%desktop%/$SELECTED_DESKTOP/g" $outfile
/bin/sed -i -r "s/%workgroup%/$SELECTED_WORKGROUP/g" $outfile
/bin/sed -i -r "s/%internet%/$SELECTED_NET/g" $outfile
/bin/sed -i -r "s/%kernel%/$SELECTED_KERNEL/g" $outfile

/bin/sed -i -r "s/%source[-]drive%/$SOURCE/g" $outfile
/bin/sed -i -r "s/%target[-]drive%/$TARGET/g" $outfile
/bin/sed -i -r "s/%source[-]path%/$SOURCE_PATH/g" $outfile

/bin/sed -i -r "s/%nb[-]packages%/$NB_PACKAGES/g" $outfile
/bin/sed -i -r "s/%disk[-]space%/$DISK_SPACE/g" $outfile

clear
/bin/cat $outfile

exit 0

