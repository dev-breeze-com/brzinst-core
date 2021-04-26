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
# Initialize folder paths
. d-dirpaths.sh

HOST="$(cat /etc/hostname 2> /dev/null)"
IPADDR="$(cat $TMP/selected-lan-ipaddr 2> /dev/null)"
DERIVED="$(cat $TMP/selected-derivative 2> /dev/null)"

DEVICE="$(cat $TMP/selected-target 2> /dev/null)"
DRIVE_ID="$(basename $DEVICE)"
GPT_MODE="$(extract_value scheme-${DRIVE_ID} 'gpt-mode' 'upper')"

FILES="skel timezone shells passwd shadow group hostname HOSTNAME hosts hosts.allow hosts.deny dhcpc resolv.conf etc_fstab etc_crypttab etc_dmcrypt login.defs adduser.conf ld.so.conf cfgnow.lst multipath.conf openssl.cnf uefi.cnf scheme firewall os-release lsb-release keys brzdm.conf asound.conf"

for entry in $FILES ; do

	if [ "$entry" = "sales.asc" ]; then

		mkdir -p $ROOTDIR/etc/config/ssl/
		mkdir -p $ROOTDIR/etc/config/crypt/keys/
		mkdir -p $ROOTDIR/etc/config/keyring/public/
		mkdir -p $ROOTDIR/etc/config/keyring/private/

		if [ -f $MOUNTPOINT/sales.asc ]; then
			cp -f $MOUNTPOINT/sales.asc $ROOTDIR/etc/config/crypt/keys/
		elif [ -f $MOUNTPOINT/breezeos.asc ]; then
			cp -f $MOUNTPOINT/breezeos.asc $ROOTDIR/etc/config/crypt/keys/
		elif [ -f $ROOTDIR/etc/brzpkg/breezeos.asc ]; then
			cp $ROOTDIR/etc/brzpkg/breezeos.asc $ROOTDIR/etc/config/crypt/keys/ 
		fi
	elif [ "$entry" = "openssl.cnf" ]; then
		if [ -f $TMP/openssl.cnf ]; then
			mkdir -p $ROOTDIR/etc/openssl/
			cp -f $TMP/openssl.cnf $ROOTDIR/etc/openssl/
			chmod a+r,a-wx $ROOTDIR/etc/openssl/openssl.cnf
		fi
	elif [ "$entry" = "uefi.cnf" -a "$GPT_MODE" = "UEFI" ]; then
		if [ -f $TMP/uefi.cnf ]; then
			mkdir -p $ROOTDIR/etc/config/uefi/keys/
			cp -f $TMP/uefi.cnf $ROOTDIR/etc/config/uefi/
			chmod a+r,a-wx $ROOTDIR/etc/config/uefi/uefi.cnf
		fi
	elif [ "$entry" = "etc_crypttab" ]; then
		if [ -f $TMP/etc_crypttab ]; then
			cp -f $TMP/etc_crypttab $ROOTDIR/etc/crypttab
			chmod 0644 $ROOTDIR/etc/crypttab
		fi
	elif [ "$entry" = "etc_fstab" ]; then
		if [ -f $TMP/etc_fstab ]; then
			cp -f $TMP/etc_fstab $ROOTDIR/etc/fstab
			chmod 0644 $ROOTDIR/etc/fstab
		fi
	elif [ "$entry" = "etc_dmcrypt" ]; then
		if [ -f $TMP/etc_dmcrypt ]; then
			mkdir -p $ROOTDIR/etc/conf.d/
			cp -f $TMP/etc_dmcrypt $ROOTDIR/etc/conf.d/dmcrypt
			chmod 0644 $ROOTDIR/etc/conf.d/dmcrypt
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
	elif [ "$entry" = "os-release" -o "$entry" = "lsb-release" ]; then
		if [ ! -f $ROOTDIR/etc/brzpkg/$entry ]; then 
			if [ -f $TMP/$entry ]; then
				cp -a $TMP/$entry $ROOTDIR/etc/brzpkg/
			fi
		fi
	elif [ "$entry" = "multipath.conf" -o "$entry" = "brzdm.conf" ]; then
		if [ -f $BRZDIR/factory/$entry ]; then
			cp -f $BRZDIR/factory/$entry $ROOTDIR/etc/
			chmod 0644 $ROOTDIR/etc/$entry
		fi
	elif [ "$entry" = "asound.conf" ]; then
		if egrep -q 'VERSION=2[.][0-9]' $TMP/os-release ; then
			if [ -f $BRZDIR/factory/$entry ]; then
				cp -f $BRZDIR/factory/$entry $ROOTDIR/etc/
				chmod 0644 $ROOTDIR/etc/$entry
			fi
		fi
	elif [ -d "/etc/$entry" ]; then

		cp -a /etc/$entry $ROOTDIR/etc/

		if [ "$entry" = "skel" ]; then
			mkdir -p $ROOTDIR/etc/skel/.config/vlc/
			cp $BRZDIR/factory/vlcrc $ROOTDIR/etc/skel/.config/vlc/

			mkdir -p $ROOTDIR/etc/skel/.kde/share/config/
			cp $BRZDIR/factory/plasmarc $ROOTDIR/etc/skel/.kde/share/config/

			if [ -f $ROOTDIR/usr/share/vim/vimrc ]; then
				cp $ROOTDIR/usr/share/vim/vimrc $ROOTDIR/etc/skel/.vimrc
			fi
		fi
	elif [ "$entry" = "keys" ]; then
		if [ -d $TMP/etc/keys ]; then
			cp -a $TMP/etc/keys $ROOTDIR/etc/
			chmod -R 0400 $ROOTDIR/etc/keys/
			chmod 0700 $ROOTDIR/etc/keys/
		fi
	elif echo "$entry" | grep -q -F "hosts" ; then

		if [ -e "/etc/$entry" ]; then
			cp -af /etc/$entry $ROOTDIR/etc/
			chmod 0644 $ROOTDIR/etc/$entry
		fi

		if [ -f "$BRZDIR/factory/$entry" ]; then
			cp -af $BRZDIR/factory/$entry $ROOTDIR/etc/
			chmod 0644 $ROOTDIR/etc/$entry
		fi
	elif [ -e "/etc/$entry" ]; then
		if echo "$entry" | grep -q -E "^(group|passwd|shadow)$" ; then
			if [ -f "$BRZDIR/factory/$DERIVED/$entry" ]; then
				cp -a $BRZDIR/factory/$DERIVED/$entry $ROOTDIR/etc/
				chmod 0644 $ROOTDIR/etc/$entry
			fi
		else
			cp -a /etc/$entry $ROOTDIR/etc/
			chmod 0644 $ROOTDIR/etc/$entry
		fi
	elif [ -e "$BRZDIR/factory/$entry" ]; then
		cp -af $BRZDIR/factory/$entry $ROOTDIR/etc/
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

if [ -r /etc/lvmtab -o -d /etc/lvm/backup ]; then
    echo "on" 1> $ROOTDIR/tmp/lvm-enabled
fi

exit 0

# end Breeze::OS setup script
