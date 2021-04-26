#!/bin/bash
#
# GNU GENERAL PUBLIC LICENSE Version 3
#
# Copyright 2016 Pierre Innocent, Tsert Inc., All Rights Reserved
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

. d-format-utils.sh

# end Breeze::OS setup script

isa_gpt_drive()
{
  if fdisk -l ${1} | grep -iqF 'Disk label type: gpt' ; then
    return 0
  fi
  return 1
}

keep_drive_settings()
{
  local src="$1"
  local CRYPTO=""
  local total=0

  declare -a entries;

  while read line; do

	IFS=',' read -r -a entries <<< "$line"

    local PARTITION="${entries[0]}"
    local PTYPE="${entries[1]}"
    local SIZE="${entries[2]}"
    local FSTYPE="${entries[3]}"
    local MTPT="${entries[4]}"
    local MODE="${entries[5]}"

    if [ -z "$MTPT" ]; then
      echo_failure "L_NOT_ALL_MOUNTPOINTS_WERE_SPECIFIED"
      exit 1
    fi

    if ! echo "$MTPT" | grep -qF '/' ; then
		MTPT="/$MTPT"
    fi

    if echo "$MTPT" | grep -qF '/target/' ; then
        MTPT="$(echo "$MTPT" | sed -e 's/\/target//g')"
    fi

    track_mountpoint "$DRIVE_ID" \
      "$PARTITION" "$MTPT" "$FSTYPE" "$PTYPE" "$MODE" "$CRYPTO" "$PARTITION"

	total=$(( $total + 1 ))

  done < "$src"

  echo "$total" 1> $TMP/nb-target-partitions

  return 0
}

set_drive_settings()
{
  local device="$1"
  local disksz="$2"
  local ssd="$(is_drive_ssd $device)"
  local memsize="$(probe_memory real $PLATFORM)"

  SWAP_SIZE=1024
  DISK_TYPE="linux"

  if [ "$PLATFORM" = "netbsd" ]; then
    DISK_TYPE="netbsd"
  fi

  lsblk -d -n -o 'model,vendor,rev' "$device" | \
    sed -r 's/[\t ][\t ]*/ /g' 1> $TMP/selected-drive-model

  if test $memsize -lt 512; then
    SWAP_SIZE=1024
  elif test $memsize -lt 750; then
    SWAP_SIZE=2048
  elif test $memsize -lt 1000; then
    SWAP_SIZE=4096
  elif test $memsize -lt 4000; then
    SWAP_SIZE=5120
  else
    SWAP_SIZE=$(( $memsize ))
  fi

  if test $disksz -lt 5000; then
    SWAP_SIZE=256
  elif test $disksz -lt 20000; then
    SWAP_SIZE=512
    elif test $disksz -lt 35000; then
        SWAP_SIZE=768
  elif test $disksz -lt 50000; then
    SWAP_SIZE=1024
  fi

  GPT_MODE="gpt"
  BOOT_SIZE="256"
  SECTOR_SIZE="$(get_sector_size $device)"

  if test $disksz -ge 750000; then
    RESERVED="0"
    SCHEME="root-share"
    BOOT_SIZE="1024"
    GPT_MODE="gpt"

  elif test $disksz -ge 500000; then
    RESERVED="1"
    SCHEME="root-opt"
    BOOT_SIZE="512"
    GPT_MODE="gpt"

  elif test $disksz -ge 250000; then
    RESERVED="2"
    SCHEME="root-srv"

  elif test $disksz -ge 150000; then
    RESERVED="2"
    SCHEME="root-var"
  else
    SCHEME="root-home"
    RESERVED="2"
  fi

  if [ "$ssd" = "yes" ]; then
    GPT_MODE="gpt"
    SECTOR_SIZE="4k"
  fi

  if isa_gpt_drive $device ; then
    GPT_MODE="gpt"
  fi

  return 0
}

keep_home() {

  unlink "$OUTPUT_SCHEME" 2> /dev/null
  touch "$OUTPUT_SCHEME" 2> /dev/null

  unlink $TMP/kepthome-${DRIVE_ID}.csv
  touch $TMP/kepthome-${DRIVE_ID}.csv

  while read line; do

    mtpt="$(echo "$line" | cut -f5 -d',')"

    if [ "$mtpt" = "/home" ]; then
      line="$(echo "$line" | sed -r 's/ignore/keep/g')"
    fi

    echo "$line" >> $OUTPUT_SCHEME
    echo "$line" >> $TMP/kepthome-${DRIVE_ID}.csv

  done < $TMP/kepthome.csv

  return 0
}

# Main starts here ...
DEVICE="$1"

if ! is_valid_device "$DEVICE" ; then
  echo_failure "L_NO_DRIVE_SELECTED"
  exit 1
fi

DRIVE_ID="$(basename $DEVICE)"

if ! is_safemode_drive "$DEVICE" ; then
   echo_failure "L_SAFEMODE_DRIVE_SELECTED !"
   exit 1
fi

DISK_SIZE="$(get_drive_size $DEVICE)"

OUTPUT_SCHEME=$TMP/partitions-${DRIVE_ID}.csv

echo "$DISK_SIZE" 1> $TMP/drive-total
echo "$DISK_SIZE" 1> $TMP/${DRIVE_ID}-drive-total

set_drive_settings $DEVICE $DISK_SIZE

set_drive_mode $DEVICE

if [ "$GPT_MODE" = "gpt" -o "$GPT_MODE" = "uefi" ]; then
  echo "$DEVICE=GPT Partitioned" >> $TMP/gpt-mbr-drives
else
  echo "$DEVICE=MBR Partitioned" >> $TMP/gpt-mbr-drives
fi

#if [ ! -e "$OUTPUT_SCHEME" ]; then
#  cp $TMP/selected-drive-info.csv $OUTPUT_SCHEME
#fi

KEEPDRIVE="$(cat $TMP/selected-keepdrive 2> /dev/null)"

if [ -e $TMP/keepdrive.csv ]; then
  cp $TMP/keepdrive.csv $OUTPUT_SCHEME

  if [ "$KEEPDRIVE" = "yes" ]; then
    echo "$DEVICE" >> $TMP/drives-partitioned.lst
    echo "$DEVICE" >> $TMP/drives-formatted.lst
    keep_drive_settings $TMP/keepdrive.csv
  else
    grep -vF "$DEVICE" $TMP/drives-partitioned.lst > $TMP/dpl
    mv $TMP/dpl $TMP/drives-partitioned.lst
    grep -vF "$DEVICE" $TMP/drives-formatted.lst > $TMP/dfl
    mv $TMP/dfl "$DEVICE" $TMP/drives-formatted.lst
  fi
fi

unlink $TMP/selected-keepdrive 2> /dev/null

EXPERTISE="$(cat $TMP/selected-expertise 2> /dev/null)"

wc -l $TMP/drives-formatted.lst | \
  cut -f1 -d' ' 1> $TMP/nb-target-drives

if [ "$EXPERTISE" = "beginner" ]; then

  cat $BRZDIR/templates/scheme.tpl  | sed \
    -e "s/@DEVICE@/\/dev\/$DRIVE_ID/g" \
    -e "s/@SCHEME@/$SCHEME/g" \
    -e "s/@GPT_MODE@/$GPT_MODE/g" \
    -e "s/@DISK_TYPE@/$DISK_TYPE/g" \
    -e "s/@FSTYPE@/ext4/g" \
    -e "s/@DISK_SIZE@/$DISK_SIZE/g" \
    -e "s/@BOOT_SIZE@/$BOOT_SIZE/g" \
    -e "s/@SWAP_SIZE@/$SWAP_SIZE/g" \
    -e "s/@SECTOR_SIZE@/$SECTOR_SIZE/g" \
    -e "s/@ENCRYPTED@/no/g" \
    -e "s/@RESERVED@/$RESERVED/g" \
    -e "s/@LUKSPFX@/luks/g" \
  1> $TMP/scheme-${DRIVE_ID}.map
fi

echo "INSTALLER: SUCCESS"
exit 0

# end Breeze::OS setup script
