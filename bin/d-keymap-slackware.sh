#!/bin/bash
# Modified by dev@tsert.com
# Copyright 1993, 1999, 2002 Patrick Volkerding, Moorhead, MN.
# Copyright 2009  Patrick J. Volkerding, Sebeka, MN, USA

# Initialize folder paths
. d-dirpaths.sh $DISTRO

DISTRO="`cat $TMP/selected-distro 2> /dev/null`"
RELEASE="`cat $TMP/selected-release 2> /dev/null`"
KEYMAP="`cat $TMP/selected-keymap 2> /dev/null`"
KEYMAPS="./install/factory/keymaps.tar.gz"

if [ "$KEYMAP" = "" ]; then
	KEYMAP="qwerty/us"
fi

while [ 0 ]; do

	dialog --colors --clear \
	--backtitle "Breeze::OS Kodiak.light Installer" \
	--title "Breeze::OS Kodiak.light Setup (v0.9.0)" \
	--default-item "$KEYMAP" \
	--menu "\nKeyboard maps are used to associate characters to keystrokes.\n\
They are able to remap your keystrokes to permit the use of accented \
characters, for certain locales .i.e \Z1fi-latin1\Zn.\n\n\
Select one of the following keyboard maps ..." 22 70 10 \
"azerty/azerty" "" \
"azerty/be-latin1" "" \
"azerty/fr-latin0" "" \
"azerty/fr-latin1" "" \
"azerty/fr-latin9" "" \
"azerty/fr-old" "" \
"azerty/fr-pc" "" \
"azerty/fr" "" \
"azerty/wangbe" "" \
"azerty/wangbe2" "" \
"colemak/en-latin9" "" \
"dvorak/ANSI-dvorak" "" \
"dvorak/dvorak-fr" "" \
"dvorak/dvorak-l" "" \
"dvorak/dvorak-r" "" \
"dvorak/dvorak" "" \
"dvorak/no-dvorak" "" \
"fgGIod/tr_f-latin5" "" \
"fgGIod/trf-fgGIod" "" \
"olpc/es-olpc" "" \
"olpc/pt-olpc" "" \
"qwerty/bashkir" "" \
"qwerty/bg-cp1251" "" \
"qwerty/bg-cp855" "" \
"qwerty/bg_bds-cp1251" "" \
"qwerty/bg_bds-utf8" "" \
"qwerty/bg_pho-cp1251" "" \
"qwerty/bg_pho-utf8" "" \
"qwerty/br-abnt" "" \
"qwerty/br-abnt2" "" \
"qwerty/br-latin1-abnt2" "" \
"qwerty/br-latin1-us" "" \
"qwerty/by-cp1251" "" \
"qwerty/by" "" \
"qwerty/bywin-cp1251" "" \
"qwerty/cf" "" \
"qwerty/cz-cp1250" "" \
"qwerty/cz-lat2-prog" "" \
"qwerty/cz-lat2" "" \
"qwerty/cz-qwerty" "" \
"qwerty/defkeymap" "" \
"qwerty/defkeymap_V1.0" "" \
"qwerty/dk-latin1" "" \
"qwerty/dk" "" \
"qwerty/emacs" "" \
"qwerty/emacs2" "" \
"qwerty/es-cp850" "" \
"qwerty/es" "" \
"qwerty/et-nodeadkeys" "" \
"qwerty/et" "" \
"qwerty/fi-latin1" "" \
"qwerty/fi-latin9" "" \
"qwerty/fi-old" "" \
"qwerty/fi" "" \
"qwerty/gr-pc" "" \
"qwerty/gr" "" \
"qwerty/hu101" "" \
"qwerty/il-heb" "" \
"qwerty/il-phonetic" "" \
"qwerty/il" "" \
"qwerty/is-latin1-us" "" \
"qwerty/is-latin1" "" \
"qwerty/it-ibm" "" \
"qwerty/it" "" \
"qwerty/it2" "" \
"qwerty/jp106" "" \
"qwerty/kazakh" "" \
"qwerty/ky_alt_sh-UTF-8" "" \
"qwerty/kyrgyz" "" \
"qwerty/la-latin1" "" \
"qwerty/lt.baltic" "" \
"qwerty/lt.l4" "" \
"qwerty/lt" "" \
"qwerty/mk-cp1251" "" \
"qwerty/mk-utf" "" \
"qwerty/mk" "" \
"qwerty/mk0" "" \
"qwerty/nl" "" \
"qwerty/nl2" "" \
"qwerty/no-latin1" "" \
"qwerty/no" "" \
"qwerty/pc110" "" \
"qwerty/pl" "" \
"qwerty/pl1" "" \
"qwerty/pl2" "" \
"qwerty/pl3" "" \
"qwerty/pl4" "" \
"qwerty/pt-latin1" "" \
"qwerty/pt-latin9" "" \
"qwerty/pt" "" \
"qwerty/ro" "" \
"qwerty/ro_std" "" \
"qwerty/ru-cp1251" "" \
"qwerty/ru-ms" "" \
"qwerty/ru-yawerty" "" \
"qwerty/ru" "" \
"qwerty/ru1" "" \
"qwerty/ru2" "" \
"qwerty/ru3" "" \
"qwerty/ru4" "" \
"qwerty/ru_win" "" \
"qwerty/ruwin_alt-CP1251" "" \
"qwerty/ruwin_alt-KOI8-R" "" \
"qwerty/ruwin_alt-UTF-8" "" \
"qwerty/ruwin_cplk-CP1251" "" \
"qwerty/ruwin_cplk-KOI8-R" "" \
"qwerty/ruwin_cplk-UTF-8" "" \
"qwerty/ruwin_ct_sh-CP1251" "" \
"qwerty/ruwin_ct_sh-KOI8-R" "" \
"qwerty/ruwin_ct_sh-UTF-8" "" \
"qwerty/ruwin_ctrl-CP1251" "" \
"qwerty/ruwin_ctrl-KOI8-R" "" \
"qwerty/ruwin_ctrl-UTF-8" "" \
"qwerty/se-fi-ir209" "" \
"qwerty/se-fi-lat6" "" \
"qwerty/se-ir209" "" \
"qwerty/se-lat6" "" \
"qwerty/se-latin1" "" \
"qwerty/sk-prog-qwerty" "" \
"qwerty/sk-qwerty" "" \
"qwerty/speakup-jfw" "" \
"qwerty/speakupmap" "" \
"qwerty/sr-cy" "" \
"qwerty/sv-latin1" "" \
"qwerty/tj_alt-UTF8" "" \
"qwerty/tr_q-latin5" "" \
"qwerty/tralt" "" \
"qwerty/trf" "" \
"qwerty/trq" "" \
"qwerty/ttwin_alt-UTF-8" "" \
"qwerty/ttwin_cplk-UTF-8" "" \
"qwerty/ttwin_ct_sh-UTF-8" "" \
"qwerty/ttwin_ctrl-UTF-8" "" \
"qwerty/ua-cp1251" "" \
"qwerty/ua-utf-ws" "" \
"qwerty/ua-utf" "" \
"qwerty/ua-ws" "" \
"qwerty/ua" "" \
"qwerty/uk" "" \
"qwerty/us-acentos" "" \
"qwerty/us" "" \
"qwertz/croat" "" \
"qwertz/cz-us-qwertz" "" \
"qwertz/cz" "" \
"qwertz/de-latin1-nodeadkeys" "" \
"qwertz/de-latin1" "" \
"qwertz/de-mobii" "" \
"qwertz/de" "" \
"qwertz/de_CH-latin1" "" \
"qwertz/de_alt_UTF-8" "" \
"qwertz/fr_CH-latin1" "" \
"qwertz/fr_CH" "" \
"qwertz/hu" "" \
"qwertz/sg-latin1-lk450" "" \
"qwertz/sg-latin1" "" \
"qwertz/sg" "" \
"qwertz/sk-prog-qwertz" "" \
"qwertz/sk-qwertz" "" \
"qwertz/slovene" "" \
 2> $TMP/selected-keymap

	if [ "$?" != 0 ]; then
		unlink $TMP/selected-keymap
		exit 1
	fi

	BMAP="`cat $TMP/selected-keymap`"
	BMAP="`basename $BMAP`".bmap

	echo "######### $BMAP" 1> /tmp/found

	tar -xzOf "$KEYMAPS" "$BMAP" 1> /dev/null

	if [ "$?" != 0 ]; then
		continue
	fi

	echo "#########" 1> /tmp/found

	tar -xzOf "$KEYMAPS" "$BMAP" | ./install/bin/loadkmap

	if [ "$?" != 0 ]; then
		continue
	fi

	while [ 0 ]; do
		# Match the dialog colors a little while doing the keyboard test:
		setterm -background cyan -foreground black -blank 0
		clear
		cat << EOF

    OK, the new map is now installed.  You may now test it by typing
    anything you want.  To quit testing the keyboard, enter 'y' on a
    line by itself to accept the map and go on, or 'n' on a line by
    itself to reject the current keyboard map and select a new one.

EOF
		echo -n "    "
		read answer

		answer="`echo $answer | tr '[:upper:]' '[:lower:]'`"

		if [ "$answer" = "y" -o "$answer" = "n" ]; then
			break
		fi
	done

	setterm -background default -foreground default -blank 0

	if [ "$answer" = "y" ]; then
		exit 0
	fi

	tar -xzOf "$KEYMAPS" us.bmap | ./install/bin/loadkmap
done

exit 0

