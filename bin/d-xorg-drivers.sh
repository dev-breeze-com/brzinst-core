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

prompt="$1"

/sbin/lspci | grep -F -i 'VGA compatible controller' 1> $TMP/lspci

GRAPHICS="$(cat $TMP/lspci | sed -r 's/^.*://g')"

if echo "$GRAPHICS" | fgrep -q -i nvidia ; then
	DRIVERS="nv nvidia nouveau vesa vga"
elif echo "$GRAPHICS" | fgrep -q -i ati ; then
	DRIVERS="ati mach64 vesa vga"
elif echo "$GRAPHICS" | fgrep -q -i cirrus ; then
	DRIVERS="cirrus vesa vga"
elif echo "$GRAPHICS" | fgrep -q -i savage ; then
	DRIVERS="openchrome s3 savage vga vesa"
elif echo "$GRAPHICS" | fgrep -q -i radeon ; then
	DRIVERS="radeon vesa vga"
elif echo "$GRAPHICS" | fgrep -q -i trident ; then
	DRIVERS="trident vesa vga"
elif echo "$GRAPHICS" | fgrep -q -i trident ; then
	DRIVERS="trident vesa vga"
elif echo "$GRAPHICS" | fgrep -q -i voodoo ; then
	DRIVERS="voodoo vesa vga"
elif echo "$GRAPHICS" | fgrep -q -i intel ; then
	DRIVERS="intel vesa vga"
else
	DRIVERS="vesa vga"
fi

echo "$DRIVERS" 1> $TMP/xorg-drivers
echo "$GRAPHICS" 1> $TMP/xorg-graphics

#DRIVER="$(echo "$DRIVERS" | cut -f1 -d ' ')"

echo "$DRIVER" 1> $TMP/selected-xorg-driver

if [ "$prompt" != "" ]; then

	/bin/cp -f ./text/xorg.txt $TMP/xorg.txt

	if [ "$GRAPHICS" = "" ]; then
		sed -i -r "s/%graphics%/No or unknown graphics card/g" $TMP/xorg.txt
	else
		sed -i -r "s/%graphics%/$GRAPHICS/g" $TMP/xorg.txt
	fi

	clear
	cat $TMP/xorg.txt
	read command

fi

exit 0

# end Breeze::OS setup script
