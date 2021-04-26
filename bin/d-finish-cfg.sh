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
# Took writeclock from Slackware /usr/sbin/timeconfig
#
TMP=/tmp
ROOTDIR=/

. $TMP/bin/d-dirpath.sh

. $TMP/bin/d-crypto-utils.sh

# writeclock( $CLOCK_SET_TO )
#
# Writes out /etc/hardwareclock that tells rc.S how the hardware clock
# value is stored.
writeclock()
{
	local hwclock="/etc/hardwareclock"
	echo "# /etc/hardwareclock" 1> $hwclock
	echo "#" >> $hwclock
	echo "# Tells how the hardware clock time is stored." >> $hwclock
	echo "# You should run timeconfig to edit this file." >> $hwclock
	echo >> $hwclock
	echo "$1" >> $hwclock
	return 0
}

update_dialout_files()
{
	if [ -f $TMP/wvdial.conf ]; then
		# Copy dialup config file ...
		cp -f $TMP/wvdial.conf $ROOTDIR/etc/
	fi

	if [ -f "$TMP/ddclient.conf" ]; then
		# Copy ddclient configuration ...
		cp -f $TMP/ddclient.conf $ROOTDIR/etc/
	fi
	return 0
}

update_system_files()
{
	if [ -f "$TMP/interfaces" ]; then
		# Copy network interface file ...
		cp -f $TMP/interfaces $ROOTDIR/etc/network/
	fi

	# Copy fstab,hostname to root device
	cp -f $TMP/selected-hostname /etc/hostname
	cp -f $TMP/selected-hostname /etc/HOSTNAME
	cp -f $TMP/etc_fstab /etc/fstab

	# Copy timezone,localtime to root device
	rm -f /etc/localtime
	cp -f $TMP/selected-timezone /etc/timezone
	cp -f /usr/share/zoneinfo/$TIMEZONE /etc/localtime

	# Copy the password files ...
	cp -fa $TMP/etc_shadow /etc/shadow
	cp -fa $TMP/etc_shadow /etc/shadow.org
	cp -fa $TMP/etc_passwd /etc/passwd
	cp -fa $TMP/etc_passwd /etc/passwd.org
	cp -fa $TMP/etc_group /etc/group

	chown root.shadow /etc/shadow /etc/shadow.org /etc/gshadow
	chmod 640 /etc/shadow /etc/shadow.org /etc/gshadow

	return 0
}

update_user_homedirs()
{
	# Copy skel files to users' home folder ...
	USERS="$(cat $TMP/selected-users 2> /dev/null)"

	OTHERS="cdrom,disk,floppy,dialout,audio,video,scanner,plugdev,powerdev,bluetooth,netdev"

	cp -a /usr/share/vim/vimrc /etc/skel/.vimrc

	mkdir -p /root/

	cp -a /etc/skel/.[a-z]* /root/
	chown -R root.root /root/

	for user in secadmin $USERS; do

		mkdir -p /home/$user/
		cp -a /etc/skel/.[a-z]* /home/$user/
		chown -R ${user}.users /home/$user/
		usermod -a -G "$OTHERS" $user 2> /tmp/usermod.err

		if [ $? = 0 ]; then
			if [ "$CRYPTO_TYPE" = "encfs" -o "$CRYPTO_TYPE" = "ecryptfs" ]; then
				init_crypto_$CRYPTO_TYPE $SELECTED_DRIVE /home $user
			fi
		fi
	done
	return 0
}

update_lvm_partitions()
{
	# Prepare for LVM in a newly installed system
	#
	if [ -f $TMP/lvm-enabled ]; then # Available in local root
		if [ ! -r /etc/lvmtab -a ! -d /etc/lvm/backup ]; then
			/sbin/vgscan --mknodes --ignorelockingfailure 2> /dev/null
			# First run does not always catch LVM on a LUKS partition:
			/sbin/vgscan --mknodes --ignorelockingfailure 2> /dev/null
		fi
	fi
	return 0
}

update_selected_keymap()
{
	# Load keyboard map (if any) when booting
	#
	if [ -r $TMP/seleted-keymap ]; then

		MAPNAME="$(cat $TMP/selected-keymap)"

		echo "#!/bin/bash" 1> /etc/rc.d/rc.keymap
		echo "# Load the keyboard map." >> /etc/rc.d/rc.keymap
		echo "# More maps are in /usr/share/kbd/keymaps." >> /etc/rc.d/rc.keymap
		echo "#" >> /etc/rc.d/rc.keymap
		echo "if [ -x /usr/bin/loadkeys ]; then" >> /etc/rc.d/rc.keymap
		echo -e "\t/usr/bin/loadkeys $MAPNAME" >> /etc/rc.d/rc.keymap
		echo "fi" >> /etc/rc.d/rc.keymap
		echo "" >> /etc/rc.d/rc.keymap
		chmod 755 /etc/rc.d/rc.keymap
	fi
	return 0
}

# Main starts here ...
cd /

TIMEZONE="$(cat $TMP/selected-timezone 2> /dev/null)"
ROOT_DEVICE="$(cat $TMP/root-device 2> /dev/null)"
SELECTED_DRIVE="$(cat $TMP/selected-drive 2> /dev/null)"
DRIVE_ID="$(basename SELECTED_DRIVE)"

CIPHER="$(extract_value crypto-${DRIVE_ID} 'cipher')"
HASHALGO="$(extract_value crypto-${DRIVE_ID} 'hash')"
KEYSIZE="$(extract_value crypto-${DRIVE_ID} 'key-size')"
CRYPTO_TYPE="$(extract_value crypto-${DRIVE_ID} 'type')"

DEFAULT_DM="$(cat $TMP/selected-xdm 2> /dev/null)"
echo "$DEFAULT_DM" 1> /etc/X11/default-display-manager

update_dialout_files

update_system_files

update_user_homedirs

update_lvm_partitions

update_selected_keymap

# Update package database
/usr/bin/sqlite3 /etc/brzpkg/packages.db < /tmp/db-updates

for script in /var/log/setup/setup.* ; do

	if [ -x "$script" ]; then
		name="$(basename $script)"

		if [ "$name" != "setup.liloconfig" -a \
			"$name" != "setup.timeconfig" -a \
			"$name" != "setup.mouse" -a \
			"$name" != "setup.xwmconfig" -a \
			"$name" != "setup.70.install-kernel" -a \
			"$name" != "setup.80.make-bootdisk" ]; then
			. $script / $ROOT_DEVICE
		fi
	fi
done

writeclock "UTC"

# Add display manager invocation to rc.local script
echo "exec /etc/rc.d/rc.4" >> /etc/rc.d/rc.local
echo "" >> /etc/rc.d/rc.local

exit $?

# end Breeze::OS setup script
