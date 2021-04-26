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

function set_etc_sys_files() {

  local hostname="$1"
  local ipaddr="$2"

  echo "$hostname" 1> $TMP/selected-hostname

  if live_or_install_media ; then

#    echo "$hostname" 1> /etc/hostname
#    echo "$hostname" 1> /etc/HOSTNAME
#    echo "$hostname" 1> /proc/sys/kernel/hostname
#    cp -f $BRZDIR/factory/hosts /etc/hosts

    cp -f $BRZDIR/factory/hosts $TMP/hosts
    sed -r -i "s/breeze/$hostname/g" $TMP/hosts
    sed -r -i "s/192.168.1.1/$ipaddr/g" $TMP/hosts
    cp -f $TMP/hosts $TMP/etc_hosts
  fi

  return 0
}

function set_dns_openrc_values() {

  local logfile="$1"
  local dhcplog="/var/run/dhcpcd/resolv.conf/${2}.dhcp"

  INF="$2"
  GATEWAY="$(grep -F 'changing default route via' $logfile | sed -r 's/^.*[ ]//g' | crunch)"
  IPADDR="$(grep -F 'rebinding lease' $logfile | sed -r 's/^.*[ ]//g' | crunch)"
  NETIP="$(grep -F 'changing route' $logfile | sed -r 's/^.*[ ]//g' | crunch)"
  NAMESERVER="$(grep -F 'domain' $dhcplog | sed -r 's/^.*[ ]//g' | crunch)"
  DHCP_DOMAIN="$(grep -F 'domain' $dhcplog | sed -r 's/^.*[ ]//g' | crunch)"

  if [ -z "$NAMESERVER" ]; then
    return 1
  fi
  return 0
}

function set_dns_values() {

  local logfile="$1"
  local edev="$2"

#  if [ -x /sbin/openrc ]; then
#    set_dns_openrc_values $logfile "$edev"
#    return $?
#  fi

  GATEWAY="$(grep -m1 -F 'GATEWAYS=' $logfile | cut -f 2 -d'=')"
  GATEWAY="$(echo "$GATEWAY" | sed -r "s/'//g" | crunch)"
  GATEWAY="$(echo "$GATEWAY" | cut -f 1 -d' ')"

  NAMESERVER="$(grep -m1 -F 'DNSSERVERS=' $logfile | cut -f 2 -d'=')"
  NAMESERVER="$(echo "$NAMESERVER" | sed -r "s/'//g" | crunch)"
  NAMESERVER="$(echo "$NAMESERVER" | cut -f 1 -d' ')"

  if [ -z "$GATEWAY" ]; then
    GATEWAY="$(grep -m1 -F 'DNSSERVERS=' $logfile | cut -f 2 -d'=')"
    GATEWAY="$(echo "$GATEWAY" | sed -r "s/'//g" | crunch)"
    GATEWAY="$(echo "$GATEWAY" | cut -f 1 -d' ')"
  fi

  if [ -z "$NAMESERVER" ]; then
    NAMESERVER="$(grep -m1 -F 'DNSDOMAIN' $logfile | cut -f 2 -d'=')"
    NAMESERVER="$(echo "$NAMESERVER" | sed -r "s/'//g" | crunch)"
    NAMESERVER="$(echo "$NAMESERVER" | cut -f 1 -d' ')"
  fi

  echo $GATEWAY 1> $TMP/selected-gateway
  echo $NAMESERVER 1> $TMP/selected-nameserver

  IPADDR="$(grep -m1 -F 'IPADDR=' $logfile | cut -f 2 -d'=')"
  IPADDR="$(echo "$IPADDR" | sed -r "s/'//g" | crunch)"
  echo $IPADDR 1> $TMP/selected-lan-ipaddr

  INF="$(grep -m1 -F 'INTERFACE=' $logfile | cut -f 2 -d'=')"
  INF="$(echo "$INF" | sed -r "s/'//g" | crunch)"
  [ -z "$INF" -a -n "$EDEV" ] && INF="$EDEV"

  DHCP_DOMAIN="$(echo "$NAMESERVER" | sed -r 's/^[^.]*.//g')"
  echo $DHCP_DOMAIN 1> $TMP/selected-dhcp-domain

  if echo "$GATEWAY" | egrep -q '^[0-9]' ; then
    NETIP="$(echo "$GATEWAY" | cut -f 1-3 -d'.').0/24"
  elif echo "$NAMESERVER" | egrep -q '^[0-9]' ; then
    NETIP="$(echo "$NAMESERVER" | cut -f 1-3 -d'.').0/24"
  fi

  if [ -z "$NAMESERVER" ]; then
    return 1
  fi

  return 0
}

function write_dns_values() {

  rm -f $DNS_SETTINGS 2> /dev/null

  echo "dns=dhcp" 1> $DNS_SETTINGS
  echo "interface=$INF" >> $DNS_SETTINGS
  echo "gateway=$GATEWAY" >> $DNS_SETTINGS
  echo "nameserver=$NAMESERVER" >> $DNS_SETTINGS
  echo "hostname=$HOSTNAME" >> $DNS_SETTINGS
  echo "domain=$DOMAIN" >> $DNS_SETTINGS
  echo "ipaddr=" >> $DNS_SETTINGS
  echo "lan-ipaddr=$IPADDR" >> $DNS_SETTINGS
  echo "master=master.localdomain" >> $DNS_SETTINGS
  echo "internal-net=$NETIP" >> $DNS_SETTINGS
  echo "networkd=none" >> $DNS_SETTINGS
  echo "primary-dns=8.8.8.8" >> $DNS_SETTINGS
  echo "secondary-dns=8.8.4.4" >> $DNS_SETTINGS

  cp $DNS_SETTINGS $TMP/hwnet.map
  echo "yes" 1> $TMP/internet-enabled

  cp $DNS_SETTINGS $TMP/adsl.map
  cp $DNS_SETTINGS $TMP/cable.map
  cp $DNS_SETTINGS $TMP/wireless.map
  cp $DNS_SETTINGS $TMP/dialup.map

  return 0
}

MODE="$1"
DOMAIN="localdomain"
DNS_SETTINGS="$TMP/ifsetup.map"
DHCPCD=$BRZDIR/bin/dhcpcd-x64

RELEASE="$(cat $TMP/selected-release 2> /dev/null)"
HOSTNAME="$(cat $TMP/selected-hostname 2> /dev/null)"
CONNECTION="$(cat $TMP/selected-connection 2> /dev/null)"
CURHOST="$(cat /proc/sys/kernel/hostname 2> /dev/null)"

[ -e /etc/dhcpc ] || mkdir -p /etc/dhcpc

echo "no" 1> $TMP/internet-enabled

DEVICES="$(cat /proc/net/dev | grep -F ':' | \
  sed -r "s/^[ ]*//" | cut -f1 -d: | \
  grep -v -E 'lo|bond|dummy|ifb|sit' | sort)"

if [ -z "$HOSTNAME" ]; then
  HOSTNAME="$(cat /etc/HOSTNAME 2> /dev/null)"

  if [ -z "$HOSTNAME" ]; then
    echo "INSTALLER: FAILURE L_MISSING_HOSTNAME"
    exit 1
  fi
fi

if echo "$HOSTNAME" | grep -F -q '.' ; then
  DOMAIN="$(echo $HOSTNAME | cut -f2 -d '.')"
  HOSTNAME="$(echo $HOSTNAME | cut -f1 -d '.')"
fi

mkdir -p /etc/dhcpc

echo "$HOSTNAME" 1> $TMP/selected-hostname

for EDEV in eth0 $DEVICES; do

  LOGFILE="/etc/dhcpc/dhcpcd-${EDEV}.info"

  EINF="$(echo "$EDEV" | sed -r 's/[0-9]//g')"

  if [ -f "$LOGFILE" -a -s "$LOGFILE" ]; then

    echo "INSTALLER: MESSAGE L_CHECKING_${EINF}_NETWORK"
    sync; sleep 1

    if set_dns_values $LOGFILE "$EDEV" ; then
      write_dns_values
      set_etc_sys_files $HOSTNAME
      echo "INSTALLER: SUCCESS L_NETWORK_CONFIG_SUCCESS"
      exit 0
    fi
  fi
done

set_etc_sys_files $HOSTNAME

# If we can get information from a local DHCP server, we store that for later:
if grep -wq nodhcp /proc/cmdline ; then
  echo "DHCP network probing was disabled on boot !"
  echo "INSTALLER: FAILURE L_NETWORK_CONFIG_DISABLED"
  exit 1
fi

dhcpcd_rc=1

if [ -x /usr/bin/pkill ]; then
  pkill -KILL dhcpcd ; sync
fi

for EDEV in eth0 $DEVICES; do

  LOGFILE="/etc/dhcpc/dhcpcd-${EDEV}.info"

  if [ -e $DNS_SETTINGS -a -s $LOGFILE ]; then

    cp $DNS_SETTINGS $TMP/hwnet.map
    echo "yes" 1> $TMP/internet-enabled

    cp $DNS_SETTINGS $TMP/adsl.map
    cp $DNS_SETTINGS $TMP/cable.map
    cp $DNS_SETTINGS $TMP/wireless.map
    cp $DNS_SETTINGS $TMP/dialup.map

    IPADDR="$(grep -m1 -F 'IPADDR=' $LOGFILE | cut -f2 -d'=')"
    IPADDR="$(echo "$IPADDR" | sed -r "s/'//g" | crunch)"
    echo $IPADDR 1> $TMP/selected-lan-ipaddr

    echo "INSTALLER: SUCCESS L_NETWORK_CONFIG_SUCCESS"
    exit 0
  fi

  touch /etc/resolv.conf 2> /dev/null

#  if [ -x /sbin/openrc ]; then
#    $DHCPCD -j $LOGFILE -t 30 -h $HOSTNAME $EDEV
#  else
    $DHCPCD -t 30 -h $HOSTNAME $EDEV 1> $TMP/dhcpcd.errs 2>&1
#  fi

  dhcpcd_rc=$?

  if [ $dhcpcd_rc = 0 ]; then

    if live_or_install_media ; then
      echo "" >> /etc/resolv.conf
      echo "domain google.com" >> /etc/resolv.conf
      echo "nameserver 8.8.8.8" >> /etc/resolv.conf
      echo "nameserver 8.8.4,4" >> /etc/resolv.conf
      cp -f /etc/resolv.conf $TMP/resolv.conf
    fi
    break
  fi
done

if [ $dhcpcd_rc = 0 ]; then
  if set_dns_values $LOGFILE "$EDEV" ; then
    write_dns_values
    echo "INSTALLER: SUCCESS L_NETWORK_CONFIG_SUCCESS"
    exit 0
  fi
fi

if [ "$CONNECTION" = "none" -o "$CONNECTION" = "lan" ]; then
  echo "INSTALLER: FAILURE L_NETWORK_CONFIG_CANCEL"
else
  echo "INSTALLER: FAILURE L_NETWORK_CONFIG_FAILURE"
fi

exit 1

# end Breeze::OS setup script
