#!/bin/bash
#
# (c) Pierre Innocent, Tsert Inc. <dev@tsert.com>
# Copyright 1996-2011, All Rights Reserved.
# See copyright file

. d-dirpaths.sh

if [ $EUID -gt 0 ]; then
    echo "====================== EXECUTE ONLY AS ROOT ========================"
    exit 1
fi

if [ "$1" = "stop" -o "$1" = "close" -o "$1" = "exit" -o "$1" = "down" ]; then
	pkill -HUP wvdial
	exit 0
fi

if [ -f /etc/resolv.conf ]; then
	cp /etc/resolv.conf /etc/resolv.conf.old

	if [ ! -f /etc/resolv.conf.bak ]; then
		cp /etc/resolv.conf /etc/resolv.conf.bak
	fi
fi

echo "nameserver x.x.x.x" >> /etc/resolv.conf

if [ -n "$2" -a -f "$2" ]; then
	cp $BRZDIR/factory/wvdial.conf /etc/wvdial.conf

	username="$(grep -iF -m1 username $2 | cut -f2 -d=)"
	password="$(grep -iF -m1 password $2 | cut -f2 -d=)"
	area_code="$(grep -iF -m1 'area-code' $2 | cut -f2 -d=)"
	phone_nb="$(grep -iF -m1 'phone-nb' $2 | cut -f2 -d=)"

	sed -i -r "s/%username%/$username/g" /etc/wvdial.conf
	sed -i -r "s/%password%/$password/g" /etc/wvdial.conf
	sed -i -r "s/%area-code%/$area_code/g" /etc/wvdial.conf
	sed -i -r "s/%phone-nb%/$phone_nb/g" /etc/wvdial.conf
fi

if [ "$1" = "start" -o "$1" = "restart" ]; then
	wvdial --config /etc/wvdial.conf &

elif [ "$1" = "config" -o "$1" = "configure" ]; then
	wvdialconf /etc/wvdial.conf &
fi

if [ $? = 0 ]; then
	exit 0
fi

exit 1;

