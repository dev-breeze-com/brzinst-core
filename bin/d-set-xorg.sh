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

set_xorg_driver()
{
	local mode="$1"
	local GRAPHICS="$(cat $TMP/detected-vga-controller 2> /dev/null)"

	if echo "$GRAPHICS" | grep -q -F -i unichrome ; then
		DRIVERS="openchrome vesa"
	elif echo "$GRAPHICS" | grep -q -F -i intel ; then
		DRIVERS="intel vesa"
	elif echo "$GRAPHICS" | grep -q -F -i cirrus ; then
		DRIVERS="cirrus vesa"
	elif echo "$GRAPHICS" | grep -q -F -i savage ; then
		DRIVERS="openchrome savage s3 vesa"
	elif echo "$GRAPHICS" | grep -q -F -i radeon ; then
		DRIVERS="radeon vesa"
	elif echo "$GRAPHICS" | grep -q -F -i trident ; then
		DRIVERS="trident vesa"
	elif echo "$GRAPHICS" | grep -q -F -i voodoo ; then
		DRIVERS="voodoo vesa"
	elif echo "$GRAPHICS" | grep -q -F -i nvidia ; then
		DRIVERS="nvidia nv vesa"
	elif echo "$GRAPHICS" | grep -q -F -i glide ; then
		DRIVERS="glide vesa"
	elif echo "$GRAPHICS" | grep -q -F -i geode ; then
		DRIVERS="geode ztv vesa"
	elif echo "$GRAPHICS" | grep -q -F -i geforce ; then
		DRIVERS="nvidia nv nouveau vesa"
	elif echo "$GRAPHICS" | grep -q -F -i siliconmotion ; then
		DRIVERS="siliconmotion vesa"
	elif echo "$GRAPHICS" | grep -q -F -i ati ; then
		DRIVERS="ati mach64 vesa"
	elif echo "$GRAPHICS" | grep -q -F -i r128 ; then
		DRIVERS="r128 vesa"
	else
		DRIVERS="vesa"
	fi

	echo "$DRIVERS" 1> $TMP/xorg-drivers
	echo "$GRAPHICS" 1> $TMP/xorg-graphics

	local driver="$(echo "$DRIVERS" | cut -f1 -d' ')"
	local xdms="slim"

	if [ "$mode" = "desktop" ]; then

		local desktop="$(cat $TMP/selected-desktop 2> /dev/null)"
		local xkbmodel="$(cat $TMP/selected-keyboard 2> /dev/null)"
		local xkblayout="$(cat $TMP/selected-kbd-layout 2> /dev/null)"
		local xkbvariant="$(cat $TMP/selected-keymap 2> /dev/null)"
		local resolution="1280x1024"
		local hsync="31.0 - 65.0"
		local vsync="50.0 - 100.0"

		if grep -q -E '[ ](LCD|TFT|LED)[ ]' /var/log/Xorg.0.log ; then
			vsync="20.0 - 70.0"
			resolution="1600x900"
		fi

		echo "graphics-card=$driver" 1> $TMP/xorg.map
		echo "monitor=Monitor0" >> $TMP/xorg.map
		echo "vendor=Monitor Vendor" >> $TMP/xorg.map
		echo "monitor-model=Monitor Model" >> $TMP/xorg.map
		echo "hsync=$hsync" >> $TMP/xorg.map
		echo "vsync=$vsync" >> $TMP/xorg.map
		echo "resolution=$resolution" >> $TMP/xorg.map
		echo "xkbmodel=$xkbmodel" >> $TMP/xorg.map
		echo "xkbvariant=,,$xkbvariant" >> $TMP/xorg.map
		echo "xkblayout=$xkblayout" >> $TMP/xorg.map
		echo "xkboptions=terminate:ctrl_alt_bksp" >> $TMP/xorg.map

		if [ "$desktop" = "breeze" ]; then
			echo "Breeze Login Mgr=breeze" 1> $TMP/xdm.map
			echo "Slim Login Mgr=slim" >> $TMP/xdm.map
			echo "xdm=breeze" >> $TMP/xorg.map
			xdms="slim,breeze"
		else
			echo "Slim Login Mgr=slim" 1> $TMP/xdm.map
			echo "xdm=slim" >> $TMP/xorg.map
		fi

		if [ "$desktop" = "kde" ]; then
			desktop="kde,"
			echo "desktop=kde" >> $TMP/xorg.map
		elif [ "$desktop" = "gnome" ]; then
			echo "desktop=gnome" >> $TMP/xorg.map
		elif [ "$desktop" = "breeze" ]; then
			echo "desktop=breeze" >> $TMP/xorg.map
		else
			desktop="xfce"
			echo "desktop=xfce" >> $TMP/xorg.map
		fi
		sed -i "s/^value=xfce.*$/value=$desktop/g" $BRZDIR/fields/xorg.seq
		sed -i "s/^values=xfce,.*$/values=$desktop/g" $BRZDIR/fields/xorg.seq
		sed -i "s/^values=slim,.*$/values=$xdms/g" $BRZDIR/fields/xorg.seq
	fi
	return 0
}

# Main starts here ...
ARGUMENT="$1"
ARCH="$(cat $TMP/selected-arch 2> /dev/null)"
DERIVED="$(cat $TMP/selected-derivative 2> /dev/null)"

if [ "$ARGUMENT" = "drivers" ]; then
	set_xorg_driver
	exit 0
fi

if [ "$ARGUMENT" = "desktop" ]; then
	set_xorg_driver desktop
	exit 0
fi

exit 0

# end Breeze::OS setup script
