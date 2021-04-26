#!/bin/bash
#
# GNU GENERAL PUBLIC LICENSE Version 3
#
# Copyright 1994, 1998, 2000  Patrick Volkerding, Concord, CA, USA 
# Copyright 2001, 2003  Slackware Linux, Inc., Concord, CA, USA
# Copyright 2007, 2009  Patrick Volkerding, Sebeka, MN, USA 
# All rights reserved.
#
# Modified by <dev@tsert.com>
# Copyright 2015, Pierre Innocent, Tsert Inc. All Rights Reserved
#
# Initialize folder paths
. d-dirpaths.sh

MODE="$1"

# Remove extra whitespace
lcrunch() {
  while read line; do
    echo $line
  done
}

INPUT="L"

# main loop:
while [ 0 ]; do

# Clear "card found" flag:
unlink $TMP/cardfound 1> /dev/null 2>&1

if [ "$MODE" = "dialog" ]; then
	dialog --colors \
		--backtitle "Breeze::OS $RELEASE Installer" \
		--title "Breeze::OS Setup -- Network Configuration" \
		--inputbox "\nPress [enter] to automatically probe for all network cards,\n\
	or switch to a different console and use \Z1modprobe\Zn to load\n\
	the modules manually.\n\n\
	To skip probing some modules (in case of hangs), enter them after an S:\n\
	   S eepro100 ne2k-pci\n\n\
	To probe only certain modules, enter them after a P like this:\n\
	   P 3c503 3c505 3c507\n\n\
	To get a list of network modules, enter an L.\n\
	To skip the automatic probe entirely, press ESC now.\n" 20 75 2> $TMP/retcode

	if [ "$?" != 0 ]; then
		exit 0
	fi
	clear
	INPUT="`cat $TMP/retcode`"
fi

if [ "`echo $INPUT | lcrunch | cut -f 1 -d ' '`" = "L" \
     -o "`echo $INPUT | lcrunch | cut -f 1 -d ' '`" = "l" ]; then

  echo "Available network modules:"

  for file in /lib/modules/`uname -r`/kernel/drivers/net/* /lib/modules/`uname -r`/kernel/drivers/net/ethernet/* /lib/modules/`uname -r`/kernel/drivers/net/ethernet/*/* /lib/modules/`uname -r`/kernel/arch/i386/kernel/* /lib/modules/`uname -r`/kernel/arch/x86/kernel/* /lib/modules/`uname -r`/kernel/drivers/pnp/* ; do

    if [ -r "$file" ]; then
      OUTPUT="`basename $file .gz`"
      OUTPUT="`basename $OUTPUT .o`"
      echo -n "$OUTPUT "
    fi
  done
  echo
  echo
  if [ "$MODE" = "noprompt" ]; then
	continue
  else
	INPUT=""
  fi
fi

if [ ! "$INPUT" = "q" -a ! "$INPUT" = "Q"  \
     -a ! "`echo $INPUT | lcrunch | cut -f 1 -d ' '`" = "P" \
     -a ! "`echo $INPUT | lcrunch | cut -f 1 -d ' '`" = "p" ]; then
  echo "Probing for PCI/EISA network cards:"

  for card in \
    3c59x acenic de4x5 dgrs eepro100 e1000 e1000e e100 epic100 hp100 ne2k-pci olympic pcnet32 rcpci 8139too 8139cp tulip via-rhine r8169 atl1e sktr yellowfin tg3 dl2k ns83820 \
    ; do
    SKIP=""
    if [ "`echo $INPUT | lcrunch | cut -f 1 -d ' '`" = "S" \
         -o "`echo $INPUT | lcrunch | cut -f 1 -d ' '`" = "s" ]; then
      for nogood in `echo $INPUT | lcrunch | cut -f 2- -d ' '` ; do
        if [ "$card" = "$nogood" ]; then
          SKIP=$card
        fi
      done
    fi
    if [ "$SKIP" = "" ]; then
      echo "Probing for card using the $card module..."
      modprobe $card 2> /dev/null
      grep -q eth0 /proc/net/dev
      if [ $? = 0 ]; then
        echo
        echo "Found card using $card protocol -- modules loaded."
        echo "$card" > $TMP/cardfound
	  	echo "INSTALLER: SUCCESS"
        echo
        break
      else
        modprobe -r $card 2> /dev/null
      fi
    else
      echo "Skipping module $card..."
    fi
  done

  echo

  if [ ! -r $TMP/cardfound ]; then
    # Don't probe for com20020... it loads on any machine with or without the card.
    echo "Probing for MCA, ISA, and other PCI network cards:"
    # removed because it needs an irq parameter: arlan
    # tainted, no autoprobe: (arcnet) com90io com90xx
    for card in depca ibmtr 3c501 3c503 3c505 3c507 3c509 3c515 ac3200 \
      acenic at1700 cosa cs89x0 de4x5 de600 \
      de620 e2100 eepro eexpress es3210 eth16i ewrk3 fmv18x forcedeth hostess_sv11 \
      hp-plus hp lne390 ne3210 ni5010 ni52 ni65 sb1000 sealevel smc-ultra \
      sis900 smc-ultra32 smc9194 wd ; do 
      SKIP=""
      if [ "`echo $INPUT | lcrunch | cut -f 1 -d ' '`" = "S" \
           -o "`echo $INPUT | lcrunch | cut -f 1 -d ' '`" = "s" ]; then
        for nogood in `echo $INPUT | lcrunch | cut -f 2- -d ' '` ; do
          if [ "$card" = "$nogood" ]; then
            SKIP=$card
          fi
        done
      fi
      if [ "$SKIP" = "" ]; then
        echo "Probing for card using the $card module..."
        modprobe $card 2> /dev/null
        grep -q eth0 /proc/net/dev
        if [ $? = 0 ]; then
          echo
          echo "Found card using $card protocol -- modules loaded."
          echo "$card" > $TMP/cardfound
	  	  echo "INSTALLER: SUCCESS"
          echo
          break
        else
          modprobe -r $card 2> /dev/null
        fi
      else
        echo "Skipping module $card..."
      fi
    done
    echo
  fi
  if [ ! -r $TMP/cardfound ]; then
    echo "Sorry, but no network card was detected.  Some cards (like non-PCI"
    echo "NE2000s) must be supplied with the I/O address to use.  If you have"
    echo "an NE2000, you can switch to another console (Alt-F2), log in, and"
    echo "load it with a command like this:"
    echo
    echo "  modprobe ne io=0x360"
    echo
  fi
elif [ "`echo $INPUT | lcrunch | cut -f 1 -d ' '`" = "P" \
       -o "`echo $INPUT | lcrunch | cut -f 1 -d ' '`" = "p" ]; then

  echo "Probing for a custom list of modules:"

  for card in `echo $INPUT | lcrunch | cut -f 2- -d ' '` ; do

    echo "Probing for card using the $card module..."
    modprobe $card 2> /dev/null
    grep -F -q eth0 /proc/net/dev

    if [ $? = 0 ]; then
      echo
      echo "Found card using $card protocol -- modules loaded."
      echo "$card" > $TMP/cardfound
	  echo "INSTALLER: SUCCESS"
      echo
      break
    else
      modprobe -r $card 2> /dev/null
    fi
  done
  echo
else
  echo "Skipping automatic module probe."
  echo
fi

# end main loop
break
done

exit 0

