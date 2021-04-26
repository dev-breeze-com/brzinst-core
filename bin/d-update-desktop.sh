#!/bin/bash
#
# GNU GENERAL PUBLIC LICENSE Version 3
#
if [ "$EUID" -gt 0 ]; then
	echo "d-update-desktop.sh: execute only as root !"
	echo "Usage: d-update-desktop.sh [pango|desktop|icons|fonts|schemas] | <ssl|uefi> [overwrite] | xdm <slim|kde|gnome|pdm> <theme>"
	exit 1
fi

IS_ON=/bin/true

if test -f /etc/rc.d/init.d/functions; then
	. /etc/rc.d/init.d/functions
	ECHO=echo
	ECHO_OK="echo_success"
	ECHO_ERROR="echo_failure"
else
	ECHO=echo
	ECHO_OK=:
	ECHO_ERROR=:
fi

if [ "$1" = "xdm" ]; then
	if [ "$2" = "slim" -a "$3" != "" ]; then
		if [ -x /usr/bin/slim -a -e /etc/slim.conf ]; then
			sed -ir "s/^current_theme.*$/current_theme    $3/g" /etc/slim.conf

			WINMGR="$(extract_value 'desktop' xorg)"
			WINMGRS="$WINMGR,xfce,kde,gnome,blackbox,openbox,fluxbox"

			if [ -f "/etc/X11/xinit/xinitrc.$WINMGR" ]; then
				sed -ir "s/^sessions.*$/sessions    $WINMGRS/g" /etc/slim.conf
			fi
		fi
	elif [ "$2" = "pdm" -a "$3" != "" ]; then
		mkdir -p /etc/config/xdm/

		if [ -x /usr/sbin/pdm -a -e /etc/config/apps/pdm.cfg ]; then
			sed -ri "s/^theme.*$/theme=$3/g" /etc/config/apps/pdm.cfg
		fi
	else
		echo "Usage: d-update-desktop.sh xdm %xdm %theme"
		exit 1
	fi
elif [ "$1" = "certificates" ]; then
	if [ -x /usr/sbin/update-ca-certificates ]; then
		/usr/sbin/update-ca-certificates --fresh 1> /dev/null 2>&1
	fi
elif [ "$1" = "schemas" ]; then
	if [ -x /usr/bin/glib-compile-schemas ]; then
		glib-compile-schemas /usr/share/glib-2.0/schemas
	fi
elif [ "$1" = "mime" ]; then
	# Update mime database ...
	if [ -x /usr/bin/update-mime-database -a -d /usr/share/mime ]; then
		echo "Updating MIME database ..."
		/usr/bin/update-mime-database /usr/share/mime 1> /dev/null 2>&1
	fi
elif [ "$1" = "desktop" ]; then
	if [ -x /usr/bin/update-desktop-database ]; then
		/usr/bin/update-desktop-database \
			/usr/share/applications 1> /dev/null 2>&1
		/usr/bin/update-desktop-database -q 1> /dev/null 2>&1
	fi
elif [ "$1" = "fonts" ]; then
	if [ -x /usr/bin/fc-cache ]; then
		for fontdir in 100dpi 75dpi OTF Speedo TTF Type1 cyrillic misc ; do
			if [ -d /usr/share/fonts/$fontdir ]; then
				mkfontscale /usr/share/fonts/$fontdir 1> /dev/null 2>&1
				mkfontdir /usr/share/fonts/$fontdir 1> /dev/null 2>&1

				if [ "$fontdir" = "misc" ]; then
					mkfontdir \
						-e /usr/share/fonts/encodings \
						-e /usr/share/fonts/encodings/large 1> /dev/null 2>&1
				fi
			fi
		done
		/usr/bin/fc-cache -f 1> /dev/null 2>&1
	fi
elif [ "$1" = "icons" ]; then

	for theme in /usr/share/icons/* ; do
		echo "Updating icon-theme.cache in ${theme}..."
		/usr/bin/gtk-update-icon-cache -t -f ${theme} 1> /dev/null
		xdg-icon-resource forceupdate --theme ${theme} 1> /dev/null

		if [ -d "${theme}/scalable" ]; then
			/usr/bin/gtk-update-icon-cache -t -f ${theme}/scalable 1> /dev/null
			xdg-icon-resource forceupdate --theme ${theme}/scalable 1> /dev/null
		fi
	done

	# This would be a large file and probably shouldn't be there.
	if [ -r /usr/share/icons/icon-theme.cache ]; then
		#/usr/bin/gtk-update-icon-cache -t -f /usr/share/icons 1> /dev/null 2>&1
		echo "Deleting icon-theme.cache in /usr/share/icons..."
		rm -f /usr/share/icons/icon-theme.cache
	fi

	/usr/bin/gdk-pixbuf-query-loaders --update-cache

elif [ "$1" = "pango" ]; then

	# These GTK+/pango files need to be kept up to date for
	# proper input method, pixbuf loaders, and font support.
	#
	if [ -e /var/lib/update-gtk ]; then
		if [ -x /usr/bin/update-gtk-immodules ]; then
			/usr/bin/update-gtk-immodules --verbose
		fi
		if [ -x /usr/bin/update-gdk-pixbuf-loaders ]; then
			/usr/bin/update-gdk-pixbuf-loaders --verbose
		fi
		if [ -x /usr/bin/update-pango-querymodules ]; then
			/usr/bin/update-pango-querymodules --verbose
		fi
	fi

	if [ -e /usr/bin/pango-querymodules ]; then
		if egrep -q '^ARCHITECTURE=i486' /etc/os-release ; then
			PANGO_MODULES=/etc/pango/i486-slackware-linux/pango.modules
		else
			PANGO_MODULES=/etc/pango/x86_64-slackware-linux/pango.modules
		fi
		/usr/bin/pango-querymodules 1> $PANGO_MODULES
	fi
elif [ "$1" = "ssl" ]; then

	mkdir -p /etc/config/ssl/

	GPG="$(which gpg 2> /dev/null)"

	CRTFILE="/etc/config/ssl/secadmin.pem"

	# Add sales encryption key to the 'root' keyring
	$GPG --import /etc/config/crypt/keys/sales.asc

	# Add sales encryption key to the 'secadmin' keyring
	su -c "$GPG --import /etc/config/crypt/keys/sales.asc" secadmin

	if [ "$2" = "overwrite" -o ! -e $CRTFILE ]; then

		if [ -f /etc/openssl/openssl.cnf ]; then
			openssl req -utf8 -batch -new -nodes -x509 \
				-config /etc/openssl/openssl.cnf \
				-out $CRTFILE -keyout $CRTFILE
		else
			openssl req -utf8 -batch -new -nodes -x509 \
				-out $CRTFILE -keyout $CRTFILE
		fi

		cd /etc/config/ssl/

		cp -f secadmin.pem mail.pem
		chmod a+r secadmin.pem mail.pem
		chmod a-wx secadmin.pem mail.pem
	fi
elif [ "$1" = "uefi" ]; then

	mkdir -p /etc/config/uefi/keys/

	HOST="$(hostname -s)"

	KEYFILE=/etc/config/uefi/keys/${HOST}.key
	CRTFILE=/etc/config/uefi/keys/${HOST}.crt
	CERFILE=/etc/config/uefi/keys/${HOST}.cer

	if [ "$2" = "overwrite" -o ! -e $CRTFILE ]; then

		if [ -s /etc/config/uefi/uefi.cnf ]; then
			openssl req -new -x509 -newkey rsa:2048 \
				-config /etc/config/uefi/uefi.cnf \
				-keyout $KEYFILE -out $CRTFILE \
				-nodes -days 3650 #-subj "/CN=My UEFI Keys/"
		else
			openssl req -new -x509 -newkey rsa:2048 \
				-keyout $KEYFILE -out $CRTFILE \
				-nodes -days 3650 -subj "/CN=My UEFI Keys/"
		fi
		openssl x509 -in $CRTFILE -out $CERFILE -outform DER
	fi
fi

exit 0

# end Breeze::OS setup script
