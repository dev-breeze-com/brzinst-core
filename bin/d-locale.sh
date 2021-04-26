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

DERIVED="`cat $TMP/selected-derivative 2> /dev/null`"
RELEASE="`cat $TMP/selected-release 2> /dev/null`"
CODENAME="`cat $TMP/selected-codename 2> /dev/null`"

while [ 0 ]; do

dialog --colors \
	--backtitle "Breeze::OS $RELEASE Installer" \
	--title "Breeze::OS $RELEASE Setup (v0.9.0)" \
	--menu "\nSelect an option below ..." 13 60 5 \
"LOCALE" "Select your country locale" \
"TIMEZONE" "Select your timezone" \
"KEYBOARD" "Select your keyboard" \
"LAYOUT" "Select your keyboard layout" \
"KEYMAP" "Select your keyboard map"  2> $TMP/retcode

	if [ "$?" != 0 ]; then
		exit 1
	fi

	RETCODE="`cat $TMP/retcode`"

	if [ "$RETCODE" = "LOCALE" ]; then

		if [ "$CODENAME" = "kodiak.light" ]; then
			LOCALES=./dialog/locales.map.txt
		else
			LOCALES=./dialog/locales-all.map.txt
		fi

		cat << EOF > $TMP/tmpscript
		dialog --colors \\
			--backtitle "Breeze::OS $RELEASE Installer" \\
			--title "Breeze::OS Setup -- Locale Selection" \\
			--default-item "en_US" \\
			--menu "\nSelect a country locale ..." 18 60 10 \\
EOF
cat $LOCALES >> $TMP/tmpscript
echo "2> $TMP/selected-locale" >> $TMP/tmpscript 

		. $TMP/tmpscript

		if [ "$?" = 0 ]; then

			LOCALE="`cat $TMP/selected-locale`"
			COUNTRY="`echo "$LOCALE" | cut -f2 -d '_'`"
			COUNTRY="`echo "$COUNTRY" | tr '[:upper:]' '[:lower:]'`"

			echo $COUNTRY 1> $TMP/selected-country
			RETCODE="TIMEZONE"
		else
			LOCALE="en_US"
			echo "us" 1> $TMP/selected-country
			echo "en_US" 1> $TMP/selected-locale
		fi
		unlink $TMP/tmpscript
	fi

	if [ "$RETCODE" = "TIMEZONE" ]; then

		cat << EOF > $TMP/tmpscript
		dialog --colors \\
			--backtitle "Breeze::OS $RELEASE Installer" \\
			--title "Breeze::OS Setup -- Timezone Selection" \\
			--default-item "US/Eastern" \\
			--menu "\nSelect a timezone ..." 18 50 10 \\
EOF
cat ./dialog/timezone.map.txt >> $TMP/tmpscript
echo "2> $TMP/selected-timezone" >> $TMP/tmpscript 

		. $TMP/tmpscript

		if [ "$?" = 0 ]; then
			TIMEZONE="`cat $TMP/selected-timezone`"
			echo -n "$TIMEZONE" 1> /etc/timezone

			# Reset to current date ...
			/bin/date -s today
			/bin/touch /etc/timezone
			/bin/touch $TMP/selected-timezone

			dirname $TIMEZONE 1> $TMP/selected-timezone-area
			RETCODE="KEYBOARD"
		else
			unlink $TMP/selected-locale
		fi
		unlink $TMP/tmpscript
	fi

	if [ "$RETCODE" = "KEYBOARD" ]; then

		cat << EOF > $TMP/tmpscript
		dialog --colors \\
			--backtitle "Breeze::OS $RELEASE Installer" \\
			--title "Breeze::OS Setup -- Keyboard Selection" \\
			--default-item "pc105" \\
			--menu "\nSelect a keyboard ..." 18 60 10 \\
EOF
cat $BRZDIR/factory/keyboards.txt >> $TMP/tmpscript
echo "2> $TMP/selected-keyboard" >> $TMP/tmpscript

		. $TMP/tmpscript

		if [ "$?" = 0 ]; then
			RETCODE="LAYOUT"
		else
			echo "pc105" 1> $TMP/selected-keyboard
		fi
		unlink $TMP/tmpscript
	fi

	if [ "$RETCODE" = "LAYOUT" ]; then

		echo "us" 1> $TMP/selected-kbd-layout

		dialog --colors \
			--backtitle "Breeze::OS $RELEASE Installer" \
			--title "Breeze::OS Setup -- Keyboard Layout Selection" \
			--default-item "DEFAULT" \
			--menu "\nSelect a keyboard layout ..." 10 60 2 \
				"DEFAULT" "Use the default keyboard layout (us)" \
				"LOCALE" "Layout based on your country locale" 2> $TMP/retcode

		if [ "$?" != 0 ]; then
			continue
		fi

		RETCODE="`cat $TMP/retcode`"

		if [ "$RETCODE" = "LOCALE" -a "$LOCALE" != "en_US" ]; then

			layout="`grep -E -m1 "^$COUNTRY" $BRZDIR/factory/kbd-layouts.lst`"

			d-search-prompt.sh \
				"layout" "$layout" \
				"Breeze::OS Setup -- Keyboard Layout Selection"

			if [ "$?" = 0 ]; then
				echo "$COUNTRY" 1> $TMP/selected-kbd-layout
			fi
		fi
		RETCODE="KEYMAP"
	fi

	if [ "$RETCODE" = "KEYMAP" ]; then

		echo "qwerty/us" 1> $TMP/selected-keymap

		dialog --colors \
			--backtitle "Breeze::OS $RELEASE Installer" \
			--title "Breeze::OS Setup -- Keyboard Map Selection" \
			--default-item "DEFAULT" \
			--menu "\nSelect a keyboard map ..." 15 60 7 \
				"DEFAULT" "Use the default keyboard map (us)" \
				"QWERTY" "Use a QWERTY keyboard map (qwerty/us-acentos)" \
				"QWERTZ" "Use a QWERTZ keyboard map (qwertz/hu)" \
				"DVORAK" "Use a DVORAK keyboard map (dvorak/no)" \
				"COLEMAK" "Use a COLEMAK keyboard map (colemap/latin9)" \
				"OLPC" "Use an OLPC keyboard map (olpc/es)" \
				"LOCALE" "Map based on your country locale" 2> $TMP/retcode

		if [ "$?" != 0 ]; then
			continue
		fi

		RETCODE="`cat $TMP/retcode`"

		if [ "$RETCODE" != "DEFAULT" ]; then
			d-keymap.sh "$RETCODE" "$COUNTRY"
		fi

		if [ "$?" = 0 ]; then
			clear
			exit 0
		fi
	fi
done

exit 0

# end Breeze::OS setup script
