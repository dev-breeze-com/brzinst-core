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

. $TMP/d-dirpaths.sh

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
	local srv="$(brzctl selected authorization 2> /dev/null)"

	brzctl force-disable bind
	brzctl force-disable inetd

	brzctl enable klogd sysklogd
	brzctl enable taskmgr dcron
	brzctl enable hwnet networkmanager

	brzctl enable alsa
	brzctl enable alsa-oss
	brzctl enable messagebus
	brzctl enable consolekit
	brzctl enable udev

	if egrep -q 'VERSION=2[.][0-9]' /etc/brzpkg/os-release ; then
		cp /etc/asound.conf /etc/skel/.asoundrc
		brzctl enable sound pulseaudio
	fi

#	if ! grep -q sysdefault ${LIVE_ROOTDIR}/etc/asound.conf ; then
#		# If pulse is used, configure a fallback to use the system default
#		# or else there will not be sound on first boot:
#		sed -i ${LIVE_ROOTDIR}/etc/asound.conf \
#			-e '/type pulse/ a \ \ fallback "sysdefault"'
#	fi

	if [ -e /etc/rc.d/rc.policykit ]; then
		brzctl enable policykit
	fi

	if [ "$ENCRYPTED" = "yes" ]; then
		if [ "$CRYPTO" = "luks" ]; then
			brzctl enable encryption dmcrypt
		elif [ "$CRYPTO" = "encfs" ]; then
			brzctl enable encryption encfs
		elif [ "$CRYPTO" = "ext4" ]; then
			brzctl enable encryption ext4
		fi
	fi

	if [ "$srv" = "nis" ]; then
		d-update-nis.sh on
	fi
	return 0
}

update_system_files()
{
	if [ -f /etc/mkinitrd.conf.sample ]; then
		cp -f /etc/mkinitrd.conf.sample /etc/mkinitrd.conf
	fi

#	cp -f /etc/hostname /etc/HOSTNAME
#	chmod 0644 /etc/hostname /etc/HOSTNAME

	if [ -f $TMP/openssl.cnf ]; then
		cp -f $TMP/openssl.cnf /etc/openssl/
	fi

	if [ -f $TMP/etc_fstab ]; then
		if ! cmp -s $TMP/etc_fstab /etc/fstab ; then
			cp -f $TMP/etc_fstab /etc/fstab
			chmod 0644 /etc/fstab
		fi
	fi
	return 0
}

update_user_accounts()
{
	local groups="cdrom disk floppy dialout audio video scanner plugdev netdev power wheel fuse powerdev bluetooth"
	local others=""

	for gid in $groups; do
		if grep -F -q -m1 $gid /etc/group ; then
			if [ "$others" = "" ]; then
				others="$gid"
			else
				others="$others,$gid"
			fi
		fi
	done

	mkdir -p /root/
	cp -a /etc/skel/.[a-z]* /root/
	chown -R root.root /root/

	mkdir -p /home/secadmin/
	cp -a /etc/skel/.[a-z]* /home/secadmin/
	chown -R secadmin.users /home/secadmin/

#	if [ -x /sbin/shadowconfig ]; then
#		/sbin/shadowconfig on # For PAM
#	fi

	while read line; do

		if [ -z "$line" ]; then
			continue
		fi

		user="$(echo "$line" | cut -f1 -d ':')"
		userid="$(echo "$line" | cut -f2 -d ':')"
		group="$(echo "$line" | cut -f3 -d ':')"
		fullname="$(echo "$line" | cut -f4 -d ':')"
		homedir="$(echo "$line" | cut -f5 -d ':')"
		crypted="$(echo "$line" | cut -f6 -d ':')"

		USERID=""
		GROUPID=""
		SYS=""

		if [ -n "$userid" ]; then
			USERID=" --uid $userid"
		fi

		if [ -n "$group" ]; then
			GROUPID=" --gid $group"
		fi

		if [ "$user" = "root" ]; then
			SYS=" --system "
		fi

		echo "INSTALLER: MESSAGE TIP_UPDATING_USER_ACCOUNT((user,$user),(uid,$userid),(gid,$group),(homedir,$homedir))"
		sync; sleep 1

		if ! grep -qE "^$user:" /etc/shadow ; then
			useradd -m $USERID $GROUPID $SYS \
				-c "$fullname" \
				-d $homedir \
				-G $others \
				-p "$crypted" \
				-s /bin/bash $user 2> $TMP/useradd.$user
		else
			usermod $USERID $GROUPID \
				-c "$fullname" \
				-d $homedir \
				-G $others \
				-p "$crypted" \
				-s /bin/bash $user 2> $TMP/useradd.$user
		fi
	done < $TMP/selected-users

	userdel -rf live 2> /dev/null

	chown root.shadow /etc/shadow
	chmod 0644 /etc/passwd /etc/group
	chmod 0640 /etc/shadow

	return 0
}

check_file_permissions()
{
#	chmod a+rx,u+w,a-s /usr/bin/dbus-daemon
#	chmod u+rwsx,g+rx,o-rwx /usr/libexec/dbus-daemon-launch-helper
	return 0
}

update_lvm_partitions()
{
	# Prepare for LVM in a newly installed system
	#
	if [ -f $TMP/lvm-enabled ]; then # Available in local root
		if [ ! -r /etc/lvmtab -a ! -d /etc/lvm/backup ]; then
			# First run does not always catch LVM on a LUKS partition:
			vgscan --mknodes --ignorelockingfailure 2> /dev/null
		fi
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
		if [ "$symbols" = "" ]; then symbols="us"; fi

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
ENCRYPTED="$(extract_value scheme-${DRIVE_ID} 'encrypted')"
CRYPTO="$(extract_value scheme-${DRIVE_ID} 'type')"

DESKTOP="$(cat $TMP/selected-desktop 2> /dev/null)"
PKGTYPE="$(cat $TMP/selected-pkgtype 2> /dev/null)"

[ -z "$DESKTOP" ] && DESKTOP="xfce"

echo "INSTALLER: MESSAGE L_UPDATING_LIB_DATABASE"
ldconfig 1> /dev/null 2>&1

echo "INSTALLER: MESSAGE L_UPDATING_SYSTEM_FILES"
update_system_files
sync; sleep 1

echo "INSTALLER: MESSAGE L_UPDATING_SYSTEM_KEYMAP"
update_keymap
sync; sleep 1

echo "INSTALLER: MESSAGE L_UPDATING_LVM_PARTITIONS"
update_lvm_partitions
sync; sleep 1

echo "INSTALLER: MESSAGE L_UPDATING_SYSTEM_SERVICES"
update_services
sync; sleep 1

echo "INSTALLER: MESSAGE L_UPDATING_USER_ACCOUNTS"
update_user_accounts
sync; sleep 1

echo "INSTALLER: MESSAGE L_CHECKING_FILE_PERMISSIONS"
check_file_permissions
sync; sleep 1

echo "INSTALLER: MESSAGE L_UPDATING_SYSTEM_CLOCK"
timezone="$(cat $TMP/selected-timezone 2> /dev/null)"
d-update-desktop.sh timezone $timezone LOCAL
sync; sleep 1

echo "INSTALLER: MESSAGE L_UPDATING_FONT_CACHE"
d-update-desktop.sh fonts
sync; sleep 1

echo "INSTALLER: MESSAGE L_UPDATING_MIME_DATABASE"
d-update-desktop.sh mime
sync; sleep 1

echo "INSTALLER: MESSAGE L_UPDATING_ICON_CACHE"
d-update-desktop.sh icons
sync; sleep 1

echo "INSTALLER: MESSAGE L_UPDATING_DESKTOP_SCHEMAS"
d-update-desktop.sh schemas
sync; sleep 1

echo "INSTALLER: MESSAGE L_UPDATING_PANGO_SETTINGS"
d-update-desktop.sh pango
sync; sleep 1

echo "INSTALLER: MESSAGE L_UPDATING_DESKTOP_DATABASE"
d-update-desktop.sh desktop
sync; sleep 1

echo "INSTALLER: MESSAGE L_UPDATING_CA_CERTS"
d-update-desktop.sh certificates
sync; sleep 1

if [ "$(brzctl selected sshd 2> /dev/null)" != "disabled" ]; then
	echo "INSTALLER: MESSAGE L_UPDATING_SSL_CERTS"
	d-update-desktop.sh ssl overwrite
	sync; sleep 1
fi

if [ "$GPT_MODE" = "S-UEFI" ]; then
	echo "INSTALLER: MESSAGE L_UPDATING_UEFI_CERTS"
	d-update-desktop.sh uefi overwrite
	sync; sleep 1
fi

echo "INSTALLER: MESSAGE L_UPDATING_NETWORK_CONFIG"
d-update-network.sh networkmanager
sync; sleep 1

if [ "$PKGTYPE" = "squashfs" ]; then XORGCFG="keyboard"; fi

echo "INSTALLER: MESSAGE L_UPDATING_XORG_CONFIG"
d-update-display.sh -yes $XORGCFG
sync; sleep 1

echo "INSTALLER: MESSAGE L_UPDATING_POLICY_RULES"
d-update-desktop.sh policy restart shutdown
sync; sleep 1

echo "INSTALLER: MESSAGE L_UPDATING_DISPLAY_MANAGER"
d-update-desktop.sh xdm brzdm $DESKTOP midnight
sync; sleep 1

# Removing Live and Install Edition marker file
rm -f $ROOTDIR/BRZLIVE
rm -f $ROOTDIR/BRZINSTALL

rm -f $TMP/users-*
rm -f $TMP/useradd*
rm -f $TMP/selected-users
rm -f $TMP/*.sh

exit 0

# end Breeze::OS setup script
