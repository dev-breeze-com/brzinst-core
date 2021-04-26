#!/bin/bash
#
# GNU GENERAL PUBLIC LICENSE Version 3
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

bootstrap()
{
  local rootdir="$1"
  local repository="$(cat $TMP/selected-source-path 2> /dev/null)"

  if [ "$MEDIA" = "CDROM" -o "$MEDIA" = "FLASH" -o "$MEDIA" = "DISK" ]; then
    if [ "$PKGTYPE" = "package" -o "$PKGTYPE" = "install" ]; then
      echo_message "L_BOOTSTRAPPING_PACKAGE_INSTALLATION"

      brzpkg --yes -q -f -T $rootdir -L $repository \
        -Xinstall -Xprevious -u "stable:$ARCH:$DESKTOP"

      if [ $? != 0 ]; then
        return 1
      fi
    fi
  fi

  echo "$repository" 1> $TMP/selected-repository
  return 0
}

select_path()
{
  local path="$(cat $TMP/selected-source-path 2> /dev/null)"

  if [ -z "$2" ]; then
    path="$1/$path"
  else
    path="$2/$path"
  fi

  path="$(echo "$path" | sed 's/[\/][/]+/\//g')"

  if [ -d "$path" -a -f "$path/distfiles/metadata.tgz" ]; then
    echo "$path" 1> $TMP/selected-source-path
    return 0
  fi

  if [ -h "$path" ]; then
    path="$(readlink path)"

    if [ -d "$path" -a -f "$path/distfiles/metadata.tgz" ]; then
      echo "$path" 1> $TMP/selected-source-path
      return 0
    fi
  fi
  return 1
}

check_mount_point()
{
  local device="$1"
  local mtpt="$2"

  if cat /proc/mounts /etc/mtab | grep -qF " $mtpt " ; then
    local label="$(blkid -s LABEL -o value $device)"

    if [ "$mtpt" = "/mnt/livemedia" ]; then
      if [ "$label" = "BRZLIVE" -o "$label" = "LIVEBRZ" ]; then
        return 0
      fi
      if [ "$label" = "BRZINSTALL" -o "$label" = "INSTALLBRZ" ]; then
        return 0
      fi
    fi

    umount $mtpt 1> /dev/null 2> $TMP/umount.errlog
    sync; sleep 1
  fi
  return 1
}

check_install_media()
{
  local media="$1"
  local device="$2"
  local mtpt="$3"

  if check_mount_point "$2" "$3" ; then
    return 0
  fi

  if [ "$media" = "DISK" ]; then
    if cat /proc/mounts | grep -qF "$device " ; then
      MTPT="$(cat /proc/mounts | grep -F $device | cut -f2 -d' ')"
      return 0
    fi
  fi

  if [ "$media" = "CDROM" ]; then
    mount -o ro -t iso9660 $device $mtpt \
      1> /dev/null 2> $TMP/mount.errlog
  else
    mount -o ro $device $mtpt \
      1> /dev/null 2> $TMP/mount.errlog
  fi

  if [ "$?" != 0 ]; then
    echo_warning "L_MOUNTING_${media}_FAILURE"
    exit 1
  fi

  sync; sleep 1

  if check_mount_point "$2" "$3" ; then
    return 0
  fi

  return 1
}

check_os_release()
{
  local rootdir="$1"
  local mtpt="$(cat $TMP/selected-source-path 2> /dev/null)"

  echo_message "L_CHECKING_${MEDIA}_MEDIA"

  if [ "$MEDIA" = "NETWORK" ]; then
     if [ -f $rootdir/etc/brzpkg/os-release ]; then
         return 0
     fi
  fi

  local osrelease="$mtpt/distfiles/os-release"
  local lsbrelease="$mtpt/distfiles/lsb-release"
  local pkglist=$TMP/pkglist.lst
  local found=false

  if [ -e "$mtpt/boot/KERNEL" ]; then
      cat $mtpt/boot/KERNEL 1> $TMP/selected-kernel
  fi

  if [ -e "$mtpt/boot/KERNEL_VERSION" ]; then
      cat $mtpt/boot/KERNEL_VERSION 1> $TMP/selected-kernel-version
  fi

  if [ -f "$osrelease" ]; then

    cp $osrelease $TMP/ 2> /dev/null
    cp $lsbrelease $TMP/ 2> /dev/null

    for t in 1 2 3 4 5; do
      if grep -qE '^NAME=Breeze::OS' $osrelease ; then
          found=true
          break
      fi
      sync
    done
  fi

  if [ "$found" = false ]; then
    return 1
  fi

  if [ "$PKGTYPE" = "squashfs" ]; then
    find $mtpt -name '*.sxz' 1> $pkglist

    if [ -f "$pkglist" -a -s "$pkglist" ]; then
        unlink $pkglist
        return 0
    fi
  elif [ "$PKGTYPE" = "package" -o "$PKGTYPE" = "install" ]; then
    if [ -e $mtpt/BRZINSTALL -o -e $mtpt/INSTALLBRZ ]; then
        return 0
    fi
    echo_failure "L_INVALID_INSTALL_REPOSITORY"
  fi

  return 1
}

# Main starts here ...
DEVICE="$2"
PROBEMODE="$3"
MEDIA="$(echo "$1" | tr '[:lower:]' '[:upper:]')"

ARCH="$(cat $TMP/selected-arch 2> /dev/null)"
DISTRO="$(cat $TMP/selected-distro 2> /dev/null)"
PKGTYPE="$(cat $TMP/selected-pkgtype 2> /dev/null)"
TARGET="$(cat $TMP/selected-target 2> /dev/null)"

if [ "$PKGTYPE" = "squashfs" ]; then
  patterns="LIVEBRZ|BRZLIVE"
  device="$(lsblk -fsdp | grep -F -m1 "$patterns" | crunch | cut -f1 -d' ')"
else
  patterns="BRZINSTALL|INSTALLBRZ"
  device="$(lsblk -fsdp | grep -E -m1 "$patterns" | crunch | cut -f1 -d' ')"
fi

if [ -n "$DEVICE" -a -n "$device" -a "$DEVICE" != "$device" ]; then
  echo_message "L_SOURCE_MEDIA_MISMATCH"
  DEVICE="$device"
fi

echo "$DEVICE" 1> $TMP/selected-source
echo "$MEDIA" 1> $TMP/selected-source-media

[ -z "$ROOTDIR" ] && ROOTDIR="/target"

ARCH="$(extract_value 'network' 'arch')"
DESKTOP="$(extract_value 'network' 'desktop')"
PKGSRC="$(extract_value 'network' 'source' 'upper')"

if [ "$MEDIA" = "NETWORK" ]; then
  CONNECTION="$(cat $TMP/selected-connection 2> /dev/null)"

  if [ -z "$TARGET" ]; then
    echo_failure "L_TARGET_DRIVE_UNSPECIFIED"
    exit 1
  fi

  if [ "$CONNECTION" = "none" ]; then
    echo_failure "L_NETWORK_CONNECTIONR_REQUIRED"
    exit 1
  fi

  echo_message "L_RETRIEVING_METADATA"

  if [ "$PKGSRC" = "WEB" ]; then
    PKGHOST="$(extract_value 'network' 'mirror')"
  elif [ "$PKGSRC" = "URI" ]; then
    PKGHOST="$(extract_value 'network' 'uri')"
  else
    PKGHOST="http://master.localdomain"
  fi

  if [ -z "$PKGHOST" ]; then
    echo_failure "L_INVALID_PKGHOST"
    exit 1
  fi

  if [ "$PKGHOST" = "downloads.sourceforge.net" ]; then
    PKGHOST="https://downloads.sourceforge.net/project/breezeos"
  elif ! echo "$PKGHOST" | grep -qF 'http' ; then
    PKGHOST="http://$PKGHOST"
  fi

  echo_message "L_BOOTSTRAPPING_PACKAGE_INSTALLATION"

  brzpkg --yes -q -f -T $ROOTDIR -L $PKGHOST \
    -Xinstall -Xprevious -u "stable:$ARCH:$DESKTOP"

  if [ "$?" = 0 ]; then
    echo "NETWORK" 1> $TMP/selected-media
    echo "NETWORK" 1> $TMP/selected-source-media
    echo "$DESKTOP" 1> $TMP/selected-desktop
    echo "$PKGHOST" 1> $TMP/selected-source
    echo "$PKGSRC" 1> $TMP/selected-pkgsrc
    echo "install" 1> $TMP/selected-pkgtype

    d-displaymgr.sh desktop
    exit 0
  fi
elif [ "$MEDIA" = "CDROM" -o "$MEDIA" = "FLASH" ]; then
  echo "$MOUNTPOINT" 1> $TMP/selected-source-path
  check_install_media "$MEDIA" "$DEVICE" "$MOUNTPOINT"

elif [ "$MEDIA" = "DISK" ]; then

  PARTITION="$(cat $TMP/selected-source-partition)"
  check_install_media "$MEDIA" "$PARTITION" "$MOUNTPOINT"
  [ $? = 0 ] && select_path $MOUNTPOINT $MTPT
fi

if [ $? = 0 ]; then
  if check_os_release "$ROOTDIR" ; then
    if bootstrap "$ROOTDIR" ; then
      if [ "$PROBEMODE" = "auto" ]; then
        echo_message "L_${MEDIA}_MEDIA_VALID"
      else
        echo_success "L_${MEDIA}_MEDIA_VALID"
      fi
      sync; sleep 1
      exit 0
    fi
  fi
fi

if [ "$PROBEMODE" = "auto" ]; then
  echo_warning "L_${MEDIA}_MEDIA_INVALID"
else
  echo_failure "L_${MEDIA}_MEDIA_INVALID"
fi

exit 1

# end Breeze::OS setup script
