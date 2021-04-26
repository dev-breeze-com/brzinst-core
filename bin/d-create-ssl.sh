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
# Secure socket Layer (SSL) key installation <dev@tsert.com>
#

# Initialize folder paths
. d-dirpaths.sh

DERIVED="`cat $TMP/selected-derivative 2> /dev/null`"
RELEASE="`cat $TMP/selected-release 2> /dev/null`"

if [ ! -e "$ROOTDIR/etc/desktop/public-keys/sales.asc" ]; then
	# Copy sales encryption key to /etc/desktop/public-keys folder
	cp -f /keys/sales.asc $ROOTDIR/etc/desktop/public-keys/

	# Add sales encryption key to the 'root' keyring
	chroot $ROOTDIR /usr/bin/gpg --import /etc/desktop/public-keys/sales.asc

	# Add sales encryption key to the 'tsert' keyring
	chroot $ROOTDIR su -c "/usr/bin/gpg --import /etc/desktop/public-keys/sales.asc" tsert
fi

USERS="root tsert"

for USER in $USERS; do
	# Add sales encryption key to new users's keyring
	chroot $ROOTDIR su -c "/usr/bin/gpg --import /etc/desktop/public-keys/sales.asc" $USER
done

if [ ! -f "$ROOTDIR/etc/desktop/openssl.cnf" ]; then
	exit 1
fi

cp -f $ROOTDIR/etc/desktop/openssl.cnf \
	$ROOTDIR/etc/desktop/certificates/openssl.cnf

unlink $ROOTDIR/etc/desktop/openssl.cnf

if [ -f "$ROOTDIR/etc/desktop/certificates/tsert.pem" ]; then
	dialog --colors --clear \
			--backtitle "Breeze::OS $RELEASE Installer" \
			--title "Breeze::OS Setup -- Certificate Generation" \
		--yesno "\nOverwrite the certificate for host \Z1$FQDN\Zn ?" 7 60
else
	dialog --colors --clear \
		--backtitle "Breeze::OS $RELEASE Installer" \
		--title "Breeze::OS Setup -- Certificate Generation" \
		--yesno "\nAbout to create the certificate for host \Z1$FQDN\Zn ?" 7 60
fi

if [ $? = 0 ]; then
#	Make sure that the random number generator daemon is running ...
	chroot $ROOTDIR /etc/init.d/rng-tools restart

	sleep 1

#	Setting up Openssl certificates pem keys ...
	chroot $ROOTDIR openssl req -utf8 -batch -new -nodes -x509 \
		-config /etc/desktop/certificates/openssl.cnf \
		-out /etc/desktop/certificates/tsert.pem \
		-keyout /etc/desktop/certificates/tsert.pem

	pushd $(pwd)
	cd $ROOTDIR/etc/desktop/certificates/

	/bin/cp -f tsert.pem mail.pem
	/bin/chmod a+r tsert.pem mail.pem
	/bin/chmod a-wx tsert.pem mail.pem

	popd
fi

clear
exit 0

