#!/bin/bash
#
# GNU GENERAL PUBLIC LICENSE Version 3
#
# Copyright 1993, 1999, 2002 Patrick Volkerding, Moorhead, MN.
# Use and redistribution covered by the same terms as the "setup" script.
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

umount $MOUNTPOINT 2> /dev/null
unlink $TMP/SeTmount 2> /dev/null
unlink $TMP/SeTDS 2> /dev/null
unlink $TMP/SeTCDdev 2> /dev/null
unlink $TMP/reply 2> /dev/null

dialog --clear --colors \
--backtitle "Breeze::OS $RELEASE Installer." \
--title "SCANNING FOR CD or DVD DRIVE" \
--menu "Make sure the \Zb\Z4Breeze::OS\Zn disc is in your CD/DVD drive, \
and then press ENTER to begin the scanning process. \
Or, if you'd rather specify the device name manually \
(experts only), choose that option below." 12 72 2 \
"auto" "Scan for the CD or DVD drive" \
"manual" "Specify CD or DVD by device name" 2> $TMP/reply

if [ "$?" != 0 ]; then
 # cancel or esc
 exit 1
fi

if [ "`cat $TMP/reply`" = "manual" ]; then
dialog --clear --colors \
--backtitle "Breeze::OS $RELEASE Installer." \
--title "MANUAL CD/DVD DEVICE SELECTION" --menu \
 "Please select your CD/DVD device from the list below.  \
If you don't see your device listed, choose 'custom'.  \
This will let you type in any device name. (and if necessary, \
will create the device)" 18 70 9 \
 "custom" "Type in the CD or DVD device to use" \
 "/dev/hdb" "CD/DVD slave on first IDE bus" \
 "/dev/hda" "CD/DVD master on first IDE bus (unlikely)" \
 "/dev/hdc" "CD/DVD master on second IDE bus" \
 "/dev/hdd" "CD/DVD slave on second IDE bus" \
 "/dev/hde" "CD/DVD master on third IDE bus" \
 "/dev/hdf" "CD/DVD slave on third IDE bus" \
 "/dev/hdg" "CD/DVD master on fourth IDE bus" \
 "/dev/hdh" "CD/DVD slave on fourth IDE bus" \
 "/dev/sr0" "First SCSI CD/DVD drive" \
 "/dev/sr1" "Second SCSI CD/DVD drive" \
 "/dev/sr2" "Third SCSI CD/DVD drive" \
 "/dev/sr3" "Fourth SCSI CD/DVD drive" \
 "/dev/scd0" "First SCSI CD/DVD drive" \
 "/dev/scd1" "Second SCSI CD/DVD drive" \
 "/dev/scd2" "Third SCSI CD/DVD drive" \
 "/dev/scd3" "Fourth SCSI CD/DVD drive" \
 "/dev/pcd0" "First parallel port ATAPI CD" \
 "/dev/pcd1" "Second parallel port ATAPI CD" \
 "/dev/pcd2" "Third parallel port ATAPI CD" \
 "/dev/pcd3" "Fourth parallel port ATAPI CD" \
 "/dev/aztcd" "Non-IDE Aztech CD/DVD" \
 "/dev/cdu535" "Sony CDU-535 CD/DVD" \
 "/dev/gscd" "Non-IDE GoldStar CD/DVD" \
 "/dev/sonycd" "Sony CDU-31a CD/DVD" \
 "/dev/optcd" "Optics Storage CD/DVD" \
 "/dev/sjcd" "Sanyo non-IDE CD/DVD" \
 "/dev/mcdx0" "Non-IDE Mitsumi drive 1" \
 "/dev/mcdx1" "Non-IDE Mitsumi drive 2" \
 "/dev/sbpcd" "Old non-IDE SoundBlaster CD/DVD" \
 "/dev/cm205cd" "Philips LMS CM-205 CD/DVD" \
 "/dev/cm206cd" "Philips LMS CM-206 CD/DVD" \
 "/dev/mcd" "Old non-IDE Mitsumi CD/DVD" 2> $TMP/reply

 if ! [ $? = 0 -o -r $TMP/reply ]; then
  # cancel or esc
  unlink $TMP/SeTmount 2> /dev/null
  unlink $TMP/SeTDS 2> /dev/null
  unlink $TMP/SeTCDdev 2> /dev/null
  unlink $TMP/errordo 2> /dev/null
  exit 1
 fi

 REPLY="`cat $TMP/reply`"
 if [ "$REPLY" = "custom" ]; then
dialog --clear --colors \
--backtitle "Breeze::OS $RELEASE Installer." \
--title "ENTER CD/DVD DEVICE MANUALLY" --inputbox \
"Please enter the name of the CD/DVD device (such as /dev/hdc) that \
you wish to use to mount the \Zb\Z4Breeze::OS\Zn CD/DVD:" 9 70 2> $TMP/reply

 if ! [ $? = 0 -o -r $TMP/reply ]; then
   # cancel or esc
   unlink $TMP/SeTmount 2> /dev/null
   unlink $TMP/SeTDS 2> /dev/null
   unlink $TMP/SeTCDdev 2> /dev/null
   unlink $TMP/errordo 2> /dev/null
   exit 1
  fi

  DRIVE_FOUND="`cat $TMP/reply`"

  if [ ! -r $DRIVE_FOUND ]; then # no such device
   unlink $TMP/majorminor
dialog --clear --colors \
--backtitle "Breeze::OS $RELEASE Installer." \
--title "MKNOD CD/DVD DEVICE" --inputbox \
   "There doesn't seem to be a device by the name of $DRIVE_FOUND in the \
/dev directory, so we will have to create it using the major and minor \
numbers for the device.  If you're using a bootdisk with a custom CD/DVD \
driver on it, you should be able to find these numbers in the \
documentation.  Also, see the 'devices.txt' file that comes with the \
Linux kernel source.  If you don't know the numbers, you'll have to hit \
Esc to abort. Enter the major and minor numbers for the new device, \
separated by one space:" 15 72 2> $TMP/majorminor

   if ! [ $? = 0 -o -r $TMP/majorminor ]; then
    # cancel or esc
    unlink $TMP/SeTmount 2> /dev/null
    unlink $TMP/SeTDS 2> /dev/null
    unlink $TMP/SeTCDdev 2> /dev/null
    unlink $TMP/errordo 2> /dev/null
    exit 1
   fi

   MAJOR="`cat $TMP/majorminor`"

dialog --colors \
--backtitle "Breeze::OS $RELEASE Installer." \
--title "MAKING DEVICE IN /dev" \
--infobox "mknod $DRIVE_FOUND b $MAJOR" 3 40
   mknod $DRIVE_FOUND b $MAJOR 2> /dev/null
   sleep 3

   if [ ! -r $DRIVE_FOUND ]; then
dialog --clear --colors \
--backtitle "Breeze::OS $RELEASE Installer." \
--title "MKNOD FAILED" --msgbox \
    "Sorry, but the mknod command failed to make the device.  You'll need to \
go back and try selecting your source media again.  Press ENTER to abort \
the source media selection process." 8 60
    unlink $TMP/SeTmount 2> /dev/null
    unlink $TMP/SeTDS 2> /dev/null
    unlink $TMP/SeTCDdev 2> /dev/null
    unlink $TMP/errordo 2> /dev/null
    exit 1
   fi
  fi
 else
  DRIVE_FOUND=$REPLY
 fi
fi

# Search the IDE interfaces:
if [ "$DRIVE_FOUND" = "" ]; then

dialog --colors \
	--backtitle "Breeze::OS $RELEASE Installer." \
	--title "SCANNING FOR CD or DVD DRIVE" \
	--infobox "Scanning for a \Z1CD/DVD\Zn drive with a \Zb\Z4Breeze::OS\Zn disc..." 4 65
 sleep 1

 device="/dev/cdrom"
 mount -o ro -t iso9660 $device $MOUNTPOINT 1> /dev/null 2> $TMP/isomount

  if [ "$?" = 0 ]; then
    echo "$device" 1> $TMP/selected-source
    echo "$MOUNTPOINT" 1> $TMP/selected-source-path

	dialog --colors \
		--backtitle "Breeze::OS $RELEASE Installer." \
		--title "SCANNING FOR CD or DVD DRIVE" \
		--infobox "CD/DVD drive \Z4$device\Zn was found ..." 4 65
    sleep 3
    exit 0
  fi

dialog --colors \
	--backtitle "Breeze::OS $RELEASE Installer." \
	--title "SCANNING FOR CD or DVD DRIVE" \
	--infobox "Scanning for an \Z1IDE CD/DVD\Zn drive with a \Zb\Z4Breeze::OS\Zn disc..." 4 65
 sleep 3

 for device in \
  /dev/hdd /dev/hdc /dev/hdb /dev/hda \
  /dev/hde /dev/hdf /dev/hdg /dev/hdh \
  /dev/hdi /dev/hdj /dev/hdk /dev/hdl \
  /dev/hdm /dev/hdn /dev/hdo /dev/hdp \
  ; do

  mount -o ro -t iso9660 $device $MOUNTPOINT 1> /dev/null 2> $TMP/isomount

  if [ $? = 0 ]; then
    echo "$device" 1> $TMP/selected-source
    echo "$MOUNTPOINT" 1> $TMP/selected-source-path

	dialog --colors \
		--backtitle "Breeze::OS $RELEASE Installer." \
		--title "SCANNING FOR CD or DVD DRIVE" \
		--infobox "IDE CD/DVD drive \Z4$device\Zn was found ..." 4 65
    sleep 3
    exit 0
  fi
 done
fi

# Search for SCSI CD/DVD drives:
if [ "$DRIVE_FOUND" = "" ]; then
dialog --colors \
	--backtitle "Breeze::OS $RELEASE Installer." \
	--title "SCANNING FOR CD or DVD DRIVE" \
	--infobox "Scanning for a \Z1SCSI CD/DVD\Zn drive with a \Zb\Z4Breeze::OS\Zn disc..." 4 65
 sleep 3

 for device in /dev/sr0 /dev/sr1 /dev/sr2 /dev/sr3; do
  mount -o ro -t iso9660 $device $MOUNTPOINT 1> /dev/null 2> /dev/null

  if [ "$?" = 0 ]; then
    echo "$device" 1> $TMP/selected-source
    echo "$MOUNTPOINT" 1> $TMP/selected-source-path

	dialog --colors \
		--backtitle "Breeze::OS $RELEASE Installer." \
		--title "SCANNING FOR CD or DVD DRIVE" \
		--infobox "SCSI CD/DVD drive \Z4$device\Zn was found ..." 4 65
    sleep 3
    exit 0
  fi
 done
fi

# Search for parallel port ATAPI CD/DVD drives:
if [ "$DRIVE_FOUND" = "" ]; then
dialog --colors \
--backtitle "Breeze::OS $RELEASE Installer." \
--title "SCANNING" \
--infobox "Scanning for a parallel port \Z1ATAPI CD/DV\Zn drive with a \Z4\ZbBreeze::OS\Zn disc..." 4 65
 sleep 3
 for device in /dev/pcd0 /dev/pcd1 /dev/pcd2 /dev/pcd3; do
  mount -o ro -t iso9660 $device $MOUNTPOINT 1> /dev/null 2> /dev/null
  if [ $? = 0 ]; then
    echo "$device" 1> $TMP/selected-source
    echo "$MOUNTPOINT" 1> $TMP/selected-source-path

	dialog --colors \
		--backtitle "Breeze::OS $RELEASE Installer." \
		--title "SCANNING FOR CD or DVD DRIVE" \
		--infobox "CD/DVD drive \Z4$device\Zn was found ..." 4 65
    sleep 3
    exit 0
  fi
 done
fi

# Still not found?  OK, we will search for CD/DVD drives on old, pre-ATAPI
# proprietary interfaces.  There aren't too many of these still around, and
# the scan won't actually work unless a bootdisk that supports the drive is
# used, and any necessary parameters have been passed to the kernel.
if [ "$DRIVE_FOUND" = "" ]; then
dialog --clear --colors \
--backtitle "Breeze::OS $RELEASE Installer." \
--title "SCANNING" --msgbox "No IDE/SCSI drive, so we will try \
scanning for CD drives on \
old proprietary interfaces, such as SoundBlaster pre-IDE CD drives, \
Sony CDU-31a, Sony 535, old Mitsumi pre-IDE, old Optics, etc.  For this \
scan to work at all, you'll need to be using a bootdisk that supports \
your CD drive.  Please press ENTER to begin this last-chance scan \
for old, obsolete hardware." 11 60
 for device in \
  /dev/sonycd /dev/gscd /dev/optcd /dev/sjcd /dev/mcdx0 /dev/mcdx1 \
  /dev/cdu535 /dev/sbpcd /dev/aztcd /dev/cm205cd /dev/cm206cd \
  /dev/bpcd /dev/mcd \
  ; do
  mount -o ro -t iso9660 $device $MOUNTPOINT 1> /dev/null 2> /dev/null
  if [ $? = 0 ]; then
    echo "$device" 1> $TMP/selected-source
    echo "$MOUNTPOINT" 1> $TMP/selected-source-path

	dialog --colors \
		--backtitle "Breeze::OS $RELEASE Installer." \
		--title "SCANNING FOR CD or DVD DRIVE" \
		--infobox "CD/DVD drive \Z4$device\Zn was found ..." 4 65
    sleep 3
    exit 0
  fi
 done
fi

if [ "$DRIVE_FOUND" = "" ]; then
dialog --clear --colors \
--backtitle "Breeze::OS $RELEASE Installer." \
--title "CD/DVD DRIVE NOT FOUND" --msgbox \
 "A CD/DVD drive could not be found on any of the devices that were \
scanned.  Possible reasons include using a bootdisk or kernel that \
doesn't support your drive, failing to pass parameters needed by some \
drives to the kernel, not having the \Zb\Z4Breeze::OS\Zn disc in your CD/DVD \
drive, or using a drive connected to a Plug and Play soundcard (in this \
case, connecting the drive directly to the IDE interface often helps). \
Please make sure you are using the correct bootdisk for your hardware, \
consult the BOOTING file for possible information on \
forcing the detection of your drive, and then reattempt installation.  \
If all else fails, see FAQ.TXT for information about copying \
parts of this CD to your DOS partition and installing it from there.\n\
\n\
You will now be returned to the main menu.  If you want to try looking \
for the CD again, you may skip directly to the SOURCE menu selection." \
 0 0

 unlink $TMP/SeTmount 2> /dev/null
 unlink $TMP/SeTDS 2> /dev/null
 unlink $TMP/SeTCDdev 2> /dev/null
 unlink $TMP/errordo 2> /dev/null
 exit 1
fi

exit 0

