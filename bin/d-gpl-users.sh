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

DERIVED="`cat $TMP/selected-derivative 2> /dev/null`"
RELEASE="`cat $TMP/selected-release 2> /dev/null`"

USER=""
TEXT=""
FULLNAME=""

CRYPTED=""
PASSWORD=""
USERID="1000"

USERS="`cat $TMP/selected-users 2> /dev/null`"
YOURNAME="`cat $TMP/system-username 2> /dev/null`"

if [ ! -f $TMP/USERID.txt ]; then
	echo -n "1000" 1> $TMP/USERID.txt
fi

if [ ! -f $TMP/sysusers.cfg ]; then

	unlink $TMP/selected-users 2> /dev/null
	touch $TMP/selected-users

	unlink $TMP/password-errors.txt 2> /dev/null
	touch $TMP/password-errors.txt

	/bin/cp -f /etc/passwd $TMP/etc_passwd
	/bin/cp -f /etc/shadow $TMP/etc_shadow
	/bin/cp -f /etc/group $TMP/etc_group

	/bin/cp -f $BRZDIR/factory/sysusers.cfg $TMP/
#	/bin/cp -f /etc/gshadow $TMP/etc_gshadow
fi

ask_password() {

	USER=$1
	PASSWORD=""
	CONFIRM=""

	while [ 0 ]; do

		dialog --colors --insecure \
			--backtitle "Breeze::OS $RELEASE Installer" \
			--title "Breeze::OS Password Setup -- User \Z1$USER\Zn " \
			--passwordform "\nEnter your password below ...\n" 10 55 2 \
				"Password: " 1 1 "$PASSWORD" 1 10 55 0 \
				"Confirm:  " 2 1 "" 2 10 55 0 2> $TMP/password.txt

		if [ "$?" != 0 ]; then
			return 1
		fi

		count=1

		while read f; do
			case $count in
				1) PASSWORD="$f" ;;
				2) CONFIRM="$f" ;;
				*) ;;
			esac
			count=$(( $count + 1 ))
		done < $TMP/password.txt

		if [ "$PASSWORD" = "" -o "$PASSWORD" != "$CONFIRM" ]; then

			dialog --colors --clear \
				--backtitle "Breeze::OS $RELEASE Installer" \
				--title "Error: Incorrect Password" \
				--msgbox "\nYou did not \Z1confirm\Zn your password !" 7 55 2> /dev/null
		else
			CRYPTED="`t-util -c "$PASSWORD"`"
			CRYPTED="`echo -n $CRYPTED | /bin/sed 's/[\n\r\t ]*//g'`"

			if [ "$CRYPTED" = "" ]; then
				echo -e "$USER\t$PASSWORD" >> $TMP/password-errors.txt
			fi
			return 0
		fi
	done

	return 1
}

add_user() {

	local user="$1"
	local userid="$2"
	local crypted="$3"
	local fullname="$4"

	while [ 0 ]; do
		found="`grep -F ":$userid:" $TMP/selected-users`"

		if [ "$found" = "" ]; then
			break
		fi
		userid=$(( $userid + 1 ))
	done

	echo "$userid" 1> $TMP/USERID.txt
	echo "$user:$userid::$fullname:/home/$user:$crypted" >> $TMP/selected-users

	return 0
}

if [ "`cat $TMP/selected-users | grep -F 'root:' | cut -f4 -d ':'`" = "" ]; then

dialog --colors --clear \
	--backtitle "Breeze::OS $RELEASE Installer" \
	--title "WARNING: NO SYSADMIN PASSWORD DETECTED" \
	--yesno "\nThere is currently no password set for the system administrator \
account [ \Z4\Zbroot\Zn ]. It is recommended that you set one \Z1now\Zn; so \
that it is active, the first time the machine is rebooted.\n\n\
Would you like to set the password for \Z4\Zbroot\Zn ?" 10 68 2> /dev/null

	if [ "$?" = 0 ]; then
		ask_password root
		echo "root:0:0:System Manager:/root:$CRYPTED" >> $TMP/selected-users
	fi
fi

if [ "`cat $TMP/selected-users | grep -F 'secadmin:' | cut -f4 -d ':'`" = "" ]; then

dialog --colors --clear \
	--backtitle "Breeze::OS $RELEASE Installer" \
	--title "WARNING: NO SECADMIN PASSWORD DETECTED" \
	--default-item "keep" \
	--menu "\nThe security manager's account [ \Z4\Zbsecadmin\Zn ] was added.\nYou \Zb\Z4must\Zn set a password for it \Z1now\Zn; so that it is active,\nthe first time the machine is rebooted.\n\nSelect a password option !" 14 65 2 \
		"keep" "Re-use 'root' password for Security Manager" \
		"create" "Create a new password for Security Manager"  2> $TMP/retcode

	if [ "$?" = 0 ]; then
		RETCODE="`cat $TMP/retcode`"
		if [ "$RETCODE" = "create" ]; then
			ask_password secadmin
		fi
		echo "secadmin:999:100:Security Manager:/home/secadmin:$CRYPTED" >> $TMP/selected-users
	fi
fi

if [ "$YOURNAME" != "" ]; then
	if [ "`grep -F "$YOURNAME:" $TMP/selected-users`" != "" ]; then
		exit 0
	fi
fi

TEXT_1="\nYou should, at least, add your \Z1own\Zn username."
TEXT_2="Do you wish to \Z1add a user\Zn ?"
TEXT_3="Do you wish to \Z1add another user\Zn ?"

while [ 0 ]; do

	USER=""
	FULLNAME=""

	dialog --colors --clear --defaultno \
		--backtitle "Breeze::OS $RELEASE Installer" \
		--title "Breeze::OS User Setup -- Adding a User" \
		--yesno "$TEXT_1\n$TEXT_2" 7 55 2> /dev/null

	if [ "$?" != 0 ]; then
		exit 0
	fi

	TEXT_1=""
	TEXT_2="$TEXT_3"

	dialog --colors \
		--backtitle "Breeze::OS $RELEASE Installer" \
		--title "Breeze::OS User Setup -- Enter your Full Name" \
		--inputbox "\n" 7 55 \
		"$FULLNAME" 2> $TMP/selected-fullname

	if [ "$?" != 0 ]; then
		exit 1
	fi

	FULLNAME="`cat $TMP/selected-fullname`"
	USER="`echo "$FULLNAME" | cut -f1 -d ' '`"
	USER="`echo "$USER" | tr '[:upper:]' '[:lower:]'`"

	dialog --colors \
		--backtitle "Breeze::OS $RELEASE Installer" \
		--title "Breeze::OS User Setup -- Enter your User Name" \
		--inputbox "\n" 7 55 \
		"$USER" 2> $TMP/selected-username

	if [ "$?" != 0 ]; then
		exit 1
	fi

	USER="`cat $TMP/selected-username`"

	found="`grep -F "$USER:" $TMP/selected-users`"

	if [ "$found" = "" ]; then

		ask_password $USER

		if [ "$?" != 0 ]; then
			exit 1
		fi

		if [ "$USER" != "root" -a "$USER" != "secadmin" ]; then
			add_user "$USER" "$USERID" "$CRYPTED" "$FULLNAME"
		fi

		if [ "$YOURNAME" = "" ]; then
			YOURNAME="$USER"
			echo "$USER" 1> $TMP/system-username
		fi
	else
		dialog --colors --clear \
			--backtitle "Breeze::OS $RELEASE Installer" \
			--title "Error: specified \Z1userame\Zn is already in use !" \
			--msgbox "\nUser \Z1$USER\Zn already exists !" 7 55 2> /dev/null
	fi
done

exit 0

# end Breeze::OS setup script

