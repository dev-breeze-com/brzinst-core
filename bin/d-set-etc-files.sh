#!/bin/bash
#
# GNU GENERAL PUBLIC LICENSE -- Version 3
#
# Copyright 2013 Pierre Innocent, Tsert Inc. All rights reserved.
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

# Make sure /etc/config/network is present
mkdir -p $ROOTDIR/etc/config/network
chmod 0755 $ROOTDIR/etc/config/network

# Make sure /etc/config/settings is present
mkdir -p $ROOTDIR/etc/config/settings
chmod 0755 $ROOTDIR/etc/config/settings

# Make sure /etc/config/services is present
mkdir -p $ROOTDIR/etc/config/services
chmod 0755 $ROOTDIR/etc/config/services

HOST="$(cat /etc/hostname 2> /dev/null)"
DERIVED="$(cat $TMP/selected-derivative 2> /dev/null)"

FILES="skel timezone shells passwd shadow group hostname HOSTNAME hosts hosts.allow hosts.deny dhcpc resolv.conf etc_fstab login.defs adduser.conf rc.local ld.so.conf cfgnow.lst multipath.conf sales.asc openssl.cnf uefi.cnf etc_dmcrypt"

for entry in $FILES ; do

	if [ "$entry" = "sales.asc" ]; then
		if [ -f $MOUNTPOINT/sales.asc ]; then
			mkdir -p $ROOTDIR/etc/config/ssl/
			mkdir -p $ROOTDIR/etc/config/crypt/keys/
			mkdir -p $ROOTDIR/etc/config/keyring/public/
			mkdir -p $ROOTDIR/etc/config/keyring/private/
			cp -f $MOUNTPOINT/sales.asc $ROOTDIR/etc/config/crypt/keys/
		fi
	elif [ "$entry" = "openssl.cnf" ]; then
		if [ -f $TMP/openssl.cnf ]; then
			mkdir -p $ROOTDIR/etc/openssl/
			cp -f $TMP/openssl.cnf $ROOTDIR/etc/openssl/
			chmod a+r,a-wx $ROOTDIR/etc/openssl/openssl.cnf
		fi
	elif [ "$entry" = "uefi.cnf" ]; then
		if [ -f $TMP/uefi.cnf ]; then
			mkdir -p $ROOTDIR/etc/config/uefi/keys/
			cp -f $TMP/uefi.cnf $ROOTDIR/etc/config/uefi/
			chmod a+r,a-wx $ROOTDIR/etc/config/uefi/uefi.cnf
		fi
	elif [ "$entry" = "multipath.conf" ]; then
		if [ -f /install/factory/$entry ]; then
			cp -f /install/factory/$entry $ROOTDIR/etc/
			chmod 0644 $ROOTDIR/etc/multipath.conf
		fi
	elif [ "$entry" = "rc.local" ]; then
		if [ -f /install/factory/$DERIVED/$entry ]; then
			cp -f /install/factory/$DERIVED/$entry $ROOTDIR/etc/
			chmod 0755 $ROOTDIR/etc/rc.local
		fi
	elif [ "$entry" = "cfgnow.lst" ]; then
		if [ -f /install/factory/$DERIVED/$entry ]; then
			cp -f /install/factory/$DERIVED/$entry $TMP/
			cp -f /install/factory/$DERIVED/$entry $ROOTDIR/tmp/
		fi
	elif [ "$entry" = "adduser.conf" ]; then
		if [ -f $ROOTDIR/etc/adduser.conf ]; then
			sed -i -r 's/USERGROUPS=yes/USERGROUPS=no/g' \
				$ROOTDIR/etc/adduser.conf
		fi
	elif [ "$entry" = "login.defs" ]; then
		if [ -f $ROOTDIR/etc/login.defs ]; then 
		    sed -i -r 's/USERGROUPS_ENAB yes/USERGROUPS_ENAB no/g' \
				$ROOTDIR/etc/login.defs
		fi
	elif [ "$entry" = "etc_fstab" ]; then
		if [ -f $TMP/etc_fstab ]; then
			cp -f $TMP/etc_fstab $ROOTDIR/etc/fstab
			chmod 0644 $ROOTDIR/etc/fstab
		fi
	elif [ "$entry" = "etc_dmcrypt" ]; then
		if [ -f $TMP/etc_dmcrypt ]; then
			cp -f $TMP/etc_dmcrypt $ROOTDIR/etc/conf.d/dmcrypt
			chmod 0644 $ROOTDIR/etc/conf.d/dmcrypt
		fi
	elif [ -d "/etc/$entry" ]; then

		cp -a /etc/$entry $ROOTDIR/etc/

		if [ "$entry" = "skel" ]; then
			mkdir -p $ROOTDIR/etc/skel/.config/vlc/
			cp /install/factory/vlcrc $ROOTDIR/etc/skel/.config/vlc/

			if [ -f $ROOTDIR/usr/share/vim/vimrc ]; then
				cp $ROOTDIR/usr/share/vim/vimrc $ROOTDIR/etc/skel/.vimrc
			fi
		fi
	elif echo "$entry" | grep -q -F "hosts" ; then
		if [ -e "/etc/$entry" ]; then
			cp -f /etc/$entry $ROOTDIR/etc/
			chmod 0644 $ROOTDIR/etc/$entry
		fi

		if [ "$DERIVED" = "debian" ]; then
			if [ -e "/install/factory/$entry" ]; then
				cp -f /install/factory/$entry $ROOTDIR/etc/
				chmod 0644 $ROOTDIR/etc/$entry
			fi
		fi
	elif [ -e "/etc/$entry" ]; then

		cp -f /etc/$entry $ROOTDIR/etc/
		chmod 0644 $ROOTDIR/etc/$entry

		if [ "$DERIVED" = "debian" -a "$entry" = "group" ]; then
			cp -f /install/factory/debian/etc_group $ROOTDIR/etc/group
			chmod 0644 $ROOTDIR/etc/group
		fi
	elif [ -e "/install/factory/$entry" ]; then
		cp -f /install/factory/$entry $ROOTDIR/etc/
		chmod 0644 $ROOTDIR/etc/$entry
	fi

	if [ "$entry" = "shadow" ]; then

		chown root.shadow $ROOTDIR/etc/shadow
		chmod 640 $ROOTDIR/etc/shadow

		if [ -e $ROOTDIR/etc/shadow.org ]; then
			chown root.shadow $ROOTDIR/etc/shadow.org
			chmod 640 $ROOTDIR/etc/shadow.org
		fi

		if [ -e $ROOTDIR/etc/gshadow ]; then
			chown root.shadow $ROOTDIR/etc/gshadow
			chmod 640 $ROOTDIR/etc/gshadow
		fi
	fi
done

sed -r -i "s/breeze/$HOST/g" /etc/hosts
sed -r -i "s/breeze/$HOST/g" $ROOTDIR/etc/hosts

exit 0

# end Breeze::OS setup script
