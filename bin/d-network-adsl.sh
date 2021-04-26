#!/bin/bash
# (c) Eduard Bloch <blade@debian.org>
#
# LICENSE: GPL
# Purpose: initial PPPoE configuration on Debian
# Depends: bash, pppd, pppoe, whiptail, my usepeerdns script
#
# Modified: by dev@tsert.com (http://www.tsert.com) 09/07/2007
# (c) Pierre Innocent, Tsert Inc. <dev@tsert.com>
#
# Copyright 1996-2011, All Rights Reserved.
# See copyright file

export TEXTDOMAINDIR="/usr/share/locale"
export TEXTDOMAIN=pppoeconf
export OPTSFILE="/etc/ppp/peers/dsl-provider"
export INTFILE="/etc/network/interfaces"

. d-dirpaths.sh

# Exit if non-root
if [ "`id -u`" != "0" ]; then
   echo "You must be root ..."
   exit 1
fi

rm -f /var/log/adsl-failure.log
rm -f /var/log/adsl-close-success.0
rm -f /var/log/adsl-open-success.0

if [ "$1" = "stop" -o "$1" = "close" -o "$1" = "exit" ]; then
	/usr/bin/poff -a
	/usr/bin/poff -a
	touch /var/log/adsl-close-success.0
	exit 0
fi

if [ "$1" = "start" -o "$1" = "open" ]; then
	/usr/bin/pon dsl-provider

	if [ $? = 0 ]; then
		echo "INTERFACE FOUND"
		sleep 3
		touch /var/log/adsl-open-success.0
   		exit 0
	fi
	echo "NO INTERFACE FOUND"
# NO INTERFACE FOUND
# Sorry, no working ethernet card could be found. If you do have an interface
# card which was not autodetected so far, you probably wish to load the driver
# manually using the modconf utility. Run modconf now?
	exit 1;
fi

PATH="/bin:/sbin:/usr/bin:/usr/sbin"
export PATH

. /usr/bin/gettext.sh

# EOF SUID wrapper
modprobe -q pppoe

# Specify user-id & password
#
if [ -f "$2" ]; then
	user="$(grep -F -m1 username $2 | cut -f2 -d=)"
	pass="$(grep -F -m1 password $2 | cut -f2 -d=)"
	with_auth="no"
else
	user=$2
	pass=$3
	with_auth=$4
fi

# recent ppp packages have a PPPoE discovery helper program
if test -x /usr/sbin/pppoe-discovery && test -e /proc/net/pppoe ; then
  kernel_pppoe=1
  DISCOVERY_PROGRAM=pppoe-discovery
else
  DISCOVERY_PROGRAM=pppoe
fi

export DISCOVERY_PROGRAM

# create a default peers file if there is none
if ! test -r $OPTSFILE ; then
	fresh_optsfile=1
	cat <<EOM > $OPTSFILE
# Minimalistic default options file for DSL/PPPoE connections

noipdefault
defaultroute
replacedefaultroute
hide-password
#lcp-echo-interval 30
#lcp-echo-failure 4
noauth
persist
#mtu 1492
usepeerdns
EOM
fi

chmod 0640 $OPTSFILE
chown root:dip $OPTSFILE

if ! grep -q "dsl-provider" $INTFILE ; then
   printf '\niface dsl-provider inet ppp\nprovider dsl-provider\n' >> $INTFILE
fi

if ! grep -q "line maintained by pppoeconf" $INTFILE ; then
   sed -i -e 's,provider dsl-provider$,     provider dsl-provider\n# please do not modify the following line\n     pre-up /sbin/ifconfig eth0 up # line maintained by pppoeconf\n,' $INTFILE
fi

umask 177

# make a secure directory
TMP="`mktemp -d -p /etc/ppp`"
export TMP

sectempfile="`mktemp -p $TMP`"
export sectempfile

trap "rm -rf '$TMP'" 0 HUP INT TRAP TERM

# Most providers send the needed login information per mail. Some providers
# describe it in odd ways, assuming the user to input the data in their
# "user-friendly" setup programs. But in fact, these applications generate
# usuall PPP user names and passwords from the entered data. You can find
# the real names too and input the correct data in the dialog box.

list=$( LANG=C /sbin/ifconfig -a | grep "Ethernet" | grep -v irlan | cut -f1 -d" " )

# now, execute an AC lookup on each interface
for mmm in '' ' -U ' ; do
  for iface in $list; do
	 # use the first candidate only, this is done anyways, below
	 if test -z "`grep -l AC $TMP/*.pppoe 2>/dev/null| cut -f1 -d"." | head -n1`" ; then
		title=$(gettext 'SCANNING DEVICE')
		text=$(eval_gettext 'Looking for PPPoE Access Concentrator on $iface...')
		if test -n "$mmm" ; then
		   mmode=$(gettext '(multi-modem mode)')
		fi

		touch $TMP/pppoe.scan
		ifconfig $iface up
		($DISCOVERY_PROGRAM $mmm -A -I $iface > $TMP/$iface.pppoe ; rm $TMP/pppoe.scan) &
		( time=0 ; while test -f $TMP/pppoe.scan ; do time=`expr $time + 6`; echo $time; sleep 1; done )
true
	 fi
  done
done

cd "$TMP"

if test "$5" ; then
  iface=$5
else
  iface=`grep -l AC *.pppoe| cut -f1 -d"." | head -n1`
fi

ifacenocomma=$(echo $iface | sed -e 's/,/\\,/g')

if test -z "$iface" ; then
	echo "NOT CONNECTED ..." 1> /var/log/adsl-failure.log
	# Sorry, I scanned $number interfaces, but the Access Concentrator of your provider did not respond. Please check your network and modem cables. Another reason for the scan failure may also be another running pppoe process which controls the modem.
	exit 1
fi

if [ "$kernel_pppoe" ]; then
	 # interface activation code - this sucks here, pppd plugin should do it as needed
	sed -i -e "s,pre-up /sbin/ifconfig[[:space:]]\+[^[:space:]]\+[[:space:]]\+up.#.line.maintained.by.pppoeconf,pre-up /sbin/ifconfig $ifacenocomma up # line maintained by pppoeconf," $INTFILE

 # change peers config file, sanity check first
	grep -q "^plugin.*rp-pppoe.so" $OPTSFILE || echo "plugin rp-pppoe.so $iface" >> $OPTSFILE
 # disable the pppoe tunnel command
 if grep -q '^pty' $OPTSFILE ; then
	sed -i -e 's/^pty/#pty/' $OPTSFILE
 fi

 # set the interface
	sed -i -e "s,^plugin.\+rp-pppoe.so[[:space:]]\+[^[:space:]]*,plugin rp-pppoe.so $ifacenocomma," $OPTSFILE
else
 # sanity check first, fix the config file
 # install the default line
   grep -q '^.*pty.*pppoe.*-I' $OPTSFILE || echo 'pty "pppoe -I eth0 -T 80"' >> $OPTSFILE
   # install alternative lines
   grep -q '^.*pty.*pppoe.*-m.*1452' $OPTSFILE || echo '#pty "pppoe -I eth0 -T 80 -m 1452"' >> $OPTSFILE
   grep -q '^.*pty.*pppoe.*-m.*1412' $OPTSFILE || echo '#pty "pppoe -I eth0 -T 80 -m 1412"' >> $OPTSFILE
   # at least one must work
   grep -q '^pty' $OPTSFILE || echo 'pty "pppoe -I eth0 -T 80"' >> $OPTSFILE

   # set the interface
   sed -i -e "s,-I[[:space:]]*[[:alnum:]]*,-I $ifacenocomma," $OPTSFILE
fi

# fix final newline
test -e /etc/ppp/pap-secrets && ( [ $(tail -1 /etc/ppp/pap-secrets | wc -l) -eq 0 ] || echo >> /etc/ppp/pap-secrets )
test -e /etc/ppp/chap-secrets && ( [ $(tail -1 /etc/ppp/chap-secrets | wc -l) -eq 0 ] || echo >> /etc/ppp/chap-secrets )

# Most people using popular dialup providers prefer the options 'noauth' and
# 'defaultroute' in their configuration and remove the 'nodetach' option.
# Further, for busy providers the lcp-echo-interval could be increased.
# Should I check your configuration file and change these settings
# where neccessary?" 22 70

if [ "$with_auth" = "false" -o "$with_auth" = "no" ]; then
	grep -q '^noauth' $OPTSFILE || echo 'noauth' >> $OPTSFILE
	grep -q '^defaultroute' $OPTSFILE  || echo 'defaultroute' >> $OPTSFILE
	sed -i -e "/^nodetach.*/d" $OPTSFILE
#   sed -i -e "s/^lcp-echo-interval 20$/lcp-echo-interval 60/" $OPTSFILE
fi

usernoslash=$(echo $user | sed -e 's,/,\\/,')

# Update /etc files
sed -i -e "/^\"*$usernoslash\"* .*/ d" /etc/ppp/pap-secrets
echo "\"$user\" * \"$pass\"" >> /etc/ppp/pap-secrets

sed -i -e "/^\"*$usernoslash\"* .*/ d" /etc/ppp/chap-secrets
echo "\"$user\" * \"$pass\"" >> /etc/ppp/chap-secrets

# You need at least one DNS IP address to resolve the normal host names.
# Normally your provider sends you addresses of useable servers when the
# connection is established. Would you like to add these addresses
# automatically to the list of nameservers in your local /etc/resolv.conf
#
grep -q "^usepeerdns" $OPTSFILE || echo "usepeerdns" >> $OPTSFILE

printf '#!/bin/sh\n# Enable MSS clamping (autogenerated by pppoeconf)\n\niptables -o "$PPP_IFACE" --insert FORWARD 1 -p tcp --tcp-flags SYN,RST SYN -m tcpmss --mss 1400:1536 -j TCPMSS --clamp-mss-to-pmtu\n' > /etc/ppp/ip-up.d/0clampmss

# disable the old line
sed -i -e 's/^pty/#&/' $OPTSFILE

# enable the one with our mss size
sed -i -e 's/^#\(pty.*-m 1452.*\)/\1/' $OPTSFILE

# end of story
cd /

rm -rf "$TMP"

echo "ADSL CONNECTED ..."

exit 0

