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

probe_system_mobo()
{
  local company="$(grep -i manufac $1 | cut -f2 -d':' | crunch)"
  local product="$(grep -i product $1 | cut -f2 -d':' | crunch)"
  local serial="$(grep -i serial $1 | cut -f2 -d':' | crunch)"
  local chassis="$(grep -i 'chassis handle' $1 | cut -f2 -d':' | crunch)"

  echo "$company" > $TMP/detected-mobo-company
  echo "$product" > $TMP/detected-mobo-prodname
  echo "$chassis" > $TMP/detected-mobo-chassis
  echo "$serial" > $TMP/detected-mobo-serialnb

  return 0
}

probe_system_cpu()
{
  local version="$(grep -i version $1 | cut -f2 -d':' | crunch)"
  local family="$(grep -i family $1 | cut -f2 -d':' | crunch)"
  local corenb="$(grep -i 'core count' $1 | cut -f2 -d':' | crunch)"
  local socketnb="$(grep -i socket $1 | cut -f2 -d':' | crunch)"

  echo "$version" > $TMP/detected-cpu-version
  echo "$family" > $TMP/detected-cpu-family
  echo "$corenb" > $TMP/detected-cpu-corenb
  echo "$socketnb" > $TMP/detected-cpu-socket

  return 0
}

probe_system_memory()
{
  local freemem="$(probe_memory free $PLATFROM)"
  local realmem="$(probe_memory real $PLATFROM)"
  local usedmem=$(( $realmem - $freemem ))

  echo "$freemem" > $TMP/detected-free-memory
  echo "$realmem" > $TMP/detected-real-memory
  echo "$usedmem" > $TMP/detected-used-memory

  return 0
}

probe_devices()
{
  LSPCI="$(which lspci)"
  LSCPU="$(which lscpu)"

  if [ "$PLATFORM" = "freebsd" ]; then
    pciconf -lv 1> $TMP/lspci.log
  elif [ -n "$LSPCI" ]; then
    $LSPCI 1> $TMP/lspci.log
  else
    lspci 1> $TMP/lspci.log
  fi

  if [ -n "$LSCPU" ]; then
    $LSCPU 1> $TMP/lscpu.log
  else
    lscpu 1> $TMP/lscpu.log
  fi

  if [ "$PLATFORM" = "freebsd" ]; then
    xinput --list | grep -i -m 1 'mouse' 1> $TMP/proc.log
  else
    cat /proc/bus/input/devices | \
      grep -iE 'name=.*(mouse|keyboard)' 1> $TMP/proc.log
  fi

  local vga="$(grep -iF -m1 'vga compatible controller' $TMP/lspci.log)"
  local dram="$(grep -iF -m1 'dram controller' $TMP/lspci.log)"
  local eth0="$(grep -iF -m1 'ethernet controller' $TMP/lspci.log)"
  local media="$(grep -iF -m1 'multimedia controller' $TMP/lspci.log)"
  local audio="$(grep -iF -m1 'audio device' $TMP/lspci.log)"
  local memory="$(grep -iF -m1 'RAM Memory' $TMP/lspci.log)"

  local cpuarch="$(grep -iE -m1 '^Architecture' $TMP/lscpu.log)"
  local cpucore="$(grep -iE -m1 '^CPU[(]s[)]:' $TMP/lscpu.log)"
  local cpuopmode="$(grep -iE -m1 '^CPU op' $TMP/lscpu.log)"
  local cpuvendor="$(grep -iE -m1 '^Vendor' $TMP/lscpu.log)"
  local keyboard="$(grep -iF keyboard $TMP/proc.log | sed -r 's/^.*Name=//g')"
  local mouse="$(grep -iF mouse $TMP/proc.log | sed -r 's/^.*Name=//g')"

  echo "No mouse device detected" 1> $TMP/detected-device-mouse
  echo "No modem device detected" 1> $TMP/detected-device-modem
  echo "No keyboard device detected" 1> $TMP/detected-device-keyboard
  echo "No wireless adapter detected" 1> $TMP/detected-wireless-adapter

  vga="$(echo "$vga" | sed -r 's/^.*://g')"
  dram="$(echo "$dram" | sed -r 's/^.*://g')"
  media="$(echo "$media" | sed -r 's/^.*://g')"
  audio="$(echo "$audio" | sed -r 's/^.*://g')"
  eth0="$(echo "$eth0" | sed -r 's/^.*://g')"

  if [ -n "$eth0" ]; then
    eth0="$(echo "$eth0" | sed -r 's/\//_/g')"
    eth0="$(echo "$eth0" | sed -r 's/Ethernet [cC]ontroller.*$//g')"
    echo "$eth0" 1> $TMP/detected-eth-controller
  fi

  if [ -n "$dram" ]; then
    dram="$(echo "$dram" | sed -r 's/\//_/g')"
    dram="$(echo "$dram" | sed -r 's/DRAM [cC]ontroller.*$//g')"
    echo "$dram" 1> $TMP/detected-dram-controller
  fi

  if [ -n "$vga" ]; then
    vga="$(echo "$vga" | sed -r 's/\//_/g')"
    vga="$(echo "$vga" | sed -r 's/Graphics [cC]ontroller.*$//g')"
    echo "$vga" 1> $TMP/detected-vga-controller
  fi

  if [ -n "$media" ]; then
    media="$(echo "$media" | sed -r 's/\//_/g')"
    media="$(echo "$media" | sed -r 's/[(]rev.*$//g')"
    echo "$media" 1> $TMP/detected-device-mmedia
  fi

  if [ -z "$audio" ]; then
    media="$(echo "$media" | sed -r 's/Audio [cC]ontroller.*$//g')"
    echo "$media" 1> $TMP/detected-device-audio
  else
    audio="$(echo "$audio" | sed -r 's/\//_/g')"
    audio="$(echo "$audio" | sed -r 's/Audio [cC]ontroller.*$//g')"
    echo "$audio" 1> $TMP/detected-device-audio
  fi

  if [ -n "$keyboard" ]; then
    keyboard="$(echo "$keyboard" | sed -r 's/"//g')"
    echo "$keyboard" 1> $TMP/detected-device-keyboard
  fi

  if [ -n "$mouse" ]; then
    if [ "$PLATFORM" = "freebsd" ]; then
      mouse="$(cat $TMP/proc.log | sed -r 's/id.*$//g' | crunch)"
    else
      mouse="$(echo "$mouse" | sed -r 's/"//g')"
      mouse="$(echo "$mouse" | sed -r 's/^[^a-zA-Z0-9]*//g')"
      mouse="$(echo "$mouse" | sed -r 's/[(]rev.*$//g')"
    fi
    echo "$mouse" 1> $TMP/detected-device-mouse
  fi

  if [ -n "$memory" ]; then
    memory="$(echo "$memory" | sed -r 's/^.*://g')"
    memory="$(echo "$memory" | sed -r 's/[(]rev.*$//g')"
    echo "$memory" 1> $TMP/detected-ram-controller
  fi

  if [ -n "$cpuarch" ]; then
    cpuarch="$(echo "$cpuarch" | sed -r 's/^.*://g')"
    echo "$cpuarch" 1> $TMP/detected-cpu-arch
  fi

  if [ -n "$cpuvendor" ]; then
    cpuvendor="$(echo "$cpuvendor" | sed -r 's/^.*://g')"
    echo "$cpuvendor" 1> $TMP/detected-cpu-vendor
  fi

  if [ -n "$cpuopmode" ]; then
    cpuopmode="$(echo "$cpuopmode" | sed -r 's/^.*://g')"
    echo "$cpuopmode" 1> $TMP/detected-cpu-opmode
  fi

  if [ -n "$cpucore" ]; then
    cpucore="$(echo "$cpucore" | sed -r 's/^.*://g')"
    echo "$cpucore" 1> $TMP/detected-cpu-cores
  fi

  if [ ! -s $TMP/displaymgr.map ]; then
    d-displaymgr.sh drivers
  fi

  $DMIDECODE -t baseboard | \
    egrep -i 'serial|chassis|product|manufacturer' 1> $TMP/system-mobo

  $DMIDECODE -t processor | \
    egrep -i 'version|core|socket|family' 1> $TMP/system-cpu

  return 0
}

probe_network_devices()
{
  lspci 1> $TMP/lspci.log

  local modem="$(grep -iF -m1 'Communication controller' $TMP/lspci.log)"
  local wifi="$(grep -iF -m1 'WLAN Adapter' $TMP/lspci.log)"

  modem="$(echo "$modem" | sed -r 's/^.*://g')"
  wifi="$(echo "$wifi" | sed -r 's/^.*://g')"

  if [ "$modem" != "" ]; then
    modem="$(echo "$modem" | sed -r 's/[\/]/_/g')"
    modem="$(echo "$modem" | sed -r 's/[(]rev.*$//g')"
    echo "$modem" 1> $TMP/detected-device-modem
  fi

  if [ "$wifi" != "" ]; then
    wifi="$(echo "$wifi" | sed -r 's/^.*://g')"
    wifi="$(echo "$wifi" | sed -r 's/^[^ ]*//g')"
    wifi="$(echo "$wifi" | sed -r 's/[(]rev.*$//g')"
    wifi="$(echo "$wifi" | sed -r 's/WLAN Adapter//g')"
    echo "$wifi" 1> $TMP/detected-wireless-adapter
  fi

  return 0
}

probe_source_media()
{
  local pkgtype="$(cat $TMP/selected-pkgtype 2> /dev/null)"
  local installmode="$(cat $TMP/selected-install-mode 2> /dev/null)"
  local livemedia="$(cat $TMP/livemedia-marker 2> /dev/null)"

  if [ "$installmode" = "network" ]; then
    echo "yes" > $TMP/extended-install-mode
  else
    echo_message "L_AUTO_SRCMEDIA_PROBING"
    echo "no" > $TMP/extended-install-mode

    if ! d-list-drives.sh source install ; then
      echo "yes" 1> $TMP/extended-install-mode
      echo_message "L_MANUAL_SRCMEDIA_PROBING"
    fi

    if [ "$pkgtype" = "install" -o "$pkgtype" = "package" ]; then
      if [ -n "$livemedia" -a -e "$livemedia" ] || [ -e /BRZLIVE ]; then
        echo_message "L_NETWORK_SRCMEDIA_SELECTED"
        echo "yes" > $TMP/extended-install-mode
        echo "network" > $TMP/selected-install-mode
      fi
    fi
  fi

  sync; sleep 1
  return 0
}

# Causes some slowdown when invoking blkid.
# There is no need for floppies anyways !
unlink /dev/fd 2> /dev/null
rm -f /dev/fd0* 2> /dev/null

if [ -e /usr/sbin/dmidecode ]; then
  DMIDECODE=/usr/sbin/dmidecode
else
  DMIDECODE=dmidecode
fi

if [ "$1" = "source" ]; then
  probe_source_media
elif [ "$1" = "network" ]; then
  probe_network_devices
else
  probe_devices
  probe_system_cpu $TMP/system-cpu
  probe_system_mobo $TMP/system-mobo
  probe_system_memory
fi

exit 0

# end Breeze::OS setup script
