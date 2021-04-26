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

RELEASE="`cat $TMP/selected-release 2> /dev/null`"

mkdir -p $ROOTDIR/etc/X11/

d-xorg-drivers.sh "prompt"

DRIVERS="`cat $TMP/xorg-drivers`"
GRAPHICS="`cat $TMP/xorg-graphics`"

pushd $(pwd) 1> /dev/null 2>&1
cd $ROOTDIR

for driver in $DRIVERS; do
	if [ "$driver" = "nv" -o \
		-f "./usr/lib/xorg/modules/drivers/$driver"_drv.so ]; then
		break
	fi
done

popd 1> /dev/null 2>&1

if [ ! -e "$ROOTDIR/usr/bin/Xorg" ]; then
	dialog --colors \
		--backtitle "Breeze::OS $RELEASE Installer" \
		--title "Breeze::OS Setup -- Xorg Configuration" \
		--msgbox "Cannot configure X. The X server is missing !" 6 55
	exit 1
fi

XORGCONF="$ROOTDIR/etc/X11/xorg.conf"

chmod a+x $ROOTDIR/usr/bin/Xorg

if [ -f "$XORGCONF" ]; then
	mv -f "$XORGCONF" "$XORGCONF.sav"
fi

# Setup the mouse
d-mouse.sh

mouse="`cat $TMP/selected-mouse 2> /dev/null`"
keyboard="`cat $TMP/selected-keyboard 2> /dev/null`"
kbdlayout="`cat $TMP/selected-kbd-layout 2> /dev/null`"
kbdvariant="`cat $TMP/selected-kbd-variant 2> /dev/null`"

company="`echo "$GRAPHICS" | cut -f1,2 -d ' ' | crunch`"
board="`echo "$GRAPHICS" | sed -r "s/$company//g" | crunch`"

cp -f $BRZDIR/factory/xorg.conf $XORGCONF

sed -i -r "s/%mouse[-]driver%/$mouse/g" $XORGCONF
sed -i -r "s/%kbd[-]model%/$keyboard/g" $XORGCONF
sed -i -r "s/%kbd[-]layout%/$kbdlayout/g" $XORGCONF
sed -i -r "s/%kbd[-]variant%/$kbdvariant/g" $XORGCONF
sed -i -r "s/%graphics[-]board%/$board/g" $XORGCONF
sed -i -r "s/%graphics[-]company%/$company/g" $XORGCONF
sed -i -r "s/%graphics[-]driver%/$driver/g" $XORGCONF

cp -f ./bin/d-xwmconfig.sh $ROOTDIR/sbin/
cp -f $BRZDIR/factory/xinitrc $ROOTDIR/etc/X11/xinit/
chmod a+x $ROOTDIR/sbin/d-xwmconfig.sh

pushd $(pwd) 1> /dev/null 2>&1
cd $ROOTDIR/usr/bin
rm -f xwmconfig
ln -sf /sbin/d-xwmconfig.sh xwmconfig
popd 1> /dev/null 2>&1

chroot $ROOTDIR /sbin/d-xwmconfig.sh xfce true

exit 0

# end Breeze::OS setup script
