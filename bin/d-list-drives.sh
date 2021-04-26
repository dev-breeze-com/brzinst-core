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
# Initialize folder paths
. d-dirpaths.sh

check_exists() {

    local idx=1
    local count="$1"
    local serial="$2"

    while test $idx -le $count; do
        eval result="\$serials$idx"

        if $(echo "$result" | grep -F -q "$serial") ; then
            return 0
        fi
        idx=$(( $idx + 1 ))
    done
    return 1
}

list_drives() {

    local size=0
    local count=1
    local cdrom=0
    local srcdev=""
    local devlabel=""
    local filename="$1"
    local argument="$2"
    local install_media=false
    local patterns="INSTALL_DVD_1|BRZINSTALL|BRZLIVE|LIVEBRZ"

    ls -l /dev/disk/by-id/ | grep -F -v part 1> $TMP/by-id.log
    lsblk -d -n -l -o 'kname,rm,type,model,vendor' 1> $TMP/lsblk.log
    sed -i "s/[ ][ ]*/ /g" $TMP/lsblk.log

    while read line; do

        devname="$(echo "$line" | cut -f1 -d ' ')"
        by_id="$(grep -m1 -F "/$devname" $TMP/by-id.log)"
        serial="$(echo "$by_id" | cut -f2 -d: | cut -f2 -d' ')"

        device="/dev/$devname"
        removable="$(echo "$line" | cut -f 2 -d ' ')"
        dtype="$(echo "$line" | cut -f 3 -d ' ')"

        install_media=false

        if echo "$devname" | grep -iqE '(ram|loop)[0-9]' ; then
            continue
        fi

        if [ "$argument" = "target" ]; then
			if ! grep -qF "$devname" $TMP/drives-formatted.lst ; then
				continue
			fi
        fi

        if [ "$DISKTYPE" = "lvm" ]; then
            if [ "$dtype" = "rom" ]; then
                continue
            fi

            if ! has_lvm_partition $device ; then
                continue
            fi

            if ! was_lvm_partitioned $device ; then
                continue
            fi
        fi

        if [ "$argument" = "target" -o "$argument" = "drives" ]; then
            if [ "$device" = "$SOURCE" ]; then
                if [ "$MEDIA" = "$SOURCE_MEDIA" ]; then
                    SOURCE_MEDIA="same"
                fi
                continue
            fi
        fi

        if [ "$dtype" = "disk" ]; then
            model="$(echo "$line" | sed 's/^.*disk //g')"
        else
            model="$(echo "$line" | sed 's/^.*rom //g')"
        fi

        model="$(echo "$model" | sed 's/[ ][ ]*/ /g')"
        model="$(echo "$model" | sed 's/^WDC //g')"
        model="$(echo "$model" | sed 's/[ ][ ]*/_/g')"

        hdd_sz="$(grep -E "$device[^0-9]" $TMP/all-disks)"

        devlabel="$(lsblk -pnlo kname,label $device)" #| grep -E "$patterns")"
        brzlive="$(echo "$devlabel" | grep BRZLIVE | crunch)"

        if [ -n "$brzlive" ]; then
            srcdev="$(echo "$brzlive" | crunch | cut -f1 -d' ')"
            devlabel="$(echo "$brzlive" | crunch | cut -f2 -d' ')"
            echo "squashfs" 1> $TMP/selected-pkgtype
        else
            brzinstall="$(echo "$devlabel" | grep BRZINSTALL | crunch)"

            if [ -n "$brzinstall" ]; then
                srcdev="$(echo "$brzinstall" | crunch | cut -f1 -d' ')"
                devlabel="$(echo "$brzinstall" | crunch | cut -f2 -d' ')"
                echo "install" 1> $TMP/selected-pkgtype
            else
                devlabel=""
            fi
        fi

        if [ -n "$devlabel" ]; then
            install_media=true
        else
            srcdev=""
        fi

        if [ "$MEDIA" = "INSTALL" -a "$argument" = "source" ]; then
            if [ "$install_media" = true ]; then
                if [ "$dtype" = "rom" -a -n "$srcdev" ]; then
                    if d-set-source.sh 'cdrom' "$srcdev" "auto" ; then
                        exit 0
                    fi
                elif [ "$removable" = "1" -a -n "$srcdev" ]; then
                    if d-set-source.sh 'flash' "$srcdev" "auto" ; then
                        exit 0
                    fi
                fi
            fi
            continue
        fi

        if [ "$MEDIA" = "FLASH" -o "$argument" != "source" ]; then
            if [ "$argument" = "target" ]; then
                if [ "$install_media" = true ]; then
                    eval serials$count=\"$device,$dtype,$serial\"
                    continue
                fi
            elif [ "$install_media" = false -a "$argument" = "source" ] || \
                [ "$install_media" = true -a "$argument" != "source" ]; then
                eval serials$count=\"$device,$dtype,$serial\"
                continue
            elif [ "$MEDIA" = "FLASH" ] && \
                [ "$dtype" != "disk" -o "$removable" != "1" -o -z "$hdd_sz" ]; then
                eval serials$count=\"$device,$dtype,$serial\"
                continue
            fi
        elif [ "$MEDIA" = "CDROM" -o "$argument" != "source" ]; then

            if [ "$removable" != "1" ] || \
                [ -n "$srcdev" -a "$argument" = "source" ] || \
                [ ! -z "$hdd_sz" -a "$dtype" != "rom" ]; then
                eval serials$count=\"$device,$dtype,$serial\"
                continue
            fi

            if check_exists $count $serial ; then
                eval serials$count=\"$device,$dtype,$serial\"
                continue
            fi
        fi

        if [ -z "$hdd_sz" -o "$dtype" = "rom" ]; then

            if [ "$MEDIA" = "DISK" -o "$argument" != "source" ]; then
                eval serials$count=\"$device,$dtype,$serial\"
                continue
            fi

            echo "$device=CDROM" >> $TMP/drives
            echo "$devname) $model (CDROM)=$device" >> $TMP/${media}-drives.map

            if [ "$argument" = "cdroms" ]; then
                echo "$device /media/cdrom$cdrom" >> $TMP/detected-cdroms
                cdrom=$(( $cdrom + 1 ))
            fi
            count=$(( $count + 1 ))
        else
            echo "$device=DISK" >> "$TMP/drives"

            size="$(echo "$hdd_sz" | sed 's/.*[ ][ ]*//g')"
            size=$(( size / 1000 / 1000 / 1000 ))

            echo "$devname) $model [${size}G]=$device" >> $TMP/${media}-drives.map
            count=$(( $count + 1 ))
        fi

        eval serials$count=\"$device,$dtype,$serial\"
    done < $TMP/lsblk.log

    if [ "$count" -lt 1 -a "$argument" = "source" ]; then
        return 1
    fi

    return 0
}

# Main starts here ...
ARGUMENT="$1"
media="$2"
MEDIA="$2"
DISKTYPE="$3"

PLATFORM="$(cat $TMP/selected-platform 2> /dev/null)"

if [ "$ARGUMENT" = "source" ]; then
    unlink $TMP/selected-source 2> /dev/null
    unlink $TMP/selected-source-media 2> /dev/null
else
    SOURCE="$(cat $TMP/selected-source 2> /dev/null)"
    SOURCE_MEDIA="$(cat $TMP/selected-source-media 2> /dev/null)"
    SOURCE_MEDIA="$(echo "$SOURCE_MEDIA" | tr '[:lower:]' '[:upper:]')"
fi

if [ -z "$MEDIA" ]; then
    media="disk"
    MEDIA="DISK"
else
    if [ "$media" = "usb" -o "$media" = "zip" ]; then
        media="flash"
    fi
    media="$(echo "$media" | tr '[:upper:]' '[:lower:]')"
    MEDIA="$(echo "$media" | tr '[:lower:]' '[:upper:]')"
fi

if [ "$ARGUMENT" = "all" ]; then
    lsblk -nl -o 'kname,rm,type,fstype,uuid' | \
        grep -F 'part' | grep -F '-' | grep -E -v 'swap' | \
        sed -r 's/[ ][ ]*/ /g' 1> $TMP/fstab-all
    exit 0
fi

unlink $TMP/${media}-drives.map 1> /dev/null 2> /dev/null
touch $TMP/${media}-drives.map

unlink $TMP/drives 1> /dev/null 2> /dev/null
touch $TMP/drives

if [ "$ARGUMENT" = "cdroms" ]; then
    unlink $TMP/detected-cdroms 1> /dev/null 2> /dev/null
    touch $TMP/detected-cdroms 1> /dev/null 2> /dev/null
fi

unlink $TMP/kept-partitions.csv 1> /dev/null 2> /dev/null

if [ "$PLATFORM" = "openbsd" ]; then
    sysctl hw.disknames 1> $TMP/all-disks 2> /dev/null
elif [ "$PLATFORM" = "freebsd" -o "$PLATFORM" = "netbsd" ]; then
    sysctl kern.disks 1> $TMP/all-disks 2> /dev/null
else
    lsblk -p -n -b -d -l -o 'kname,size' 1> $TMP/all-disks
    lsblk -p -n -b -d -l -o 'kname,model' | sed 's/[ ]/=/' 1> $TMP/all-models
fi

sed -i "s/[ ][ ]*/ /g" $TMP/all-disks

if [ "$?" != 0 ]; then 
    echo_failure "L_LSBLK_FAILURE"
    exit 1
fi

list_drives $TMP/all-drives "$ARGUMENT"

if [ "$?" = 0 ]; then
    if [ -s "$TMP/${media}-drives.map" ]; then
        if [ "$ARGUMENT" = "target" ]; then
            OUTPUT_SCHEME=$TMP/partitions-${DRIVE_ID}.csv
            if [ -s $OUTPUT_SCHEME ]; then
                wc -l "$OUTPUT_SCHEME" | cut -f1 -d' ' 1> $TMP/nb-${DRIVE_ID}-partitions
            fi
        fi

        if [ "$ARGUMENT" != "source" ]; then
            if [ "$ARGUMENT" = "savekeys" ]; then
                if [ -s $TMP/${media}-drives.map ]; then
                    cp $TMP/${media}-drives.map $TMP/${media}-crypto-drives
                else
                    echo_error "L_NO_FLASH_DRIVES_FOUND"
                    sync; sleep 1
                fi
            elif [ "$DISKTYPE" = "lvm" ]; then
                if [ -s $TMP/${media}-drives.map ]; then
                    cp $TMP/${media}-drives.map $TMP/lvm-target-drives
                else
                    echo_error "L_MUST_PARTITION_DRIVES"
                    sync; sleep 1
                fi
            fi
            cat $TMP/${media}-drives.map
            sync
        fi
        exit 0
    fi

    if [ "$SOURCE_MEDIA" = "same" ]; then
        echo_failure "L_CANNOT_FORMAT_SRC_DRIVE"
        exit 1
    fi
fi

if [ "$ARGUMENT" = "source" ]; then
    if [ "$MEDIA" = "INSTALL" ]; then
        echo "INSTALLER: WARNING L_NO_VALID_MEDIA_FOUND"
        sync; sleep 3
    elif [ "$MEDIA" = "FLASH" -o "$MEDIA" = "CDROM" ]; then
        echo_failure "L_NO_VALID_${MEDIA}_FOUND"
    else
        echo_failure "L_NO_${MEDIA}_INSTALLED"
    fi
fi

exit 1

# end Breeze::OS setup script
