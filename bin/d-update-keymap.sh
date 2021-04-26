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
TMP=/tmp
ROOTDIR=/

set_default_locales() {

	local locale="$(cat $TMP/selected-locale 2> /dev/null)"
	local result="$(grep -F -m1 "^$locale" /etc/locale.gen)"

	if [ "$result" = "" ]; then
		locale="en_US"
	else
		locale="$(echo "$result" | sed 's/[.].*//g')"
	fi

	sed -i -r "s/^#[ ]*$locale/$locale/g" /etc/locale.gen

	locale-gen

	echo "LANG=$1" > /etc/default/locale

	return 0
}

update_services()
{
	local srv="$(brzctl selected nis 2> /dev/null)"

	brzctl force-disable bind inetd
	brzctl enable klogd sysklogd

	if [ -n "$srv" -a "$srv" != "disabled" ]; then
		/sbin/d-update-nis.sh on
	fi
	return 0
}

update_keymap()
{
	# Load keyboard map (if any) when booting
	#
	local locale="$(cat $TMP/selected-locale 2> /dev/null)"
	local keymap="$(cat $TMP/selected-keymap 2> /dev/null)"
	local layout="$(cat $TMP/selected-kbd-layout 2> /dev/null)"
	local mapname="$keymap/us"

	find /usr/share/kbd/keymaps/ -type f -name '*.gz' 1> /tmp/keymap.lst

	if [ "$layout" = "locale" ]; then

		locale="$(echo $locale | cut -f2 -d'_' | tr '[:upper:]' '[:lower:]')"
		mapname="$keymap/$locale"

		if [ "$keymap" = "dvorak" ]; then
			mapname="dvorak/dvorak-${locale}"
		fi
	fi

	local symbols="$(find /usr/share/X11/xkb/symbols | grep -F -m1 "/$locale")"

	if [ ! -e /usr/share/X11/xkb/symbols/default ]; then
		if [ -z "$symbols" ]; then
			symbols="us"
		fi
		cd /usr/share/X11/xkb/symbols
		ln -s $symbols default
		cd /
	fi

	local filename="$(grep -F -q -m1 "${mapname}" /tmp/keymap.lst)"

	if [ -n "$filename" ]; then
		mapname="$(basename $filename '.map.gz')"
	elif [ "$keymap" = "dvorak" ]; then
		mapname="dvorak/ANSI-dvorak"
	else
		mapname="qwerty/us"
	fi

	brzctl set keymap keymap "$mapname"

#	echo "#!/bin/bash" 1> /etc/rc.d/rc.keymap
#	echo "# Maps are in /usr/share/kbd/keymaps/" >> /etc/rc.d/rc.keymap
#	echo "# Load the selected keyboard map" >> /etc/rc.d/rc.keymap
#	echo "#" >> /etc/rc.d/rc.keymap
#	echo "if [ -x /usr/bin/loadkeys ]; then" >> /etc/rc.d/rc.keymap
#	echo "    /usr/bin/loadkeys $mapname" >> /etc/rc.d/rc.keymap
#	echo "fi" >> /etc/rc.d/rc.keymap
#	echo "" >> /etc/rc.d/rc.keymap
	chmod 755 /etc/rc.d/rc.keymap

    echo "$locale" 1> /etc/locale
    echo "$mapname" 1> /etc/kbdname
    echo "$symbols" 1> /etc/kbdlocale

	return 0
}

# Main starts here ...
cd /

XORGCFG="all"

DEVICE="$(cat $TMP/selected-target 2> /dev/null)"
DRIVE_ID="$(basename $DEVICE)"
GPT_MODE="$(extract_value scheme-${DRIVE_ID} 'gpt-mode' 'upper')"

DESKTOP="$(cat $TMP/selected-desktop 2> /dev/null)"
PKGTYPE="$(cat $TMP/selected-pkgtype 2> /dev/null)"

[ -z "$DESKTOP" ] && DESKTOP="xfce"

echo "INSTALLER: MESSAGE L_UPDATING_LIB_DATABASE"
/sbin/ldconfig 1> /dev/null 2>&1

echo "INSTALLER: MESSAGE L_UPDATING_SYSTEM_FILES"
update_system_files
sync; sleep 1

echo "INSTALLER: MESSAGE L_UPDATING_SYSTEM_KEYMAP"
update_keymap
sync; sleep 1

echo "INSTALLER: MESSAGE L_UPDATING_USER_ACCOUNTS"
update_user_accounts
sync; sleep 1

echo "INSTALLER: MESSAGE L_UPDATING_LVM_PARTITIONS"
update_lvm_partitions
sync; sleep 1

echo "INSTALLER: MESSAGE L_UPDATING_SYSTEM_SERVICES"
update_services
sync; sleep 1

echo "INSTALLER: MESSAGE L_UPDATING_SYSTEM_CLOCK"
timezone="$(cat $TMP/selected-timezone 2> /dev/null)"
/sbin/d-update-desktop.sh timezone $timezone
sync; sleep 1

echo "INSTALLER: MESSAGE L_UPDATING_FONT_CACHE"
/sbin/d-update-desktop.sh fonts
sync; sleep 1

echo "INSTALLER: MESSAGE L_UPDATING_MIME_DATABASE"
/sbin/d-update-desktop.sh mime
sync; sleep 1

echo "INSTALLER: MESSAGE L_UPDATING_ICON_CACHE"
/sbin/d-update-desktop.sh icons
sync; sleep 1

echo "INSTALLER: MESSAGE L_UPDATING_DESKTOP_SCHEMAS"
/sbin/d-update-desktop.sh schemas
sync; sleep 1

echo "INSTALLER: MESSAGE L_UPDATING_PANGO_SETTINGS"
/sbin/d-update-desktop.sh pango
sync; sleep 1

echo "INSTALLER: MESSAGE L_UPDATING_DESKTOP_DATABASE"
/sbin/d-update-desktop.sh desktop
sync; sleep 1

echo "INSTALLER: MESSAGE L_UPDATING_CA_CERTS"
/sbin/d-update-desktop.sh certificates
sync; sleep 1

if [ "$(brzctl selected sshd 2> /dev/null)" != "disabled" ]; then
	echo "INSTALLER: MESSAGE L_UPDATING_SSL_CERTS"
	/sbin/d-update-desktop.sh ssl overwrite
	sync; sleep 1
fi

if [ "$GPT_MODE" = "S-UEFI" ]; then
	echo "INSTALLER: MESSAGE L_UPDATING_UEFI_CERTS"
	/sbin/d-update-desktop.sh uefi overwrite
	sync; sleep 1
fi

echo "INSTALLER: MESSAGE L_UPDATING_NETWORK_CONFIG"
/sbin/d-update-network.sh
sync; sleep 1

if [ "$PKGTYPE" = "squashfs" ]; then XORGCFG="keyboard"; fi

echo "INSTALLER: MESSAGE L_UPDATING_XORG_CONFIG"
/sbin/d-update-display.sh -yes $XORGCFG
sync; sleep 1

echo "INSTALLER: MESSAGE L_UPDATING_DISPLAY_MANAGER"
#desktop="$(brzctl get displaymgr desktop xfce 2> /dev/null)"
/sbin/d-update-desktop.sh xdm brzdm $DESKTOP midnight
sync; sleep 1

# Removing Live Edition marker file
rm -f /BRZLIVE
rm -f /BRZINSTALL
rm -f $TMP/account*
rm -f $TMP/useradd*
rm -f $TMP/selected-users
rm -f $TMP/*.sh

echo "INSTALLER: MESSAGE L_SAVING_TMP_FILES"
mkdir -p /var/tmp/brzinst
cp -a $TMP/* /var/tmp/brzinst/
sync; sleep 1

exit 0

# end Breeze::OS setup script
