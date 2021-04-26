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

USER="$1"
QUIET="$2"

GROUPID="100"
ACCOUNT="users-$USER"
HOMEDIR="/home/$USER"
CREATE_ROOT=false

touch $TMP/selected-users 2> /dev/null

if [ -z "$USER" ]; then
    if grep -qE '^username' $TMP/users.map ; then
        USER="$(grep -qE '^username' $TMP/users.map | cut -f2 -d'=')"
    fi
fi

if [ -f $TMP/users.map ]; then
    cp -af $TMP/users.map $TMP/users-${USER}.map
elif [ ! -f $TMP/users-${USER}.map ]; then
    if [ -f $BRZDIR/data/users-${USER}.map ]; then
        cp -af $BRZDIR/data/users-${USER}.map $TMP/
    fi
fi

unlink $TMP/users.map 2> /dev/null

if [ -f $TMP/users-${USER}.map ]; then
    USERNAME="$(extract_value "$ACCOUNT" 'username')"
    FULLNAME="$(extract_value "$ACCOUNT" 'fullname')"
    EMAIL="$(extract_value "$ACCOUNT" 'email-address')"
    TITLE="$(extract_value "$ACCOUNT" 'job-title')"
    PHONE="$(extract_value "$ACCOUNT" 'work-phone')"
    COMMENTS="$(extract_value "$ACCOUNT" 'comments')"
    PASSWORD="$(extract_value "$ACCOUNT" 'password')"
    CONFIRM="$(extract_value "$ACCOUNT" 'confirm')"
    CRYPTED="$(extract_value "$ACCOUNT" 'crypted')"
fi

[ -z "$USERNAME" ] && USERNAME="$USER"

USERID="$(cat $TMP/current.uid 2> /dev/null)"
#DERIVED="$(cat $TMP/selected-derivative 2> /dev/null)"

if [ "$USER" = "root" ]; then
    USERID="0"
    GROUPID="0"
    HOMEDIR="/root"
elif [ "$USER" = "secadmin" ]; then
    HOMEDIR="/home/secadmin"
    USERID="999"
    GROUPID="100"
elif [ -z "$USERID" ]; then
    USERID="1000"
    GROUPID="100"
fi

#CRYPTED="$(t-util -c "$PASSWORD" 2> /dev/null)"
if [ "$USER" = "root" -o "$USER" = "secadmin" ]; then
    CRYPTED="$(echo -n $CRYPTED | sed 's/[\n\r\t ]*//g')"
fi

if [ "$USER" = "root" -o "$USER" = "secadmin" ]; then
    if ! grep -qE '^root:' $TMP/selected-users ; then
        CREATE_ROOT=true
    fi
elif [ ! -e $TMP/selected-user ]; then
    echo "$USERNAME" 1> $TMP/selected-user
    echo "$USERNAME" 1> $TMP/selected-username
    echo "yes" 1> $TMP/user-defined
fi

#echo "$USERNAME:$PASSWORD" >> $TMP/user-password.lst

if [ ! -f $TMP/selected-users -o ! -s $TMP/selected-users ]; then
    touch $TMP/selected-users
    echo "$USERNAME:$USERID:$GROUPID:$FULLNAME:$HOMEDIR:$CRYPTED:$EMAIL:$PHONE:$TITLE:$COMMENTS" >> $TMP/selected-users

elif ! grep -qE "^${USER}:" $TMP/selected-users ; then
    echo "$USERNAME:$USERID:$GROUPID:$FULLNAME:$HOMEDIR:$CRYPTED:$EMAIL:$PHONE:$TITLE:$COMMENTS" >> $TMP/selected-users
else
    touch $TMP/selected-users.tmp

    while read line; do
        user="$(echo "$line" | cut -f1 -d ':')"
        uid="$(echo "$line" | cut -f2 -d ':')"

        if [ "$user" = "$USER" ]; then
            echo "$USERNAME:$uid:$GROUPID:$FULLNAME:$HOMEDIR:$CRYPTED:$EMAIL:$PHONE:$TITLE:$COMMENTS" >> $TMP/selected-users.tmp
        else
            echo "$line" >> $TMP/selected-users.tmp
        fi
    done < "$TMP/selected-users"

    mv $TMP/selected-users.tmp $TMP/selected-users
fi

if [ "$USER" = "root" ]; then
    if ! grep -qE "^secadmin:" $TMP/selected-users ; then
        echo "yes" 1> $TMP/selected-secadmin
        echo "L_ACTIVE" 1> $TMP/secadmin-activated
        echo "secadmin:999:999:Security Manager:/home/secadmin:$CRYPTED:$EMAIL:$PHONE:$TITLE:$COMMENTS" >> $TMP/selected-users
    fi
fi

if [ "$USERID" != "0" -a "$USERID" != "999" ]; then
    USERID=$(( $USERID + 1 ))
    echo "$USERID" 1> "$TMP/current.uid"
fi

if ! grep -qF "$USER" $TMP/users.lst ; then
    echo "$USER" >> $TMP/users.lst
fi

if [ "$USER" = "root" ]; then

    USERMAP="$BRZDIR/data/secadmin.map"
    password="$(grep -F 'password=' $USERMAP | cut -f2 -d'=')"

    if [ -z "$password" ]; then
        sed -i "s/^password=/password=$PASSWORD/g" $USERMAP
    fi
fi

#if [ ! -e $TMP/adduser.map ]; then
#    echo "homedir-permission=true" 1> $TMP/adduser.map
#    echo "groups=cdrom,disk,floppy,dialout,audio,video,scanner,plugdev,netdev,power,wheel,powerdev,bluetooth" >> $TMP/adduser.map
#    echo "list=$(cat $TMP/users.lst)" >> $TMP/adduser.map
#fi

if [ "$USER" = "root" ]; then
    echo "yes" 1> $TMP/selected-sysadmin
    echo "L_ACTIVE" 1> $TMP/sysadmin-activated

    if [ -z "$QUIET" ]; then
        echo_success "L_SYSADMIN_PASSWORD_SAVED"
    fi

elif [ "$USER" = "secadmin" ]; then
    echo "yes" 1> $TMP/selected-secadmin
    echo "L_ACTIVE" 1> $TMP/secadmin-activated

    if [ -z "$QUIET" ]; then
        echo_success "L_SECADMIN_PASSWORD_SAVED"
    fi
elif [ -z "$QUIET" ]; then
    echo_success "L_USER_PASSWORD_SAVED"
fi

exit 0

# end Breeze::OS setup script
