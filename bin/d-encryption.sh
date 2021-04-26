#!/bin/bash
#
# d-encryption public key installation <dev@tsert.com>
# d-encryption secure socket layer (SSL) key installation <dev@tsert.com>
# Copyright 2011, Pierre Innocent, Tsert Inc. All Rights Reserved
#
TMP=/var/tmp
ROOTDIR=/mnt/root
MOUNTPOINT=/var/mnt

if [ ! -d "$ROOTDIR/etc/desktop/public-keys" ]; then
	mkdir -p $ROOTDIR/etc/desktop/public-keys
fi

if [ ! -d "$ROOTDIR/etc/desktop/certificates" ]; then
	mkdir -p $ROOTDIR/etc/desktop/certificates
fi

parse_fields () {
	count=1

	if [ ! -f "$TMP/openssl.log" ]; then
		return 1
	fi

	fields=$(cat $TMP/openssl.log)
	fields=$(echo $fields | sed -e 's/[\n ]/ , /g')

	for f in fields; do
		case $count in
			1) COUNTRY=$f ;;
			2) STATE_PROV=$f ;;
			3) CITY=$f ;;
			4) COMPANY=$f ;;
			5) DEPT=$f ;;
			6) TITLE=$f ;;
			7) EMAIL=$f ;;
		esac
		count=$(( $count + 1 ))
	done

	if [ "$1" = true ]; then
		cp /install/openssl.cnf $TMP/openssl.cnf
		sed -i "s/%countryName%/$COUNTRY/g" openssl.cnf
		sed -i "s/%stateOrProvinceName%/$STATE_PROV/g" openssl.cnf
		sed -i "s/%localityName%/$CITY/g" openssl.cnf
		sed -i "s/%organizationalName%/$COMPANY/g" openssl.cnf
		sed -i "s/%organizationalUnitName%/$DEPT/g" openssl.cnf
		sed -i "s/%commonName%/$TITLE/g" openssl.cnf
		sed -i "s/%emailAddress%/$EMAIL/g" openssl.cnf
		cp -f openssl.cnf $ROOTDIR/etc/desktop/certificates/
	fi
	return 0
}

if [ ! -e "$ROOTDIR/etc/desktop/public-keys/sales.asc" ]; then
	# Copy sales encryption key to /etc/desktop/public-keys folder
	cp -f /install/keys/sales.asc $ROOTDIR/etc/desktop/public-keys/

	# Add sales encryption key to the 'root' keyring
	chroot $ROOTDIR /usr/bin/gpg --import /etc/desktop/public-keys/sales.asc

	# Add sales encryption key to the 'tsert' keyring
	chroot $ROOTDIR su -c "/usr/bin/gpg --import /etc/desktop/public-keys/sales.asc" tsert
fi

USERS=$(cat $TMP/selected-users 2> /dev/null)

for user in $USERS; do
	# Add sales encryption key to new users's keyring
	chroot $ROOTDIR su -c "/usr/bin/gpg --import /etc/desktop/public-keys/sales.asc" $user
done

if [ $? = 0 ]; then
	parse_fields false
fi

dialog --colors --ok-label "Submit" \
  --backtitle "Breeze::OS Kodiak.light Installer" \
  --title "Breeze::OS Kodiak.light -- Openssl Configuration" \
  --form "\nDefault information for SSL configuration." 15 60 7 \
  "Country:"    1 1 "$COUNTRY" 1 16 45 0 \
  "State/Prov:" 2 1 "$STATE_PROV" 2 16 45 0 \
  "City:"       3 1 "$CITY" 3 16 45 0 \
  "Company:"    4 1 "$COMPANY" 4 16 45 0 \
  "Department:" 5 1 "$DEPT" 5 16 45 0 \
  "Full Name:"  6 1 "$TITLE" 6 16 45 0 \
  "Email Address:"  7 1 "$EMAIL" 7 16 45 0 2> $TMP/openssl.log

if [ $? = 0 ]; then
	parse_fields true
fi

if [ -f "$ROOTDIR/etc/desktop/certificates/tsert.pem" ]; then
	dialog --colors --clear \
			--backtitle "Breeze::OS Kodiak.light Installer" \
			--title "Breeze::OS Setup -- Certificate Generation" \
		--yesno "\nOverwrite the certificate for host \Z1$FQDN\Zn ?" 7 60
else
	dialog --colors --clear \
		--backtitle "Breeze::OS Kodiak.light Installer" \
		--title "Breeze::OS Setup -- Certificate Generation" \
		--yesno "\nAbout to create the certificate for host \Z1$FQDN\Zn ?" 7 60
fi

if [ $? = 0 ]; then
#	Make sure that the random number generator daemon is running ...
	chroot $ROOTDIR /etc/init.d/rng-tools restart

#	Setting up Openssl certificates pem keys ...
	chroot $ROOTDIR openssl req -utf8 -batch -new -nodes -x509 \
#	chroot $ROOTDIR openssl req -utf8 -batch -new -nodes -x509 \
		-config /etc/desktop/certificates/openssl.cnf \
		-out /etc/desktop/certificates/tsert.pem \
		-keyout /etc/desktop/certificates/tsert.pem

	pushd $pwd
	cd $ROOTDIR/etc/desktop/certificates/
	cp -f tsert.pem mail.pem
	chmod a+r tsert.pem mail.pem
	chmod a-wx tsert.pem mail.pem
	popd
fi

clear
exit 0

