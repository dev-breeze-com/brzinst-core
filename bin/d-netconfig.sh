#!/bin/bash
#
# A script to do basic network configuration.
# Mostly written by Patrick Volkerding <volkerdi@slackware.com>.
# Modified to use /etc/rc.d/rc.inet1.conf Tue Aug 26 16:51:48 PDT 2003 <pjv>
# Modified by dev@tsert.com

write_config_files() {
#
############################################################################
#			  The rc.inet1.conf file.
############################################################################
#

# If we're doing loopback, we don't want 127.0.0.1 and 255.255.255.0 in
# rc.inet1.conf... it's better to leave the values null.  However, since
# we use the IP in other places, we need to make a copy for here.
RCIPCOPY=$IPADDR
RCMASKCOPY=$NETMASK

if [ "$RCIPCOPY" = "127.0.0.1" ]; then
  RCIPCOPY=""
  RCMASKCOPY=""
fi

# echo "Creating /$RC..."
/bin/cat << ENDFILE > $RC
# /etc/rc.d/rc.inet1.conf
#
# This file contains the configuration settings for network interfaces.
# If USE_DHCP[interface] is set to "yes", this overrides any other settings.
# If you don't have an interface, leave the settings null ("").

# You can configure network interfaces other than eth0,eth1... by setting
# IFNAME[interface] to the interface's name. If IFNAME[interface] is unset
# or empty, it is assumed you're configuring eth<interface>.

# Several other parameters are available, the end of this file contains a
# comprehensive set of examples.

# =============================================================================

# Config information for eth0:
IPADDR[0]="$RCIPCOPY"
NETMASK[0]="$RCMASKCOPY"
USE_DHCP[0]="$USE_DHCP"
DHCP_HOSTNAME[0]="$DHCP_HOSTNAME"

# Config information for eth1:
IPADDR[1]=""
NETMASK[1]=""
USE_DHCP[1]=""
DHCP_HOSTNAME[1]=""

# Config information for eth2:
IPADDR[2]=""
NETMASK[2]=""
USE_DHCP[2]=""
DHCP_HOSTNAME[2]=""

# Config information for eth3:
IPADDR[3]=""
NETMASK[3]=""
USE_DHCP[3]=""
DHCP_HOSTNAME[3]=""

# Default gateway IP address:
GATEWAY="$GATEWAY"

# Change this to "yes" for debugging output to stdout.  Unfortunately,
# /sbin/hotplug seems to disable stdout so you'll only see debugging output
# when rc.inet1 is called directly.
DEBUG_ETH_UP="no"

# Example of how to configure a bridge:
# Note the added "BRNICS" variable which contains a space-separated list
# of the physical network interfaces you want to add to the bridge.
#IFNAME[0]="br0"
#BRNICS[0]="eth0"
#IPADDR[0]="192.168.0.1"
#NETMASK[0]="255.255.255.0"
#USE_DHCP[0]=""
#DHCP_HOSTNAME[0]=""

## Example config information for wlan0.  Uncomment the lines you need and fill
## in your info.  (You may not need all of these for your wireless network)
#IFNAME[4]="wlan0"
#IPADDR[4]=""
#NETMASK[4]=""
#USE_DHCP[4]="yes"
#DHCP_HOSTNAME[4]="icculus-wireless"
#DHCP_KEEPRESOLV[4]="yes"
#DHCP_KEEPNTP[4]="yes"
#DHCP_KEEPGW[4]="yes"
#DHCP_IPADDR[4]=""
#WLAN_ESSID[4]=BARRIER05
#WLAN_MODE[4]=Managed
##WLAN_RATE[4]="54M auto"
##WLAN_CHANNEL[4]="auto"
##WLAN_KEY[4]="D5AD1F04ACF048EC2D0B1C80C7"
##WLAN_IWPRIV[4]="set AuthMode=WPAPSK | set EncrypType=TKIP | set WPAPSK=96389dc66eaf7e6efd5b5523ae43c7925ff4df2f8b7099495192d44a774fda16"
#WLAN_WPA[4]="wpa_supplicant"
#WLAN_WPADRIVER[4]="ndiswrapper"

## Some examples of additional network parameters that you can use.
## Config information for wlan0:
#IFNAME[4]="wlan0"              # Use a different interface name nstead of
                                # the default 'eth4'
#HWADDR[4]="00:01:23:45:67:89"  # Overrule the card's hardware MAC address
#MTU[4]=""                      # The default MTU is 1500, but you might need
                                # 1360 when you use NAT'ed IPSec traffic.
#DHCP_KEEPRESOLV[4]="yes"       # If you dont want /etc/resolv.conf overwritten
#DHCP_KEEPNTP[4]="yes"          # If you don't want ntp.conf overwritten
#DHCP_KEEPGW[4]="yes"           # If you don't want the DHCP server to change
                                # your default gateway
#DHCP_IPADDR[4]=""              # Request a specific IP address from the DHCP
                                # server
#WLAN_ESSID[4]=DARKSTAR         # Here, you can override _any_ parameter
                                # defined in rc.wireless.conf, by prepending
                                # 'WLAN_' to the parameter's name. Useful for
                                # those with multiple wireless interfaces.
#WLAN_IWPRIV[4]="set AuthMode=WPAPSK | set EncrypType=TKIP | set WPAPSK=thekey"
                                # Some drivers require a private ioctl to be
                                # set through the iwpriv command. If more than
                                # one is required, you can place them in the
                                # IWPRIV parameter (separated with the pipe (|)
                                # character, see the example).
ENDFILE
#
############################################################################
#			  The networks file.
############################################################################
#
#echo "Creating /$ETCNETWORKS..."
/bin/cat <<EOF >$ETCNETWORKS
#
# networks	This file describes a number of netname-to-address
#		mappings for the TCP/IP subsystem.  It is mostly
#		used at boot time, when no name servers are running.
#

loopback	127.0.0.0
localnet	$NETWORK

# End of networks.
EOF
chmod 644 $ETCNETWORKS
#
############################################################################
#			   The hosts file.
############################################################################
#
#echo "Creating /$HOSTS..."
/bin/cat << EOF > $HOSTS
#
# hosts		This file describes a number of hostname-to-address
#		mappings for the TCP/IP subsystem.  It is mostly
#		used at boot time, when no name servers are running.
#		On small systems, this file can be used instead of a
#		"named" name server.  Just add the names, addresses
#		and any aliases to this file...
#
# By the way, Arnt Gulbrandsen <agulbra@nvg.unit.no> says that 127.0.0.1
# should NEVER be named with the name of the machine.  It causes problems
# for some (stupid) programs, irc and reputedly talk. :^)
#

# For loopbacking.
127.0.0.1		localhost
$IPADDR		$HOSTNM.$DOMAIN $HOSTNM

# End of hosts.

EOF
chmod 644 $HOSTS
#
############################################################################
#			The resolv.conf file.
############################################################################
#
if [ ! "$NAMESERVER" = "" ]; then
  echo "search $DOMAIN" >$RESOLV
  echo "nameserver $NAMESERVER" >>$RESOLV
else
  echo "search $DOMAIN" >$RESOLV
fi
if [ -f $RESOLV ]; then
  chmod 644 $RESOLV
fi
#
############################################################################
#			The rc.netdevice file.
############################################################################
#
if [ -r /cardfound ]; then
  if [ ! "`cat /cardfound`" = "" ]; then
    cat << EOF > etc/rc.d/rc.netdevice
# Load module for network device.
# This script is automatically generated during the installation.

/sbin/modprobe `cat /cardfound`

EOF
    chmod 755 etc/rc.d/rc.netdevice
  fi
fi

rm -f $TMP/tempmsg /cardfound
} # end write_config_files

TMP=/var/log/setup/tmp

if [ ! -d "$TMP" ]; then
 mkdir -p "$TMP"
 chmod 700 "$TMP"
fi

if [ "`fgrep 'DISTRIB_ID=Breeze::OS' /etc/lsb-release`" != "" ]; then

	HOSTNM="`cat /tmp/selected-hostname 2> /dev/null`"
	DOMAIN="`cat /tmp/selected-domain 2> /dev/null`"

 	echo "$HOSTNM" 1> "$TMP/SeThost"
 	echo "$DOMAIN" 1> "$TMP/SeTdom"
fi

# This checks IP address syntax.
# usage: syntax_check ADDRESS #-OF-EXPECTED-SEGMENTS (up to 4)
# example: syntax_check 123.22.43.1 4
# returns: 0=found correct  1=too many fields  2=non numeric field found
#
syntax_check_color() {
  RET_CODE=0 
  SCRATCH=$1
  SCRATCH=`echo $SCRATCH | tr "." "/"`
  INDEX=$2
  while [ ! "$INDEX" = "0" ]; do
    # OK, so I'm a LISP-head :^)
    FIELD=`basename $SCRATCH`
    SCRATCH=`dirname $SCRATCH`
    if expr $FIELD + 1 1> /dev/null 2> /dev/null; then
      true
    else
      RET_CODE=2; # non-numeric field
    fi
    INDEX=`expr $INDEX - 1`
  done
  if [ ! "$SCRATCH" = "." ]; then
    RET_CODE=1; # too many arguments
  fi
  if [ "$3" = "WARN" -a ! "$RET_CODE" = "0" ]; then
    cat << EOF > $TMP/tempmsg

The address you have entered seems to be non-standard. We were expecting
$2 groups of numbers seperated by dots, like: 127.0.0.1
Are you absolutely sure you want to use the address $1?

EOF
    dialog --title "WARNING" --yesno "`cat $TMP/tempmsg`" 9 72
    if [ $? = 0 ]; then
      RET_CODE = 0;
    fi
    rm -r $TMP/tempmsg
  else
    if [ "$3" = "ECHO" ]; then
      echo $RET_CODE;
    fi
  fi
  return $RET_CODE;
}

# Figure out where we are...  cheap hack.
if [ ! -e etc/lsb-release -a ! -e /etc/installer -a ! -e bin/bash ]; then
  cd /
fi;

# IMPORTANT!!! NO LEADING '/' in the paths below, or this script will not
# function from the bootdisk.
RC=etc/rc.d/rc.inet1.conf		# Where rc.inet1.conf file is.
RESOLV=etc/resolv.conf			# Where resolv.conf file is.
HOSTS=etc/hosts			 	# Where hosts file is.
ETCNETWORKS=etc/networks		# Where networks file is.
USE_DHCP=""                             # Use DHCP?  "" == no.
DHCP_HOSTNAME=""                        # This is our DHCP hostname.
#
# defaults:
NETWORK=127.0.0.0
IPADDR=127.0.0.1
NETMASK=255.255.255.0

# Main loop:
if [ "$HOSTNM" = "" -o "$DOMAIN" = "" ]; then

while [ 0 ]; do
cat << EOF > $TMP/tempmsg
First, we'll need the name you'd like to give your host.
Only the base hostname is needed right now. (not the domain)

Enter hostname:
EOF
 dialog --title "ENTER HOSTNAME" --inputbox "`cat $TMP/tempmsg`" 11 65 \
 $HOSTNM 2> $TMP/SeThost
 if [ $? = 1 -o $? = 255 ]; then
  rm -f $TMP/SeThost $TMP/tempmsg
  exit
 fi
 HOSTNM="`cat $TMP/SeThost`"
 rm -f $TMP/SeThost $TMP/tempmsg
 if [ ! "$HOSTNM" = "" ]; then
  break;
 fi
done

while [ 0 ]; do
cat << EOF > $TMP/tempmsg
Now, we need the domain name for this machine, such as:

example.org

Do not supply a leading '.'

Enter domain name for $HOSTNM: 
EOF
 dialog --title "ENTER DOMAINNAME FOR '$HOSTNM'" --inputbox \
"`cat $TMP/tempmsg`" \
14 64 $DOMAIN 2> $TMP/SeTdom
 if [ $? = 1 -o $? = 255 ]; then
  rm -f $TMP/SeTdom $TMP/tempmsg
  exit
 fi
 DOMAIN="`cat $TMP/SeTdom`"
 rm -f $TMP/SeTdom $TMP/tempmsg
 if [ ! "$DOMAIN" = "" ]; then
  break;
 fi
done
fi

# Write the hostname with domain to /etc/HOSTNAME:
echo $HOSTNM.$DOMAIN > etc/HOSTNAME
# Also make sure the hostname is written to /etc/NetworkManager/NetworkManager.conf:
if [ -w etc/NetworkManager/NetworkManager.conf ]; then
  sed -i "s/^hostname=.*$/hostname=$HOSTNM/g" etc/NetworkManager/NetworkManager.conf
fi

dialog --title "CONFIGUATION TYPE FOR '$HOSTNM.$DOMAIN'" \
--default-item DHCP \
--menu \
"Now we need to know how your machine connects to the network.\n\
If you have an internal network card and an assigned IP address, gateway, \
and DNS, use the 'static IP' choice to enter these values.  If your IP \
address is assigned by a DHCP server (commonly used by cable modem and DSL \
services), select 'DHCP'.  If you do not have a network card, select \
the 'loopback' choice.  You may also select 'NetworkManager' if you would \
like to have the NetworkManager daemon automatically handle your wired and \
wireless network interfaces (this is simple and usually works). \
Which type of network setup would you like?"  20 70 4 \
"static IP" "Use a static IP address to configure ethernet" \
"DHCP" "Use a DHCP server to configure ethernet" \
"loopback" "Set up a loopback connection (modem or no net)" \
"NetworkManager" "Autoconfigure network using NetworkManager" 2> $TMP/reply
if [ $? = 1 -o $? = 255 ]; then
  rm -f $TMP/reply
  exit
fi
REPLY=`cat $TMP/reply`
rm -f $TMP/reply

if [ "$REPLY" = "DHCP" ]; then
  USE_DHCP="yes"
  dialog --title "SET DHCP HOSTNAME"  --inputbox "Some network providers require \
that the DHCP hostname be set in order to connect.  If so, they'll have assigned \
a hostname to your machine, which may look something like CC-NUMBER-A (this \
depends on your ISP).  If you were assigned a DHCP hostname, please enter it \
below.  If you do not have a DHCP hostname, just hit ENTER or Cancel." 13 62 \
2> $TMP/SeTDHCPHOST
  NEW_DHCPHOST="`cat $TMP/SeTDHCPHOST`"
  rm -f $TMP/SeTDHCPHOST
  # OK, if we actually got something, use it.
  DHCP_HOSTNAME="$NEW_DHCPHOST"
elif [ "$REPLY" = "loopback" ]; then
  LOOPBACK="yes"
elif [ "$REPLY" = "NetworkManager" ]; then
  LOOPBACK="yes"
  NETWORKMANAGER="yes"
else
  LOOPBACK="no"
fi

if [ "$LOOPBACK" = "no" -a ! "$USE_DHCP" = "yes" ]; then

 while [ 0 ]; do
  if [ -r $TMP/SeTIP ]; then
   IPADDR=`cat $TMP/SeTIP`
  fi
  cat << EOF > $TMP/tempmsg
Enter your IP address for the local machine.  Example: 
111.112.113.114
Enter IP address for $HOSTNM (aaa.bbb.ccc.ddd): 
EOF
  dialog --title "ENTER IP ADDRESS FOR '$HOSTNM.$DOMAIN'" --inputbox \
"`cat $TMP/tempmsg`" \
10 68 $IPADDR 2> $TMP/SeTlip
  if [ $? = 1 -o $? = 255 ]; then
   rm -f $TMP/SeTlip $TMP/tempmsg
   exit
  fi
  IPADDR="`cat $TMP/SeTlip`"
  rm -f $TMP/SeTlip $TMP/tempmsg
  if [ "$IPADDR" = "" ]; then
   continue;
  fi
  syntax_check_color $IPADDR 4 WARN
  if [ $? = 0 ]; then
   echo $IPADDR > $TMP/SeTIP
   break;
  fi
 done

 while [ 0 ]; do
  if [ -r $TMP/SeTnetmask ]; then
   NETMASK=`cat $TMP/SeTnetmask`
  fi
  cat << EOF > $TMP/tempmsg
Enter your netmask.  This will generally look something
like this: 255.255.255.0
Enter netmask (aaa.bbb.ccc.ddd):
EOF
  dialog --title "ENTER NETMASK FOR LOCAL NETWORK" --inputbox \
"`cat $TMP/tempmsg`" \
10 65 $NETMASK 2> $TMP/SeTnmask
  if [ $? = 1 -o $? = 255 ]; then
   rm -f $TMP/SeTnmask $TMP/tempmsg
   exit
  fi
  NETMASK="`cat $TMP/SeTnmask`"
  rm -f $TMP/SeTnmask $TMP/tempmsg
  if [ "$NETMASK" = "" ]; then
   continue;
  fi
  syntax_check_color $NETMASK 4 WARN
  if [ $? = 0 ]; then
   echo $NETMASK > $TMP/SeTnetmask
   break;
  fi
 done
 
 # Set broadcast/network addresses automatically:
 BROADCAST=`ipmask $NETMASK $IPADDR | cut -f 1 -d ' '`
 NETWORK=`ipmask $NETMASK $IPADDR | cut -f 2 -d ' '`

 while [ 0 ]; do
  if [ -r $TMP/SeTgateway ]; then
   GATEWAY=`cat $TMP/SeTgateway`
  fi
  cat << EOF > $TMP/tempmsg
Enter the address for the gateway on your network, such as:
`echo $IPADDR | cut -f 1-3 -d .`.1

If you don't have a gateway on your network just hit ENTER
without entering a gateway IP address.

Enter gateway address (aaa.bbb.ccc.ddd):
EOF
  dialog --title "ENTER GATEWAY ADDRESS" --inputbox "`cat $TMP/tempmsg`" \
  14 64 $GATEWAY 2> $TMP/SeTgate
  if [ $? = 1 -o $? = 255 ]; then
   rm -f $TMP/SeTgate $TMP/tempmsg
   exit
  fi
  GATEWAY="`cat $TMP/SeTgate`"
  rm -f $TMP/SeTgate $TMP/tempmsg
  if [ "$GATEWAY" = "" ]; then
    echo > $TMP/SeTgateway
    break;
  fi
  syntax_check_color $GATEWAY 4 WARN
  if [ $? = 0 ]; then
    echo $GATEWAY > $TMP/SeTgateway
    break;
  fi
 done
fi

if [ "$LOOPBACK" = "no" ]; then
 dialog --title "USE A NAMESERVER?" --yesno "Will you be accessing a \
nameserver?" 5 42
 if [ $? = 0 ]; then
  if [ ! "`cat $TMP/SeTns 2> /dev/null`" = "" ]; then
    DNSSAMPLE="`cat $TMP/SeTns 2> /dev/null`"
  elif [ "$GATEWAY" = "" ]; then
    DNSSAMPLE=`echo $IPADDR | cut -f 1-3 -d .`
  else
    DNSSAMPLE=$GATEWAY
  fi
  while [ "$NAMESERVER" = "" ]; do
   cat << EOF > $TMP/tempmsg
Here is your current IP address, full hostname, and base hostname:
$IPADDR       $HOSTNM.$DOMAIN    $HOSTNM

Please give the IP address of the name server to use,
such as $DNSSAMPLE.

You can add more Domain Name Servers later by editing /$RESOLV.

Primary name server to use (aaa.bbb.ccc.ddd): 
EOF
   dialog --title "SELECT NAMESERVER" --inputbox \
"`cat $TMP/tempmsg`" 17 72 $DNSSAMPLE 2> $TMP/SeTns
   if [ $? = 1 -o $? = 255 ]; then
    rm -f $TMP/tempmsg $TMP/SeTns 
    break
   fi
   NAMESERVER="`cat $TMP/SeTns`"
   rm -f $TMP/tempmsg $TMP/SeTns 
  done
 fi
fi

# Check for existing network driver:
unset DONOTPROBE
if cat /proc/net/dev | grep eth0 1> /dev/null 2> /dev/null ; then
  DONOTPROBE=true 
fi

# Really, this rc.netdevice thing is mostly obsolete except for
# handmade local scripts anyway, these days with udev...
# So, we'll skip it:
DONOTPROBE=true

if [ -d lib/modules/`uname -r` \
     -a ! "$LOOPBACK" = "yes" \
     -a ! -x etc/rc.d/rc.hotplug \
     -a ! "$DONOTPROBE" = "true" \
     -a ! -r /cardfound ]; then
  dialog --title "PROBE FOR NETWORK CARD?" --menu "If you like, we \
can look to see what kind of network card you have in your machine, and \
if we find one create an /etc/rc.d/rc.netdevice script to load the module \
for it at boot time.  There's a slight bit of danger that the probing \
can cause problems, but it almost always works.  If you'd rather configure \
your system manually, you can skip the probing process and edit \
/etc/rc.d/rc.modules or /etc/modules.conf later to have it load the right module." \
16 68 2 \
"probe" "look for network cards to set up" \
"skip" "skip probe;  edit /etc/rc.d/rc.modules later" 2> $TMP/reply
  if [ $? = 1 -o $? = 255 ]; then
    rm -f $TMP/reply
    exit
  fi
  REPLY=`cat $TMP/reply`
  rm -f $TMP/reply
  if [ ! "$REPLY" = "skip" ]; then
    for card in 3c59x 82596 dgrs eepro100 e1000 epic100 hp100 lance \
    ne2k-pci olympic pcnet32 rcpci 8139too 8139cp tlan tulip via-rhine \
    yellowfin natsemi ; do
      chroot . /sbin/modprobe $card 2> /dev/null
      if [ $? = 0 ]; then
        dialog --title "CARD DETECTED" --msgbox "A networking card using \
the $card.o module has been detected." 5 72
        echo "$card" > /cardfound
        break;
      fi
     done
     if [ ! -r /cardfound ]; then
       # Don't probe for com20020, because it doesn't check and will always load.
       # Don't probe for arlan, because it needs irq= to work.
       # Don't probe for com90io or com90xx because they taint the kernel.
       for card in depca ibmtr 3c359 3c501 3c503 3c505 3c507 3c509 3c515 ac3200 \
         abyss acenic at1700 cosa cs89x0 de4x5 de600 \
         de620 dmfe dl2k e2100 eepro eexpress eth16i ewrk3 fealnx hamachi hostess_sv11 \
         hp-plus hp lanstreamer ni5010 ni52 ni65 ns83820 sb1000 sealevel sis900 sk98lin skfp smc-ultra \
         smc9194 smctr starfire sungem sunhme tg3 wd e100 iph5526 lp486e tmspci winbond-840 ; do
         chroot . /sbin/modprobe $card 2> /dev/null
         if [ $? = 0 ]; then
           dialog --title "CARD DETECTED" --msgbox "A networking card using \
the $card.o module has been detected." 5 72
           echo "$card" > /cardfound
           break
         fi
       done
     fi
     if [ ! -r /cardfound ]; then
       dialog --title "NO CARD DETECTED" --msgbox "Sorry, but no network \
card could be probed for on your system.  Some cards (like non-PCI NE2000s) \
must be supplied with the I/O address to use and can't be probed for safely. \
You'll have to try to configure the card later by editing \
/etc/rc.d/rc.modules or recompiling your kernel." 9 70
     fi
  fi
fi

if [ "$LOOPBACK" = "yes" -a ! "$NETWORKMANAGER" = "yes" ]; then
  dialog --title "NETWORK SETUP COMPLETE" --yesno "Your networking \
system is now configured to use loopback:

IP address: 127.0.0.1
Netmask: 255.255.255.0

Is this correct?  Press 'Yes' to continue, or 'No' to reconfigure." 0 0
  RETVAL=$?
elif [ "$LOOPBACK" = "yes" -a "$NETWORKMANAGER" = "yes" ]; then
  dialog --title "NETWORK SETUP COMPLETE" --yesno "Your networking \
system is now configured to use NetworkManager for
wired and wireless network management.  To set up wireless networks
and view status, add the Network Management control panel widget to
your KDE desktop.

Is this correct?  Press 'Yes' to confirm, or 'No' to reconfigure." 0 0
  RETVAL=$?
elif [ "$USE_DHCP" = "" ]; then
  while [ 0 ]; do
    dialog --title "CONFIRM NETWORK SETUP" \
--ok-label Accept \
--extra-label Edit \
--cancel-label Restart \
--inputmenu \
"These are the settings you have entered.  To accept them and complete \
the networking setup, press enter.  If you need to make any changes, you \
can do that now (or reconfigure later using 'netconfig')." \
22 60 12 \
"Hostname:" "$HOSTNM" \
"Domain name:" "$DOMAIN" \
"IP address:" "$IPADDR" \
"Netmask:" "$NETMASK" \
"Gateway:" "$GATEWAY" \
"Nameserver:" "$NAMESERVER" 2> $TMP/tempmsg
    RETVAL=$?
    if [ "$RETVAL" = "3" ]; then
      FIELD=`cat $TMP/tempmsg | cut -f 1 -d : | cut -f 2- -d ' '`
      NEWVAL=`cat $TMP/tempmsg | cut -f 2 -d : | cut -f 2- -d ' '`
      if [ "$FIELD" = "Hostname" ]; then
        HOSTNM=$NEWVAL
      elif [ "$FIELD" = "Domain name" ]; then
        DOMAIN=$NEWVAL
      elif [ "$FIELD" = "IP address" ]; then
        IPADDR=$NEWVAL
      elif [ "$FIELD" = "Netmask" ]; then
        NETMASK=$NEWVAL
      elif [ "$FIELD" = "Gateway" ]; then
        GATEWAY=$NEWVAL
      elif [ "$FIELD" = "Nameserver" ]; then
        NAMESERVER=$NEWVAL
      fi
    else
      break
    fi
  done
else # DHCP was used
  dialog --title "CONFIRM SETUP COMPLETE" \
--yesno "Your networking system is now configured to use DHCP:

  Hostname:     $HOSTNM
  Domain name:  $DOMAIN
  IP address:   (use DHCP server)
  Netmask:      (use DHCP server)
  Gateway:      (use DHCP server)
  Nameserver:   (use DHCP server)

Is this correct?  Press 'Yes' to continue, or 'No' to reconfigure." 0 0
  RETVAL=$?
fi

if [ "$RETVAL" = "0" ]; then
  # Write the hostname with domain to /etc/HOSTNAME:
  echo $HOSTNM.$DOMAIN > etc/HOSTNAME
  # Also make sure the hostname is written to /etc/NetworkManager/NetworkManager.conf:
  if [ -w etc/NetworkManager/NetworkManager.conf ]; then
    sed -i "s/^hostname=.*$/hostname=$HOSTNM/g" etc/NetworkManager/NetworkManager.conf
  fi
  write_config_files
  if [ "$NETWORKMANAGER" = "yes" -a -r etc/rc.d/rc.networkmanager ]; then
    chmod 755 etc/rc.d/rc.networkmanager
  fi
  if [ "$1" = "" ]; then
    dialog --msgbox "Settings accepted.  Basic network configuration is complete." 6 40
  fi
else
  if [ "$1" = "" ]; then
    dialog --msgbox "Settings discarded.  Run the 'netconfig' command again if you need to reconfigure your network settings." 6 60
  fi
fi

exit $RETVAL

