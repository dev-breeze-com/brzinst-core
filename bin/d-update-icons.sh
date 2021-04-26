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
# Taken from slackware rc.M
#

# Update any existing icon cache files:
if find /usr/share/icons 2> /dev/null | grep -q icon-theme.cache ; then
	for theme_dir in /usr/share/icons/* ; do
		if [ -r ${theme_dir}/icon-theme.cache ]; then
			echo "Updating icon-theme.cache in ${theme_dir}..."
			/usr/bin/gtk-update-icon-cache -t -f ${theme_dir} &> /dev/null
		fi
	done

	# This would be a large file and probably shouldn't be there.
	if [ -r /usr/share/icons/icon-theme.cache ]; then
		echo "Deleting icon-theme.cache in /usr/share/icons..."
		/usr/bin/gtk-update-icon-cache -t -f /usr/share/icons &> /dev/null
		rm -f /usr/share/icons/icon-theme.cache
	fi
fi

# Update mime database:
if [ -x /usr/bin/update-mime-database -a -d /usr/share/mime ]; then
	echo "Updating MIME database: /usr/bin/update-mime-database /usr/share/mime &"
	/usr/bin/update-mime-database /usr/share/mime &> /dev/null
fi

# These GTK+/pango files need to be kept up to date for
# proper input method, pixbuf loaders, and font support.
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

# end Breeze::OS setup script
