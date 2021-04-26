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

unlink $TMP/desktops.lst 2> /dev/null
touch $TMP/desktops.lst

MEDIA="$(cat $TMP/selected-media 2> /dev/null)"
PKGTYPE="$(cat $TMP/selected-pkgtype 2> /dev/null)"

if [ "$PKGTYPE" = "squashfs" -o -f $BRZDIR/desktop/lxde.lst ]; then
	echo "A standard Lxde desktop=lxde" >> $TMP/desktops.lst
fi

if [ "$PKGTYPE" = "squashfs" -o -f $BRZDIR/desktop/xfce.lst ]; then
	echo "A standard Xfce desktop=xfce" >> $TMP/desktops.lst
fi

if [ "$PKGTYPE" = "squashfs" -o -f $BRZDIR/desktop/mate.lst ]; then
	echo "A standard Mate desktop=mate" >> $TMP/desktops.lst
fi

if [ "$PKGTYPE" = "squashfs" -o -f $BRZDIR/desktop/kde.lst ]; then
	echo "A standard KDE desktop=kde" >> $TMP/desktops.lst
fi

if [ -f $BRZDIR/desktop/corelxde.lst ]; then
	echo "A basic Lxde desktop=corelxde" >> $TMP/desktops.lst
fi

if [ -f $BRZDIR/desktop/corexfce.lst ]; then
	echo "A basic Xfce desktop=corexfce" >> $TMP/desktops.lst
fi

if [ -f $BRZDIR/desktop/coremate.lst ]; then
	echo "A basic Mate desktop=coremate" >> $TMP/desktops.lst
fi

#if [ -f $BRZDIR/desktop/breeze.lst ]; then
#	echo "a standard Breeze::OS desktop=breeze" >> $TMP/desktops.lst
#fi
#
#if [ -f $BRZDIR/desktop/corebreeze.lst ]; then
#	echo "a basic Breeze::OS desktop=corebreeze" >> $TMP/desktops.lst
#fi
#
#if [ -f $BRZDIR/desktop/server.lst ]; then
#	echo "A standard HTTP server=server" >> $TMP/desktops.lst
#fi
#
#if [ -f $BRZDIR/desktop/clubs.lst ]; then
#	echo "A standard Clubs VPN server=clubs" >> $TMP/desktops.lst
#fi

if [ ! -s $TMP/desktops.lst ]; then
	echo "INSTALLER: ERROR L_PACKAGE_LIST_MISSING"
	sync; sleep 1
	echo "A standard Xfce desktop=xfce" >> $TMP/desktops.lst
fi

cat $TMP/desktops.lst
sync; sleep 1

exit 0

# end Breeze::OS setup script
