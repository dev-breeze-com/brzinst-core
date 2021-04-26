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

update_system_files()
{
#    if ! grep -q sysdefault ${LIVE_ROOTDIR}/etc/asound.conf ; then
#        # If pulse is used, configure a fallback to use the system default
#        # or else there will not be sound on first boot:
#        sed -i ${LIVE_ROOTDIR}/etc/asound.conf \
#            -e '/type pulse/ a \ \ fallback "sysdefault"'
#    fi

    cp -f /etc/hostname /etc/HOSTNAME
    chmod 0644 /etc/hostname /etc/HOSTNAME

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
    local groups="cdrom disk floppy dialout audio video scanner plugdev netdev power wheel fuse powerdev bluetooth lp"
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

#    if [ -x /sbin/shadowconfig ]; then
#        /sbin/shadowconfig on # For PAM
#    fi

    while read line; do

        if [ -z "$line" ]; then
            continue
        fi

        local user="$(echo "$line" | cut -f1 -d ':')"
        local userid="$(echo "$line" | cut -f2 -d ':')"
        local group="$(echo "$line" | cut -f3 -d ':')"
        local fullname="$(echo "$line" | cut -f4 -d ':')"
        local homedir="$(echo "$line" | cut -f5 -d ':')"
        local crypted="$(echo "$line" | cut -f6 -d ':')"
        local SYSOPTS=""
        local USROPTS=""

        if [ -n "$userid" ]; then
            USROPTS="$USROPTS --uid $userid"
        fi

        if [ -n "$group" ]; then
            USROPTS="$USROPTS --gid $group"
        fi

        if [ "$user" = "root" ]; then
            SYSOPTS=" --system "
        fi

        echo_message "TIP_UPDATING_USER_ACCOUNT((user,$user),(uid,$userid),(gid,$group),(homedir,$homedir))"

        if ! grep -qE "^$user:" /etc/shadow ; then
            useradd -m $USROPTS $SYSOPTS \
                -c "$fullname" \
                -d $homedir \
                -G $others \
                -p "$crypted" \
                -s /bin/bash $user 2> $TMP/useradd.$user
        else
            usermod $USROPTS \
                -c "$fullname" \
                -d $homedir \
                -G $others \
                -p "$crypted" \
                -s /bin/bash $user 2> $TMP/useradd.$user
        fi
    done < $TMP/selected-users

    chown root.shadow /etc/shadow
    chmod 0644 /etc/passwd /etc/group
    chmod 0640 /etc/shadow

    return 0
}

check_file_permissions()
{
#    chmod a+rx,u+w,a-s /usr/bin/dbus-daemon
#    chmod u+rwsx,g+rx,o-rwx /usr/libexec/dbus-daemon-launch-helper
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

#    echo "#!/bin/bash" 1> /etc/rc.d/rc.keymap
#    echo "# Maps are in /usr/share/kbd/keymaps/" >> /etc/rc.d/rc.keymap
#    echo "# Load the selected keyboard map" >> /etc/rc.d/rc.keymap
#    echo "#" >> /etc/rc.d/rc.keymap
#    echo "if [ -x /usr/bin/loadkeys ]; then" >> /etc/rc.d/rc.keymap
#    echo "    /usr/bin/loadkeys $mapname" >> /etc/rc.d/rc.keymap
#    echo "fi" >> /etc/rc.d/rc.keymap
#    echo "" >> /etc/rc.d/rc.keymap
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

AUTH="$(extract_value workgroup 'auth' 2> /dev/null)"
DISTRO="$(cat $TMP/selected-derivative 2> /dev/null)"

PKGTYPE="$(cat $TMP/selected-pkgtype 2> /dev/null)"
[ "$PKGTYPE" = "squashfs" ] && XORGCFG="keyboard"

TIMEZONE="$(cat $TMP/selected-timezone 2> /dev/null)"
[ -z "$TIMEZONE" ] && TIMEZONE="America/New_York"

DESKTOP="$(cat $TMP/selected-desktop 2> /dev/null)"
[ -z "$DESKTOP" ] && DESKTOP="xfce"

echo_message "L_UPDATING_LIB_DATABASE"
/sbin/ldconfig 1> /dev/null 2>&1

echo_message "L_UPDATING_SYSTEM_FILES"
update_system_files

if [ "$PKGTYPE" != "squashfs" ]; then
	echo_message "L_UPDATING_SYSTEM_SERVICES"
	/sbin/d-update-initd.sh $DISTRO openrc "$CRYPTO" services nomerge resync
fi

echo_message "L_UPDATING_SYSTEM_CLOCK"
/sbin/d-update-desktop.sh timezone $TIMEZONE LOCAL

echo_message "L_UPDATING_SYSTEM_KEYMAP"
update_keymap

echo_message "L_UPDATING_LVM_PARTITIONS"
update_lvm_partitions

echo_message "L_UPDATING_USER_ACCOUNTS"
update_user_accounts

echo_message "L_CHECKING_FILE_PERMISSIONS"
check_file_permissions

echo_message "L_UPDATING_FONT_CACHE"
/sbin/d-update-desktop.sh fonts

echo_message "L_UPDATING_MIME_DATABASE"
/sbin/d-update-desktop.sh mime

echo_message "L_UPDATING_ICON_CACHE"
/sbin/d-update-desktop.sh icons

echo_message "L_UPDATING_DESKTOP_SCHEMAS"
/sbin/d-update-desktop.sh schemas

echo_message "L_UPDATING_PANGO_SETTINGS"
/sbin/d-update-desktop.sh pango

echo_message "L_UPDATING_DESKTOP_DATABASE"
/sbin/d-update-desktop.sh desktop

echo_message "L_UPDATING_CA_CERTS"
/sbin/d-update-desktop.sh certificates

#if [ "$(brzctl selected sshd 2> /dev/null)" != "disabled" ]; then
#    echo_message "L_UPDATING_SSL_CERTS"
#    /sbin/d-update-desktop.sh ssl overwrite
#fi

if [ "$GPT_MODE" = "S-UEFI" ]; then
    echo_message "L_UPDATING_UEFI_CERTS"
    /sbin/d-update-desktop.sh uefi overwrite
fi

if [ "$PKGTYPE" != "squashfs" ]; then
	echo_message "L_UPDATING_NETWORK_CONFIG"
	/sbin/d-update-network.sh networkmanager

	echo_message "L_UPDATING_XORG_CONFIG"
	/sbin/d-update-display.sh -yes $XORGCFG

	echo_message "L_UPDATING_POLICY_RULES"
	/sbin/d-update-desktop.sh policy restart shutdown
fi

echo_message "L_UPDATING_DISPLAY_MANAGER"
/sbin/d-update-desktop.sh xdm brzdm $DESKTOP

# Removing Live and Install Edition marker file
rm -f $ROOTDIR/BRZLIVE
rm -f $ROOTDIR/BRZINSTALL

find $TMP/ -name 'selected-*' -delete 2> /dev/null
find $TMP/ -name '*.csv' -delete 2> /dev/null
find $TMP/ -name '*.map' -delete 2> /dev/null
find $TMP/ -name '*.info' -delete 2> /dev/null
find $TMP/ -name '*.log' -delete 2> /dev/null
find $TMP/ -name '*.errs' -delete 2> /dev/null
find $TMP/ -name '*.err' -delete 2> /dev/null
find $TMP/ -name '*.lst' -delete 2> /dev/null
find $TMP/ -name '*.sh' -delete 2> /dev/null

exit 0

# end Breeze::OS setup script
