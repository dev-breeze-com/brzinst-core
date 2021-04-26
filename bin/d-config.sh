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

MODE="$1"
META_FILE=
CONFIGURED=0

DERIVED="`cat $TMP/selected-derivative 2> /dev/null`"
RELEASE="`cat $TMP/selected-release 2> /dev/null`"
INTERNET="`cat $TMP/internet-enabled 2> /dev/null`"
NB_PKGS="`cat $TMP/pkg-total 2> /dev/null`"

DB_UPDATES="$ROOTDIR/tmp/db-updates"
echo "BEGIN TRANSACTION;" 1> "$DB_UPDATES"

export TERM=linux-c
#export LANGUAGE=C.UTF-8
export LC_ALL=""
export LANG="C"
export LANGUAGE=""
export LC_TYPE="UTF-8"

#export TERM=linux-c
#export LANGUAGE=C.UTF-8
#export LANG=en_US
#export LC_ALL=en_US
#export LC_TYPE=en_US

display_metadata() {

	local name="$1"
	local version="$2"
	local title="$3"
	local MEMORY="`cat /proc/meminfo | grep -F 'MemFree' | sed -r 's/.*MemFree[: ]*//g'`"

	CONFIGURED=$(( $CONFIGURED + 1 ))

	dialog --colors \
		--backtitle "Breeze::OS $RELEASE Installer" \
		--title "Breeze::OS Setup -- Configuration" \
		--infobox "\n\Z1Name\Zn    = $name\n\
\Z1title\Zn   = $title\n\
\Z1version\Zn = $version\n\
\Z1FreeMem\Zn = $MEMORY\n\
\Z1Date\Zn    = $(date)\n\n\
$CONFIGURED PACKAGES OUT OF $NB_PKGS CONFIGURED !" 12 75

	return 0
}

config_distro() {

	local line=""
	local name=""
	local version=""
	local pkgtype=""
	local title=""
	local src_path=""

	unlink $TMP/config.err 2> /dev/null
	touch $TMP/config.err

	while read pkg; do

		if [ "`echo "$pkg" | grep -E '\.tkg$'`" = "" ]; then
			continue
		fi

		line="`grep -F -m1 "$pkg" $ROOTDIR/tmp/titles.lst`"
		name="`echo "$line" | cut -f 1 -d '|'`"
		version="`echo "$line" | cut -f 2 -d '|'`"
		pkgtype="`echo "$line" | cut -f 3 -d '|'`"
		title="`echo "$line" | cut -f 4 -d '|'`"
		src_path="`echo "$line" | cut -f 5 -d '|'`"

		echo "INSTALLER: PROGRESS ((name,$name),(title,$title))"

		echo "UPDATE packages SET status='unpacked' WHERE identifier = '$name';" >> "$DB_UPDATES"

		SCRIPTS="/var/cache/packages/$name/scripts/"

		if [ "$name" = "etc" -o "$name" = "network-scripts" -o \
			"$name" = "openssl" -o "$name" = "openssl-solibs" ]; then
			echo "UPDATE packages SET status='installed' WHERE identifier = '$name';" >> "$DB_UPDATES"
			continue

		elif [ "$name" = "flashplayer" ]; then
			cp -f $ROOTDIR/$SCRIPTS/doinst.sh $ROOTDIR/sbin/d-flashplayer.sh

			if [ "$INTERNET" = "no" ]; then
				continue
			fi
		fi

		if [ -f "$ROOTDIR/$SCRIPTS/doinst.sh" ]; then

#			if [ "$MODE" = "dialog" ]; then
#				display_metadata "$name" "$version" "$title"
#			fi

			ERRLOG="$ROOTDIR/tmp/$name.doinst.err"
			cd $ROOTDIR
			/bin/sh ./$SCRIPTS/doinst.sh -install $ROOTDIR 2> $ERRLOG
			cd /
			if [ ! -s "$ERRLOG" ]; then unlink "$ERRLOG"; fi
		fi

		if [ -f "$ROOTDIR/$SCRIPTS/setup.sh" ]; then
			cd $ROOTDIR
			/bin/sh ./$SCRIPTS/setup.sh -install
			cd /
			if [ ! -s "$ERRLOG" ]; then unlink "$ERRLOG"; fi
		fi

		if [ -f "$ROOTDIR/$SCRIPTS/postinst.sh" ]; then
			ERRLOG="$ROOTDIR/tmp/$name.postinst.err"
			cd $ROOTDIR
			/bin/sh ./$SCRIPTS/postinst.sh -install $ROOTDIR 2> $ERRLOG
			cd /
			if [ ! -s "$ERRLOG" ]; then unlink "$ERRLOG"; fi
		fi

		if [ "$?" != 0 ]; then
			echo $pkg >> $TMP/config.err
			continue
		fi

		echo "UPDATE packages SET status='installed' WHERE identifier = '$name';" >> "$DB_UPDATES"

	done < "$TMP/packages.lst"

	echo "END TRANSACTION;" >> "$DB_UPDATES"

	if [ ! -s "$TMP/config.err" ]; then
		return 0
	fi

#	if [ "$MODE" = "dialog" ]; then
#		dialog --colors --clear --exit-label OK \
#			--backtitle "Breeze::OS $RELEASE Installer" \
#			--title "Breeze::OS Setup -- Configuration Failures" \
#			--textbox "$TMP/config.err" 18 70
#	fi
	return 1
}

# Main starts here ...

echo "INSTALLER: MESSAGE L_INIT_LIBRARIES"
chroot $ROOTDIR /sbin/ldconfig

echo "INSTALLER: MESSAGE L_CONFIGURING_PACKAGES"
config_distro "$TMP/packages.lst"

exit $?

# end Breeze::OS setup script
