#!/bin/bash
TMP=/var/tmp
if [ ! -d $TMP ]; then
  mkdir -p $TMP
fi

while [ 0 ]; do
rm -f $TMP/SeTDS $TMP/SeTmount

# OK, at this point /var/log/mount should not have anything mounted on it,
# but we will umount just in case.
umount /var/log/mount 2> /dev/null

# Anything mounted on /var/log/mount now is a fatal error:
if mount | fgrep /var/log/mount 1> /dev/null 2> /dev/null ; then
  echo "Can't umount /var/log/mount.  Reboot machine and run setup again."
  exit
fi

# If the mount table is corrupt, the above might not do it, so we will
# try to detect Linux and FAT32 partitions that have slipped by:
if [ -d /var/log/mount/lost+found -o -d /var/log/mount/recycled \
     -o -r /var/log/mount/io.sys ]; then
  echo "Mount table corrupt.  Reboot machine and run setup again."
  exit
fi
cat << EOF > $TMP/tempmsg

OK, we will install from an ISO9660 file on the current
filesystem. If you have mounted this file yourself,
you should not use /mnt or /var/log/mount as mount points,
since Setup might need to use these directories.  You may
install from any part of the current directory structure,
no matter the media. You will need to type in the name 
of the ISO9660 file containing the source disk.

Which ISO9660 file would you like to install from?
EOF
dialog --title "INSTALL FROM THE CURRENT FILESYSTEM" \
 --inputbox "`cat $TMP/tempmsg`" 19 67 2> $TMP/iso9660-file
if [ ! $? = 0 ]; then
 rm -f $TMP/iso9660-file $TMP/tempmsg
 exit
fi

ISOFILE="`cat $TMP/iso9660-file`"
rm -f $TMP/iso9660-file $TMP/tempmsg
rm -f /var/log/mount 2> /dev/null
rmdir /var/log/mount 2> /dev/null
#ln -sf $ISOFILE /var/log/mount

if [ -r $ISOFILE ]; then
 mkdir /var/log/mount/
 mount -o loop,ro -t iso9660 $ISOFILE /var/log/mount/

 echo "/var/log/mount/" > $TMP/SeTDS
 echo "-source_mounted" > $TMP/SeTmount
 echo "/dev/null" > $TMP/SeTsource
 exit
else
 cat << EOF > $TMP/tempmsg

Sorry - the ISO9660 file you specified is not valid. Please check and try again.

(ISO9660 file given: $ISOFILE)

EOF
 dialog --title "INVALID ISO9660 file ENTERED" --msgbox "`cat $TMP/tempmsg`" 10 65
 rm -f $TMP/SeTDS $TMP/SeTmount $TMP/iso9660-file $TMP/tempmsg
fi
done;
