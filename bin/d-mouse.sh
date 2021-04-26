#!/bin/bash
#
# GNU GENERAL PUBLIC LICENSE Version 3
#
# Modified from Slackware by dev@breeze.tsert.com
#
. d-dirpaths.sh

# If the mouse is USB, we can autodetect it:
if [ -r /proc/bus/usb/devices ]; then
	if cat /proc/bus/usb/devices | \
		grep usb_mouse 1> /dev/null 2> /dev/null ; then
		MOUSE_TYPE=usb
		MTYPE="imps2"
		( cd $T_PX/dev ; rm -f mouse ; ln -sf input/mice mouse )
	fi
fi

dialog \
	--backtitle "Breeze::OS $RELEASE Installer" \
	--title "Breeze::OS Setup -- Mouse Configuration" \
	--default-item "imps2" \
	--menu "\nThis part of the configuration process will create a \
/dev/mouse link pointing to your default mouse device. \
You can change the /dev/mouse link later if the mouse doesn't work, or if \
you switch to a different type of pointing device.  We will also use the \
information about the mouse to set the correct protocol.\n\n\
Please select a mouse type from the list below:" 20 76 6 \
	"ps2" "PS/2 port mouse (most desktops and laptops)" \
	"usb" "USB connected mouse" \
	"imps2" "Microsoft PS/2 Intellimouse" \
	"exps2" "Intellimouse Explorer PS/2" \
	"bare" "2 button Microsoft compatible serial mouse" \
	"ms" "3 button Microsoft compatible serial mouse" \
	"mman" "Logitech serial MouseMan and similar devices" \
	"msc" "MouseSystems serial (most 3 button serial mice)" \
	"pnp" "Plug and Play (serial mice that do not work with ms)" \
	"ms3" "Microsoft serial Intellimouse" \
	"netmouse" "Genius Netmouse on PS/2 port" \
	"logi" "Some serial Logitech devices" \
	"logim" "Make serial Logitech behave like msc" \
	"atibm" "ATI XL busmouse (mouse card)" \
	"inportbm" "Microsoft busmouse (mouse card)" \
	"logibm" "Logitech busmouse (mouse card)" \
	"ncr" "A pointing pen (NCR3125) on some laptops" \
	"twid" "Twiddler keyboard, by HandyKey Corp" \
	"genitizer" "Genitizer tablet (relative mode)" \
	"js" "Use a joystick as a mouse" \
	"wacom" "Wacom serial graphics tablet" 2> $TMP/selected-mouse

if [ ! $? = 0 ]; then
	exit
fi

MOUSE_TYPE="`cat $TMP/selected-mouse 2> /dev/null`"

if [ "$MOUSE_TYPE" = "bare" -o "$MOUSE_TYPE" = "ms" \
	-o "$MOUSE_TYPE" = "mman" -o "$MOUSE_TYPE" = "msc" \
	-o "$MOUSE_TYPE" = "genitizer" \
	-o "$MOUSE_TYPE" = "pnp" -o "$MOUSE_TYPE" = "ms3" \
	-o "$MOUSE_TYPE" = "logi" -o "$MOUSE_TYPE" = "logim" \
	-o "$MOUSE_TYPE" = "wacom" -o "$MOUSE_TYPE" = "twid" ]; then

	dialog \
		--backtitle "Breeze::OS $RELEASE Installer" \
		--title "Breeze::OS Setup -- Serial Port Selection" \
		--menu "\nYour mouse requires a serial port.\n\nWhich one would you like to use?" 14 55 4 \
		"/dev/ttyS0" "(COM1: under DOS)" \
		"/dev/ttyS1" "(COM2: under DOS)" \
		"/dev/ttyS2" "(COM3: under DOS)" \
		"/dev/ttyS3" "(COM4: under DOS)" 2> $TMP/mport

	if [ "$?" != 0 ]; then
		rm -f $TMP/mport
		exit
	fi

	MDEVICE="`cat $TMP/mport`"
	SHORT_MDEVICE=`basename $MDEVICE`

	( cd $T_PX/dev ; rm -f mouse ; ln -sf $SHORT_MDEVICE mouse )
	# For the serial mice, the protocol is the same as the mouse type:
	MTYPE=$MOUSE_TYPE
	rm -f $TMP/mport

elif [ "$MOUSE_TYPE" = "ps2" ]; then
	( cd $T_PX/dev ; rm -f mouse ; ln -sf psaux mouse )
	MTYPE="ps2"
elif [ "$MOUSE_TYPE" = "ncr" ]; then
	( cd $T_PX/dev ; rm -f mouse ; ln -sf psaux mouse )
	MTYPE="ncr"
elif [ "$MOUSE_TYPE" = "exps2" ]; then
	( cd $T_PX/dev ; rm -f mouse ; ln -sf psaux mouse )
	MTYPE="exps2"
elif [ "$MOUSE_TYPE" = "imps2" ]; then
	( cd $T_PX/dev ; rm -f mouse ; ln -sf psaux mouse )
	MTYPE="imps2"
elif [ "$MOUSE_TYPE" = "logibm" ]; then
	( cd $T_PX/dev ; rm -f mouse ; ln -sf logibm mouse )
	MTYPE="ps2"
elif [ "$MOUSE_TYPE" = "atibm" ]; then
	( cd $T_PX/dev ; rm -f mouse ; ln -sf atibm mouse )
	MTYPE="ps2"
elif [ "$MOUSE_TYPE" = "inportbm" ]; then
	( cd $T_PX/dev ; rm -f mouse ; ln -sf inportbm mouse )
	MTYPE="bm"
elif [ "$MOUSE_TYPE" = "js" ]; then
	( cd $T_PX/dev ; rm -f mouse ; ln -sf js0 mouse )
	MTYPE="js"
elif [ "$MOUSE_TYPE" = "usb" ]; then
	( cd $T_PX/dev ; rm -f mouse ; ln -sf input/mice mouse )
	MTYPE="imps2"
fi

exit 0

