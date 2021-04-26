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

update_nis()
{
	local workgroup="$(cat /etc/config/settings/workgroup)"
	local tmpfile="$(mktemp /tmp/update.XXXXXX)"

	if [ "$workgroup" = "standalone" -o \
		"$STATE" = "no" -o "$STATE" = "off" -o "$STATE" = "false" ]; then
		/bin/chmod 0644 /etc/rc.d/rc.yp
		/bin/chmod 0644 /etc/rc.d/rc.autofs
		grep -F -v '/etc/rc.d/rc.autofs' /etc/rc.d/rc.local 1> $tmpfile
		cp $tmpfile /etc/rc.d/rc.local ; unlink $tmpfile
		return 0
	fi

	local nisserver="$(grep -F -m1 "server" $NISMAP | cut -f2 -d'=')"
	local nisdomain="$(grep -F -m1 "domain" $NISMAP | cut -f2 -d'=')"
	local gateway="$(grep -F -m1 "gateway" $NISMAP | cut -f2 -d'=')"
	local netmask="$(grep -F -m1 "netmask" $NISMAP | cut -f2 -d'=')"
	local submask="$(grep -F -m1 "submask" $NISMAP | cut -f2 -d'=')"
	local nisgroup="$(grep -F -m1 "workgroup" $NISMAP | cut -f2 -d'=')"
	local ipaddr="$(grep -F -m1 "ip-address" $NISMAP | cut -f2 -d'=')"
	local nameserver="$(grep -F -m1 "nameserver" $DHCPMAP | cut -f2 -d'=')"
	local nsswitch="/etc/nsswitch.conf"

	echo "$nisdomain" 1> /etc/defaultdomain

	/bin/chmod 0755 /etc/rc.d/rc.yp
	/bin/chmod 0755 /etc/rc.d/rc.autofs

	if [ "$workgroup" = "network-master" ]; then
		sed -i -r 's/YP_CLIENT_ENABLE=.*$/YP_CLIENT_ENABLE=0/g' /etc/rc.d/rc.yp
		sed -i -r 's/YP_SERVER_ENABLE=.*$/YP_SERVER_ENABLE=1/g' /etc/rc.d/rc.yp
	else
		sed -i -r 's/YP_CLIENT_ENABLE=.*$/YP_CLIENT_ENABLE=1/g' /etc/rc.d/rc.yp
		sed -i -r 's/YP_SERVER_ENABLE=.*$/YP_SERVER_ENABLE=0/g' /etc/rc.d/rc.yp
		echo "/etc/rc.d/rc.autofs" >> /etc/rc.d/rc.local
	fi

	sed -i -r "s/^0.0.0.0.*$/$netmask $submask/g" $ROOTDIR/var/yp/securenets

	if [ ! -e /etc/ypserv.conf ]; then
		echo "dns: yes" 1> /etc/ypserv.conf
	elif $(grep -q -e '^dns:' /etc/ypserv.conf) ; then
		sed -i -r "s/^dns.*$/dns: yes/g" /etc/ypserv.conf
	else
		echo "dns: yes" >> /etc/ypserv.conf
	fi

	if [ ! -e /etc/yp.conf ]; then
		echo "ypserver $nisserver" 1> /etc/yp.conf
		echo "domain $nisdomain broadcast" >> /etc/yp.conf
		echo "broadcast" >> /etc/yp.conf
	else
		if $(grep -q -e '^ypserver:' /etc/yp.conf) ; then
			sed -i -r "s/^ypserver.*$/ypserver: $nisserver/g" /etc/yp.conf
		else
			echo "ypserver $nisserver" >> /etc/yp.conf
		fi

		if $(grep -q -e '^domain.*broadcast' /etc/yp.conf) ; then
			sed -i -r "s/^domain.*broadcast.*/domain $nisdomain broadcast/g" /etc/yp.conf
		else
			echo "domain $nisdomain broadcast" >> /etc/yp.conf
		fi

		if ! $(grep -q -e '^broadcast[ ]*$' /etc/yp.conf) ; then
			echo "broadcast" >> /etc/yp.conf
		fi
	fi

	if [ "$STATE" = "no" -o "$STATE" = "off" -o "$STATE" = "false" ]; then
		sed -i -r "s/^.*passwd:.*files nis/#passwd: files nis/g" $nsswitch
		sed -i -r "s/^.*shadow:.*files nis/#shadow: files nis/g" $nsswitch
		sed -i -r "s/^.*group:.*files nis/#group: files nis/g" $nsswitch
		sed -i -r "s/^.*passwd:.*compat/passwd: compat/g" $nsswitch
		sed -i -r "s/^.*group:.*compat/group: compat/g" $nsswitch
	else
		sed -i -r "s/^.*passwd:.*files nis/passwd: files nis/g" $nsswitch
		sed -i -r "s/^.*shadow:.*files nis/shadow: files nis/g" $nsswitch
		sed -i -r "s/^.*group:.*files nis/group: files nis/g" $nsswitch
		sed -i -r "s/^.*passwd:.*compat/#passwd: compat/g" $nsswitch
		sed -i -r "s/^.*group:.*compat/#group: compat/g" $nsswitch
	fi
	return 0
}

# Main starts here ...
STATE="$1"
ROOTDIR="$2"
NISMAP="/etc/config/services/nis.map"
DHCPMAP="/etc/config/services/dhcp.map"

if [ "$STATE" = "no" -o "$STATE" = "off" -o "$STATE" = "false" ]; then
	if [ -z "$ROOTDIR" ]; then
		/etc/rc.d/rc.yp stop
	fi
fi

update_nis "$STATE"

if [ "$STATE" = "yes" -o "$STATE" = "on" -o "$STATE" = "true" ]; then
	if [ -z "$ROOTDIR" ]; then
		/etc/rc.d/rc.yp start
	fi
fi

exit $?

# end Breeze::OS setup script
