#!/bin/bash
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
# d-users User configuration <dev@tsert.com>
#

# Initialize folder paths
. d-dirpaths.sh

DISTRO="`cat $TMP/selected-distro 2> /dev/null`"
RELEASE="`cat $TMP/selected-release 2> /dev/null`"

USER=""
TEXT=""
TITLE=""
FULLNAME=""

CRYPTED=""
PASSWORD=""

USERID=1000
USERS="`cat $TMP/selected-users 2> /dev/null`"
YOURNAME="`cat $TMP/system-username 2> /dev/null`"

if [ ! -f $TMP/USERID.txt ]; then
	echo -n "1000" 1> $TMP/USERID.txt
fi

if [ ! -f $TMP/sysusers.cfg ]; then

	unlink $TMP/user-password.txt 2> /dev/null
	touch $TMP/user-password.txt

	/bin/cp -f /etc/passwd $TMP/etc_passwd
	/bin/cp -f /etc/shadow $TMP/etc_shadow
	/bin/cp -f /etc/group $TMP/etc_group
	/bin/cp -f ./install/factory/sysusers.cfg $TMP/
#	/bin/cp -f /etc/gshadow $TMP/etc_gshadow
fi

ask_password() {

	USER=$1
	PASSWORD=""
	CONFIRM=""

	while [ 0 ]; do

		dialog --colors --insecure \
			--backtitle "Breeze::OS $RELEASE Installer" \
			--title "Breeze::OS $RELEASE Setup -- Password" \
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
			CRYPTED="`t-util -C "$PASSWORD"`"
			CRYPTED="`echo -n $CRYPTED | /bin/sed 's/[\n\r\t ]*//g'`"

			if [ "$CRYPTED" = "" ]; then
				echo "$USER=$PASSWORD" >> $TMP/user-password.txt
			fi
			return 0
		fi
	done

	return 1
}

add_user() {

	USER=$1
	CRYPTED=$2
	USERID="$3"

	while [ 0 ]; do
		found="`fgrep ":$USERID:" $TMP/etc_passwd`"

		if [ "$found" = "" ]; then
			break
		fi
		USERID=$(( $USERID + 1 ))
	done

	if [ "$USER" != "root" -a "$USER" != "secadmin" ]; then

		echo "$USERID" 1> $TMP/USERID.txt
		echo "$USER:x:$USERID:100:$FULLNAME:/home/$USER:/bin/bash" >> $TMP/etc_passwd
		echo "$USER:$CRYPTED:13381:0:99999:7:::" >> $TMP/etc_shadow
		USERS="$USERS $USER"

		echo "$USERS" 1> $TMP/selected-users
	fi
	return 0
}

if [ "`cat $TMP/etc_shadow | fgrep 'root:' | cut -f 2 -d :`" = "" ]; then

dialog --colors --clear \
	--backtitle "Breeze::OS $RELEASE Installer" \
	--title "WARNING: NO SYSADMIN PASSWORD DETECTED" \
	--yesno "\nThere is currently no password set for the system administrator \
account [ \Z4\Zbroot\Zn ]. It is recommended that you set one \Z1now\Zn; so \
that it is active, the first time the machine is rebooted.\n\n\
Would you like to set the password for \Z4\Zbroot\Zn ?" 10 68 2> /dev/null

	if [ "$?" = 0 ]; then
		ask_password root

		if [ "$?" = 0 ]; then
			fgrep -v "root" $TMP/etc_shadow 1> $TMP/shadow
			echo "root:$CRYPTED:13381:0:99999:7:::" >> $TMP/shadow
			mv -f $TMP/shadow $TMP/etc_shadow
		fi
	fi
fi

if [ "`cat $TMP/etc_shadow | fgrep 'secadmin:' | cut -f 2 -d :`" = "" ]; then

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

		if [ "$?" != 0 ]; then
			fgrep -v "secadmin" $TMP/etc_shadow 1> $TMP/shadow
			echo "secadmin:$CRYPTED:13381:0:99999:7:::" >> $TMP/shadow
			mv -f $TMP/shadow $TMP/etc_shadow
		fi
	fi
fi

if [ "$YOURNAME" != "" ]; then
	if [ "`fgrep "$YOURNAME:" $TMP/etc_passwd`" != "" ]; then
		exit 0
	fi
fi

TEXT_1="\nYou should, at least, add your \Z1own\Zn username."
TEXT_2="Do you wish to \Z1add a user\Zn ?"
TEXT_3="Do you wish to \Z1add another user\Zn ?"

while [ 0 ]; do

	count=1
	USER=""
	TITLE=""
	FULLNAME=""

	dialog --colors --clear --defaultno \
		--backtitle "Breeze::OS $RELEASE Installer" \
		--title "Breeze::OS $RELEASE Setup -- Adding a User" \
		--yesno "$TEXT_1\n$TEXT_2" 7 55 2> /dev/null

	if [ "$?" != 0 ]; then
		clear
		exit 0
	fi

	TEXT_1=""
	TEXT_2=$TEXT_3

	dialog --colors --ok-label "Submit" \
		--backtitle "Breeze::OS $RELEASE Installer" \
		--title "Breeze::OS $RELEASE Setup -- Users" \
		--form "\nEnter the required information below ...\n" 11 60 3 \
			"Username: " 1 1 "$USER" 1 15 50 0 \
			"Full-Name: " 2 1 "$FULLNAME" 2 15 50 0 \
			"Title: " 3 1 "$TITLE" 3 15 50 0 2> $TMP/fields.txt

	if [ "$?" != 0 ]; then
		clear
		exit 1
	fi

	while read f; do
		case $count in
			1) USER="$f" ;;
			2) FULLNAME="$f" ;;
			3) TITLE="$f" ;;
			*) ;;
		esac
		count=$(( $count + 1 ))
	done < $TMP/fields.txt

	if [ "$USER" = "" -o "$FULLNAME" = "" -o "$TITLE" = "" ]; then
		dialog --colors \
			--backtitle "Breeze::OS $RELEASE Installer" \
			--title "Error: Missing Fields" \
			--msgbox "\nYou \Z1must enter\Zn all fields !\n" 7 60 2> /dev/null
		continue
	fi

	found="`grep "$USER:" $TMP/etc_shadow`"

	if [ "$found" = "" ]; then

		ask_password $USER

		if [ "$?" != 0 ]; then
			exit 1
		fi

		add_user $USER $CRYPTED $USERID

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

