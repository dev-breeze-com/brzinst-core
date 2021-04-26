#!/bin/bash
#
# GNU GENERAL PUBLIC LICENSE Version 3
#
# Copyright 1999, 2002, 2012  Patrick Volkerding, Moorhead, Minnesota USA
# All rights reserved.
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
WM="$1"
FORCE="$2"
WINDOW_MANAGERS=""

if [ -f /bin/d-dirpaths.sh ]; then
	. d-dirpaths.sh
fi

if [ "$TMP" = "" ]; then
	TMP="/tmp"
fi

if [ "$WM" = "" ]; then
	WM="xfce"
	FORCE="yes"
fi

addto_wm() {
  if [ "$WINDOW_MANAGERS" = "" ]; then
  	WINDOW_MANAGERS="$1"
  else
  	WINDOW_MANAGERS="$WINDOW_MANAGERS,$1"
  fi
  return 0
}

cat << EOF > $TMP/tempscript
dialog --colors \\
	--backtitle "Breeze::OS Setup" \\
	--title "Breeze::OS Setup -- Window Manager Selection" \\
	--default-item "xfce" \\
	--menu \\
"A window manager is the application which provides a graphical user interface.\n\n\\
Select a window manager [ \Z1xfce\Zn ] !" \\
12 70 0 \\
EOF
# Add XFce:
if [ -r /etc/X11/xinit/xinitrc.xfce ]; then
	echo "\"xfce\" \"The Cholesterol Free Desktop Environment\" \\" >> $TMP/tmpscript.sh
	addto_wm "xfce"
fi

# Add KDE as the first and default entry:
if [ -r /etc/X11/xinit/xinitrc.kde ]; then
	echo "\"kde\" \"KDE: K Desktop Environment\" \\" >> $TMP/tmpscript.sh
	addto_wm "kde"
fi

# Then, we add GNOME:
if [ -r /etc/X11/xinit/xinitrc.gnome ]; then
	echo "\"gnome\" \"GNU Network Object Model Environment\" \\" >> $TMP/tmpscript.sh
	addto_wm "gnome"
fi

# Add Enlightenment:
if [ -r /etc/X11/xinit/xinitrc.e17 ]; then
	echo "\"e17\" \"Enlightenment 17\" \\" >> $TMP/tmpscript.sh
	addto_wm "e17"
fi

# Add mate:
if [ -r /etc/X11/xinit/xinitrc.mate ]; then
	echo "\"mate\" \"The mate window manager\" \\" >> $TMP/tmpscript.sh
	addto_wm "mate"
fi

# Add cinnamon:
if [ -r /etc/X11/xinit/xinitrc.cinnamon ]; then
	echo "\"cinnamon\" \"The cinnamon window manager\" \\" >> $TMP/tmpscript.sh
	addto_wm "cinnamon"
fi

# Add Fluxbox:
if [ -r /etc/X11/xinit/xinitrc.fluxbox ]; then
	echo "\"fluxbox\" \"The fluxbox window manager\" \\" >> $TMP/tmpscript.sh
	addto_wm "fluxbox"
fi

# Add Blackbox:
if [ -r /etc/X11/xinit/xinitrc.blackbox ]; then
	echo "\"blackbox\" \"The blackbox window manager\" \\" >> $TMP/tmpscript.sh
	addto_wm "blackbox"
fi

# Add WindowMaker:
if [ -r /etc/X11/xinit/xinitrc.wmaker ]; then
	echo "\"wmaker\" \"WindowMaker\" \\" >> $TMP/tmpscript.sh
	addto_wm "wmaker"
fi

# Add FVWM2:
if [ -r /etc/X11/xinit/xinitrc.fvwm2 ]; then
	echo "\"fvwm2\" \"F(?) Virtual Window Manager (version 2.xx)\" \\" >> $TMP/tmpscript.sh
	addto_wm "fvwm2"
fi

# Add FVWM95:
if [ -r /etc/X11/xinit/xinitrc.fvwm95 ]; then
	echo "\"fvwm95\" \"FVWM2 with a Windows look and feel\" \\" >> $TMP/tmpscript.sh
	addto_wm "fvwm95"
fi

# Add icewm:
if [ -r /etc/X11/xinit/xinitrc.icewm ]; then
	echo "\"icewm\" \"ICE Window Manager\" \\" >> $TMP/tmpscript.sh
	addto_wm "icewm"
fi

# Add sawfish:
if [ -r /etc/X11/xinit/xinitrc.sawfish ]; then
	echo "\"sawfish\" \"Sawfish without GNOME\" \\" >> $TMP/tmpscript.sh
	addto_wm "sawfish"
fi

# Add twm:
if [ -r /etc/X11/xinit/xinitrc.twm ]; then
	echo "\"twm\" \"Tab Window Manager (very basic)\" \\" >> $TMP/tmpscript.sh
	addto_wm "twm"
fi

# Add mwm:
if [ -r /etc/X11/xinit/xinitrc.mwm ]; then
	echo "\"mwm\" \"Motif Window Manager\" \\" >> $TMP/tmpscript.sh
	addto_wm "mwm"
fi

echo "2> $TMP/retcode" >> $TMP/tempscript

if [ "$force" != "yes" ]; then
	. $TMP/tempscript

	if [ "$?" != 0 ]; then
		exit 1
	fi
	WM="`cat TMP/retcode 2> /dev/null`"
fi

if [ -f /etc/slim.conf -a -f "/etc/X11/xinit/xinitrc.$WM" ]; then
	WMS="$WINDOW_MANAGERS"
	sed -i -r 's/^sessions.*/sessions $WMS/g' $ROOTDIR/etc/slim.conf
fi

exit 0

# end Breeze::OS script
