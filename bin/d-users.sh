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
# d-users User configuration <dev@tsert.com>
#

# Initialize folder paths
. d-dirpaths.sh

DERIVED="`cat $TMP/selected-derivative 2> /dev/null`"
RELEASE="`cat $TMP/selected-release 2> /dev/null`"

USER=""
TEXT=""
TITLE=""
CRYPTED=""
PASSWORD=""
YOURNAME=""

USERID=1001
USERS="`cat $TMP/selected-users 2> /dev/null`"

if [ ! -f $TMP/USERID.txt ]; then
	echo -n "1001" 1> $TMP/USERID.txt
fi

if [ ! -f $TMP/sysusers.cfg ]; then
	/bin/cp -f $BRZDIR/factory/sysusers.cfg $TMP/
	/bin/cp -f $BRZDIR/factory/passwd $TMP/etc_passwd
	/bin/cp -f $BRZDIR/factory/gshadow $TMP/etc_gshadow
	/bin/cp -f $BRZDIR/factory/shadow $TMP/etc_shadow
	/bin/cp -f $BRZDIR/factory/group $TMP/etc_group
fi

ask_password() {

	USER=$1
	PASSWORD=""
	CONFIRM=""

	while [ 0 ]; do

		dialog --colors --clear --insecure \
			--backtitle "Breeze::OS $RELEASE Installer" \
			--title "Breeze::OS $RELEASE Setup -- Password" \
			--passwordform "\nEnter your password below ...\n" 10 50 2 \
				"Password: " 1 1 "$PASSWORD" 1 10 50 0 \
				"Confirm:  " 2 1 "" 2 10 50 0 2> $TMP/password.txt

		if [ "$?" != 0 ]; then
			break
		fi

		count=1

		while read f; do
			case $count in
				1) PASSWORD=$f ;;
				2) CONFIRM=$f ;;
				*) ;;
			esac
			count=$(( $count + 1 ))
		done < $TMP/password.txt

		if [ "$PASSWORD" = "" -o "$PASSWORD" != "$CONFIRM" ]; then

			dialog --colors --clear \
				--backtitle "Breeze::OS $RELEASE Installer" \
				--title "Error: Incorrect Password" \
				--msgbox "\nYou did not \Z1confirm\Zn your password !" 7 45 2> /dev/null
		else
			CRYPTED="`t-util -c "$PASSWORD"`"
			CRYPTED="`echo -n $CRYPTED | /bin/sed 's/[\n\r\t ]*//g'`"

			if [ "$CRYPTED" != "" ]; then
				return 0
			fi
		fi
	done

	return 1
}

add_user() {

	USER=$1
	CRYPTED=$2
	USERID="`cat $TMP/USERID.txt 2> /dev/null`"

	while [ 0 ]; do
		found="`grep -E "[:]$USERID[:]" $TMP/etc_passwd`"

		if [ "$found" = "" ]; then
			break
		fi
		USERID=$(( $USERID + 1 ))
	done

	if [ "$USER" != "root" -a "$USER" != "secadmin" ]; then
		echo "[$USER]" >> $TMP/sysusers.cfg
		echo "user-id=$USER" >> $TMP/sysusers.cfg
		echo "group-id=users" >> $TMP/sysusers.cfg
		echo "full-name=$NAME" >> $TMP/sysusers.cfg
		echo "title=$TITLE" >> $TMP/sysusers.cfg
		echo "street-address=$STRRET" >> $TMP/sysusers.cfg
		echo "city=$CITY" >> $TMP/sysusers.cfg
		echo "prov-state=$PROV_STATE" >> $TMP/sysusers.cfg
		echo "country=$COUNTRY" >> $TMP/sysusers.cfg
		echo "postal-code=$POSTAL_CODE" >> $TMP/sysusers.cfg
		echo "email-address=$EMAIL" >> $TMP/sysusers.cfg
		echo "url=$URL" >> $TMP/sysusers.cfg
		echo "work-phone=$WORK_PHONE" >> $TMP/sysusers.cfg
		echo "home-phone=$HOME_PHONE" >> $TMP/sysusers.cfg
		echo "photo=personal" >> $TMP/sysusers.cfg
		echo "comments=$COMMENTS" >> $TMP/sysusers.cfg
		echo "[/$USER]" >> $TMP/sysusers.cfg
		echo "" >> $TMP/sysusers.cfg

		/bin/sed -i "s/city=$/city=$CITY/g" $TMP/sysusers.cfg
		/bin/sed -i "s/country=$/country=$COUNTRY/g" $TMP/sysusers.cfg
		/bin/sed -i "s/prov\-state=$/prov-state=$PROV_STATE/g" $TMP/sysusers.cfg
		/bin/sed -i "s/postal\-code=$/postal-code=$POSTAL_CODE/g" $TMP/sysusers.cfg
		/bin/sed -i "s/street\-address=$/street-address=$STREET/g" $TMP/sysusers.cfg

		echo "$USERID" 1> $TMP/USERID.txt
		echo "$USER:x:$USERID:100:$TITLE:/home/$USER:/bin/bash" >> $TMP/etc_passwd
		echo "$USER:$CRYPTED:13381:0:99999:7:::" >> $TMP/etc_shadow
		USERS="$USERS $USER"
		echo "$USERS" 1> $TMP/selected-users
	fi
	return 0
}

if [ "`cat $TMP/etc_shadow | grep 'root:' | cut -f 2 -d :`" = "" ]; then

dialog --colors --clear \
	--backtitle "Breeze::OS $RELEASE Installer" \
	--title "WARNING: NO ROOT PASSWORD DETECTED" \
	--yesno "\nThere is currently no password set for the system administrator \
account [ \Z4\Zbroot\Zn ]. It is recommended that you set one \Z1now\Zn; so \
that it is active, the first time the machine is rebooted.\n\n\
Would you like to set the password for \Z4\Zbroot\Zn ?" 10 68 2> /dev/null

	if [ "$?" = 0 ]; then
		ask_password root

		if [ "$?" = 0 ]; then
			echo "root:$CRYPTED:13381:0:99999:7:::" >> $TMP/etc_shadow
		fi
	fi
fi

if [ "`cat $TMP/etc_shadow | grep 'secadmin:' | cut -f 2 -d :`" = "" ]; then

dialog --colors --clear \
	--backtitle "Breeze::OS $RELEASE Installer" \
	--title "WARNING: NO TSERT PASSWORD DETECTED" \
	--default-item "keep" \
	--menu "\nThe security manager's account [ \Z4\Zbsecadmin\Zn ] was added.\nYou \Zb\Z4must\Zn set a password for it \Z1now\Zn; so that it is active,\nthe first time the machine is rebooted.\n\nSelect a password option !" 14 65 2 \
		"keep" "Re-use 'root' password for Security Manager" \
		"create" "Create a new password for Security Manager"  2> $TMP/retcode

	RETCODE="`cat $TMP/retcode`"

	if [ "$RETCODE" = "keep" ]; then
		echo "secadmin:$CRYPTED:13381:0:99999:7:::" >> $TMP/etc_shadow

	elif [ "$RETCODE" = "create" ]; then
		ask_password secadmin

		if [ "$?" = 0 ]; then
			echo "secadmin:$CRYPTED:13381:0:99999:7:::" >> $TMP/etc_shadow
		fi
	fi
fi

TEXT_1="\nYou should, at least, add your \Z1own\Zn username."
TEXT_2="Do you wish to \Z1add a user\Zn ?"
TEXT_3="Do you wish to \Z1add another user\Zn ?"

while [ 0 ]; do

	count=1
	USER=""
	TITLE=""

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
		--form "\nEnter the required information below ...\n" 19 60 11 \
			"Username: " 1 1 "$USER" 1 15 50 0 \
			"Full-Name: " 2 1 "$NAME" 2 15 50 0 \
			"Title: " 3 1 "$TITLE" 3 15 50 0 \
			"Street: " 4 1 "$STREET" 4 15 50 0 \
			"City: " 5 1 "$CITY" 5 15 50 0 \
			"Prov-State: " 6 1 "$PROV_STATE" 6 15 50 0 \
			"Country: " 7 1 "$COUNTRY" 7 15 50 0 \
			"Postal-Code: " 8 1 "$POSTAL_CODE" 8 15 50 0 \
			"Email: " 9 1 "$EMAIL" 9 15 50 0 \
			"Work-Phone: " 10 1 "$WORK_PHONE" 10 15 50 0 \
			"Home-Phone: " 11 1 "$HOME_PHONE" 11 15 50 0 2> $TMP/fields.txt

	if [ "$?" != 0 ]; then
		clear
		exit 1
	fi

	while read f; do
		case $count in
			1) USER=$f ;;
			2) NAME=$f ;;
			3) TITLE=$f ;;
			4) STREET=$f ;;
			5) CITY=$f ;;
			6) PROV_STATE=$f ;;
			7) COUNTRY=$f ;;
			8) POSTAL_CODE=$f ;;
			9) EMAIL=$f ;;
			10) WORK_PHONE=$f ;;
			11) HOME_PHONE=$f ;;
			*) ;;
		esac
		count=$(( $count + 1 ))
	done < $TMP/fields.txt

	found=$(grep "$USER:" $TMP/etc_shadow)

	if [ "$found" = "" ]; then

		ask_password $USER

		if [ "$?" = 0 ]; then
			add_user $USER $CRYPTED

			if [ "$YOURNAME" = "" ]; then
				YOURNAME="$USER"
				echo $USER 1> $TMP/system-username
			fi
		else
			clear
			exit 1
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

