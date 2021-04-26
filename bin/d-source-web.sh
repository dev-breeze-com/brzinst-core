#!/bin/bash
#
# GNU GENERAL PUBLIC LICENSE Version 3
#
# Copyright 1994, 1998, 2000  Patrick Volkerding, Concord, CA, USA 
# Copyright 2001, 2003  Slackware Linux, Inc., Concord, CA, USA
# Copyright 2007, 2009  Patrick Volkerding, Sebeka, MN, USA 
# All rights reserved.
#
# This script will be called with the single argument of "boot" during the
# system startup, to allow for unattended network configuration.
#
# For this to work, all required information must be passed on the commandline.
# Two parameters, 'kbd=' and 'nic=' must be used to supply this information.
#
# kbd=<keyboard_layout>
# nic=<driver>:<interface>:<dhcp|static>[:ipaddr:netmask[:gateway]]
#
# Initialize folder paths
. d-dirpaths.sh

DERIVED="`cat $TMP/selected-derivative 2> /dev/null`"
RELEASE="`cat $TMP/selected-release 2> /dev/null`"
HOSTNAME="`cat $TMP/selected-hostname 2> /dev/null`"

echo -n "$HOSTNAME" 1> /etc/hostname
echo -n "master.localdomain" 1> $TMP/selected-source
echo -n "master.localdomain" 1> $TMP/selected-source-path

# Terminate the script now if we have an interface with an IP address:
# Running the script is not needed anymore in that case.
#
if `ip -f inet -o addr show | grep -v " lo " 1>/dev/null 2>/dev/null` ; then
	exit 0
fi

# Function to convert the netmask from CIDR format to dot notation.
cidr_cvt() {
  inform=$1
  if   [ $inform -ge 32 ]; then outform='255.255.255.255'
  elif [ $inform -ge 31 ]; then outform='255.255.255.254'
  elif [ $inform -ge 30 ]; then outform='255.255.255.252'
  elif [ $inform -ge 29 ]; then outform='255.255.255.248'
  elif [ $inform -ge 28 ]; then outform='255.255.255.240'
  elif [ $inform -ge 27 ]; then outform='255.255.255.224'
  elif [ $inform -ge 26 ]; then outform='255.255.255.192'
  elif [ $inform -ge 25 ]; then outform='255.255.255.128'
  elif [ $inform -ge 24 ]; then outform='255.255.255.0'
  elif [ $inform -ge 23 ]; then outform='255.255.254.0'
  elif [ $inform -ge 22 ]; then outform='255.255.252.0'
  elif [ $inform -ge 21 ]; then outform='255.255.248.0'
  elif [ $inform -ge 20 ]; then outform='255.255.240.0'
  elif [ $inform -ge 19 ]; then outform='255.255.224.0'
  elif [ $inform -ge 18 ]; then outform='255.255.192.0'
  elif [ $inform -ge 17 ]; then outform='255.255.128.0'
  elif [ $inform -ge 16 ]; then outform='255.255.0.0'
  elif [ $inform -ge 15 ]; then outform='255.254.0.0'
  elif [ $inform -ge 14 ]; then outform='255.252.0.0'
  elif [ $inform -ge 13 ]; then outform='255.248.0.0'
  elif [ $inform -ge 12 ]; then outform='255.240.0.0'
  elif [ $inform -ge 11 ]; then outform='255.224.0.0'
  elif [ $inform -ge 10 ]; then outform='255.192.0.0'
  elif [ $inform -ge 9 ]; then outform='255.128.0.0'
  elif [ $inform -ge 8 ]; then outform='255.0.0.0'
  elif [ $inform -ge 7 ]; then outform='254.0.0.0'
  elif [ $inform -ge 6 ]; then outform='252.0.0.0'
  elif [ $inform -ge 5 ]; then outform='248.0.0.0'
  elif [ $inform -ge 4 ]; then outform='240.0.0.0'
  elif [ $inform -ge 3 ]; then outform='224.0.0.0'
  elif [ $inform -ge 2 ]; then outform='192.0.0.0'
  elif [ $inform -ge 1 ]; then outform='128.0.0.0'
  elif [ $inform -ge 0 ]; then outform='0.0.0.0'
  fi
  echo $outform
}

# First, sane defaults:
INTERFACE=""
ENET_MODE="ask"

# Does the commandline have NIC information for us?
# Format is 'nic=driver:interface:<dhcp|static>:ip:mask:gw'
#
for CMDELEM in $(cat /proc/cmdline) ; do
 if $(echo $CMDELEM | grep -q "^nic=") ; then
  DRIVER=$(echo $CMDELEM | cut -f2 -d=)
  INTERFACE=$(echo $DRIVER | cut -f2 -d:)
  ENET_MODE=$(echo $DRIVER | cut -f3 -d:)
  if [ "$ENET_MODE" = "static" ]; then
   IPADDR=$(echo $DRIVER | cut -f4 -d:)
   NETMASK=$(echo $DRIVER | cut -f5 -d:)
   # We allow for CIDR notation of the netmask (0 < NETMASK < 25):
   if [ "$(echo $NETMASK | tr -cd '\.')" != "..." ]; then
    NETMASK=$(cidr_cvt $NETMASK)
   fi
   GATEWAY=$(echo $DRIVER | cut -f6 -d:)
  fi
  DRIVER=$(echo $DRIVER | cut -f1 -d:)
  break
 fi
done

# If the script has an argument of 'boot' then we require all information for
# unattended network setup or else we silently exit.
if [ "$1" = "boot" ]; then
  if [ "x$DRIVER" = "x" -o "x$INTERFACE" = "x" -o "$ENET_MODE" = "ask" ]; then
    exit 2
  elif [ "$ENET_MODE" = "static" ] && [ "x$IPADDR" = "x" -o "x$NETMASK" = "x" ]; then
    exit 2
  fi
fi

# If the cmdline provided the name of a driver, load it;
# Alternatively check if the user ran "network" before running "setup";
# We need an interface:
#
if [ `cat /proc/net/dev | grep ':' | sed -r "s/^ *//" | cut -f1 -d: | grep -v lo | wc -l` = 0 ]; then
  if [ "x${DRIVER}" != "x" ]; then
    modprobe ${DRIVER} 1>/dev/null 2>/dev/null
  else
    while [ 0 ]; do
      cat << EOF > $TMP/tempmsg

You will now get a chance to probe your network interfaces.

EOF
      dialog --colors --clear \
		--backtitle "Breeze::OS $RELEASE Installer" \
		  --title "PROBING NETWORK DEVICES" \
		  --msgbox "`cat $TMP/tempmsg`" 7 68

      unlink $TMP/tempmsg
      /bin/network --installer
      read -p "Press any key..." JUNK

      sleep 5 # Give dhcpcd a change to probe
      unset JUNK
      cat << EOF > $TMP/tempmsg

Are you OK with the network interface which was detected?
If not, select 'No' to get back to the network probe program.
You can try to load another driver explicitly,
by using "P <driver_name>".

If you are satisfied, select 'Yes' to continue with network configuration.
EOF
      dialog --colors --clear \
		--backtitle "Breeze::OS $RELEASE Installer" \
		  --title "PROBING NETWORK DEVICES" \
		  --yesno "`cat $TMP/tempmsg`" 12 68

      if [ $? = 0 ]; then
        unlink $TMP/tempmsg
        break
      fi
    done
  fi
fi

# If we obtained information from a DHCP server, use it:
if [ "x$INTERFACE" = "x" ]; then # the cmdline did not provide a nic
 for I_I in \
  $(cat /proc/net/dev | grep ':' | sed -r "s/^ *//" | cut -f1 -d: | grep -v lo) ;
 do
  if [ -n $TMP/dhcpcd-${I_I}.info ]; then
    INTERFACE="${I_I}"
    break
  fi
 done
 unset I_I
fi

while [ 0 ]; do
 T_PX="`cat $TMP/SeTT_PX`"
 UPNRUN=1
 if [ "$T_PX" = "/" ]; then
  cat << EOF > $TMP/tempmsg

You're running off the hard drive filesystem. Is this machine
currently running on the network you plan to install from? If
so, we won't try to reconfigure your ethernet card.

Are you up-and-running on the network?
EOF
  dialog --colors --clear \
		--backtitle "Breeze::OS $RELEASE Installer" \
  	--title "NETWORK CONFIGURATION" \
	--yesno "`cat $TMP/tempmsg`" 12 68

  UPNRUN=$?
 fi
 if [ $UPNRUN = 1 ]; then
  ENET_DEVICE=${INTERFACE:-"eth0"} 
  if [ "x$INTERFACE" != "x" ]; then # interface specified via cmdline or dhcpcd
   if [ "$ENET_MODE" = "ask" ]; then
    # Offer to install using DHCP:
    cat << EOF > $TMP/tempmsg

I can configure your network interface $ENET_DEVICE
fully automatically using DHCP.
If you want this, please select 'yes'.

If you select 'no' instead, then you will be able to assign
the IP address, netmask and gateway manually.

EOF
    dialog --colors --clear \
		--backtitle "Breeze::OS $RELEASE Installer" \
    	--title "DHCP CONFIGURATION" \
		--yesno "`cat $TMP/tempmsg`" 12 65

    if [ $? -eq 0 ]; then
     unlink $TMP/tempmsg
     echo $ENET_DEVICE > $TMP/SeTdhcp
    else
     unlink $TMP/SeTdhcp
    fi
   elif [ "$ENET_MODE" = "dhcp" ]; then # Don't ask, just use DHCP
    echo $ENET_DEVICE > $TMP/SeTdhcp
   fi
  fi # End non-empty INTERFACE 

  if [ ! -r $TMP/SeTdhcp ]; then
   # No DHCP configured, so use static IP.
   # If we have all the values ready, don't ask any.
   # Only if the script runs with the "boot" parameter will we silently accept
   # an empty gateway address (if we came this far, we will have IP/netmask):
   if [ "$1" = "boot" -a "x$GATEWAY" = "x" ]; then
    HAVE_GATEWAY=1
    GATEWAY="unspec"
   else
    HAVE_GATEWAY=0
   fi
   if [ "x$IPADDR" = "x" -o "x$NETMASK" = "x" -o "x$GATEWAY" = "x" ]; then
    cat << EOF > $TMP/tempmsg

You will need to enter the IP address you wish to
assign to this machine. Example: 111.112.113.114

What is your IP address?
EOF
    if [ "$LOCAL_IPADDR" = "" ]; then # assign default
     LOCAL_IPADDR=${IPADDR}
    fi

    dialog --colors --clear \
		--backtitle "Breeze::OS $RELEASE Installer" \
    	--title "ASSIGN IP ADDRESS" \
		--inputbox "`cat $TMP/tempmsg`" 12 65 $LOCAL_IPADDR 2> $TMP/local

    if [ ! $? = 0 ]; then
     unlink $TMP/tempmsg
     unlink $TMP/local
     exit
    fi
    LOCAL_IPADDR="`cat $TMP/local`"
    unlink $TMP/local
    cat << EOF > $TMP/tempmsg

Now we need to know your netmask.
Typically this will be 255.255.255.0
but this can be different depending on
your local setup.

What is your netmask?
EOF
    if [ "$LOCAL_NETMASK" = "" ]; then # assign default
     LOCAL_NETMASK=${NETMASK:-255.255.255.0}
    fi

    dialog --colors --clear \
		--backtitle "Breeze::OS $RELEASE Installer" \
    	--title "ASSIGN NETMASK" \
		--inputbox "`cat $TMP/tempmsg`" 14 65 $LOCAL_NETMASK 2> $TMP/mask

    if [ ! $? = 0 ]; then
     unlink $TMP/tempmsg
	 unlink $TMP/mask
     exit
    fi

    LOCAL_NETMASK="`cat $TMP/mask`"
    unlink $TMP/mask
    dialog --colors --clear \
		--backtitle "Breeze::OS $RELEASE Installer" \
    	--yesno "Do you have a gateway?" 5 30
    HAVE_GATEWAY=$?

    if [ "$HAVE_GATEWAY" = "0" ]; then
     if [ "$LOCAL_GATEWAY" = "" ]; then
      if [ "$GATEWAY" = "" ]; then
       LOCAL_GATEWAY="`echo $LOCAL_IPADDR | cut -f1-3 -d '.'`."
      else
       LOCAL_GATEWAY=${GATEWAY}
      fi
     fi

     dialog --colors --clear \
		--backtitle "Breeze::OS $RELEASE Installer" \
     	--title "ASSIGN GATEWAY ADDRESS" --inputbox \
     "\nWhat is the IP address for your gateway?" 9 65 $LOCAL_GATEWAY 2> $TMP/gw

     if [ ! $? = 0 ]; then
      unlink $TMP/tempmsg
	  unlink $TMP/gw
      exit
     fi
     LOCAL_GATEWAY="`cat $TMP/gw`"
     unlink $TMP/gw
    fi
   else
    # Non-interactive run, so we use the values set on the commandline:
    LOCAL_IPADDR=${IPADDR}
    LOCAL_NETMASK=${NETMASK}
    LOCAL_GATEWAY=${GATEWAY}
   fi # end questions asked
  fi # end static ip

  if [ "$ENET_MODE" = "ask" -a ! -r $TMP/SeTdhcp ]; then
   cat << EOF > $TMP/tempmsg

This is the proposed network configuration for $ENET_DEVICE -
If this is OK, then select 'Yes'.
If this is not OK and you want to configure again, select 'No'.

* IP Address: $LOCAL_IPADDR 
* Netmask:    $LOCAL_NETMASK
EOF
   if [ "$HAVE_GATEWAY" = 0 ]; then
    echo "* Gateway:    $LOCAL_GATEWAY" >> $TMP/tempmsg
   fi 
   echo "" >> $TMP/tempmsg
   dialog --colors --clear \
		--backtitle "Breeze::OS $RELEASE Installer" \
   	--no-collapse --title "NETWORK CONFIGURATION" \
	--yesno "`cat $TMP/tempmsg`" 14 68

   if [ $? -eq 1 ]; then
    continue # New round of questions
   fi
  fi # end ask approval for ip config

  #echo "Configuring ethernet card..."
  dialog --title "INITIALIZING NETWORK" --infobox \
		--backtitle "Breeze::OS $RELEASE Installer" \
  	"\nConfiguring your network interface $ENET_DEVICE ..." 5 56

  if [ -r $TMP/SeTdhcp ]; then
   dhcpcd -k $ENET_DEVICE 1>/dev/null 2>&1 # Or else the '-T' will be used next:
   sleep 3
   dhcpcd $ENET_DEVICE
  else
   dhcpcd -k $ENET_DEVICE 1>/dev/null 2>&1 # We don't need it now
   # Broadcast and network are derived from IP and netmask:
   LOCAL_BROADCAST=`ipmask $LOCAL_NETMASK $LOCAL_IPADDR | cut -f 1 -d ' '`
   LOCAL_NETWORK=`ipmask $LOCAL_NETMASK $LOCAL_IPADDR | cut -f 2 -d ' '`
   ifconfig $ENET_DEVICE $LOCAL_IPADDR netmask $LOCAL_NETMASK broadcast $LOCAL_BROADCAST

   if [ "$HAVE_GATEWAY" = "0" ]; then
    #echo "Configuring your gateway..."
    route add default gw $LOCAL_GATEWAY metric 1
   fi

   echo $LOCAL_IPADDR > $TMP/selected-ip-address
   echo $LOCAL_NETMASK > $TMP/selected-netmask
   echo $LOCAL_GATEWAY > $TMP/selected-gateway
  fi
 fi # ! UPNRUN

 break

done
echo $UPNRUN > $TMP/SeTupnrun

# Basic initialisation completed. Let's see what the commandline has for us:
# If we know of a remote configuration file, get it now:
# Provide comma-separated values (protocol,remoteserver[:portnumber],configfile)
# like this example: 'cf=tftp,192.168.0.22,/slackware-12.1/configs/t43.cfg'
#
#for CMDELEM in $(cat /proc/cmdline) ; do
# if $(echo $CMDELEM | grep -q "^cf=") ; then
#  CONFIGFILE=$(echo $CMDELEM | cut -f2 -d=)
#  PROTO=$(echo $CONFIGFILE | cut -f1 -d,)
#  MASTER=$(echo $CONFIGFILE | cut -f2 -d,)
#  CONFIGFILE=$(echo $CONFIGFILE | cut -f3 -d,)
#  dialog --title "FETCHING CONFIGURATION" --infobox \
#   "\nAttempting to fetch a remote configuration file using $PROTO ..."54 56
# fi
#
done

exit 0

