#!/bin/bash
#
# SeTpartitions modified by <dev@tsert.com>
# Copyright 2011, Pierre Innocent, Tsert Inc. All Rights Reserved
#
# SeTpartitions user-friendly rewrite Fri Dec 15 13:17:40 CST 1995 pjv
# Rewrite to support filesystem plugins <david@slackware.com>, 07-May-2001
# Don't use plugins, make it work, pjv, 18-May-2001.
# Generalize tempscript creation and support JFS and XFS. pjv, 30-Mar-2002

TMP=/var/tmp
ROOTDIR=/mnt/root
REDIR=/dev/tty4
PART_SETTINGS="defaults"
PARTITION_LIST="`cat $TMP/partition-list 2> /dev/null`"

# crunch() -  remove extra whitespace
crunch () {
   read STRING;
   echo $STRING
}

# make_ext2( dev, nodes, check ) - Create a new ext2 filesystem on the named
#    device with the specified inode density.
# Parameters:  dev     Device node to format.
#              nodes   Inode density (1024, 2048, 4096)
#              check   Perform fs check (y or n)
make_ext2() {
	# get the size of the named partition
	SIZE=`get_part_size $1`

	# output a nice status message
	INODE_DENSITY="Inode density: 1 inode per $2 bytes."

	dialog --colors \
		--backtitle "Breeze::OS Kodiak.light Installer." \
		--title "FORMATTING with (EXT2) INODE SIZE ($2)" \
		--infobox "Formatting $1  \n\
Size in 1K blocks: $SIZE \n\
Filesystem type: ext2 \n\
$INODE_DENSITY " 0 0

	# do the format
	if mount | fgrep "$1 " 1> /dev/null 2> /dev/null ; then
		umount $1 2> /dev/null
	fi

	if [ "$3" = "y" ]; then
		mkfs.ext2 -c -i $2 $1 1> $REDIR 2> $REDIR
	else
		mkfs.ext2 -i $2 $1 1> $REDIR 2> $REDIR
	fi
}

# make_ext3( dev, nodes, check ) - Create a new ext3 filesystem on the named
#  device with the specified inode density.
# Parameters:  dev     Device node to format.
#              nodes   Inode density (1024, 2048, 4096)
#              check   Perform fs check (y or n)
make_ext3() {
	# get the size of the named partition
	SIZE=`get_part_size $1`

	# output a nice status message
	INODE_DENSITY="Inode density: 1 inode per $2 bytes."

	dialog --colors \
		--backtitle "Breeze::OS Kodiak.light Installer." \
		--title "FORMATTING with (EXT3) INODE SIZE ($2)" \
		--infobox "Formatting $1  \n\
	Size in 1K blocks: $SIZE \n\
	Filesystem type: ext3 \n\
	$INODE_DENSITY " 0 0

	# do the format
	if mount | fgrep "$1 " 1> /dev/null 2> /dev/null ; then
		umount $1 2> /dev/null
	fi

	if [ "$3" = "y" ]; then
		mkfs.ext3 -j -c -i $2 $1 1> $REDIR 2> $REDIR
	else
		mkfs.ext3 -j -i $2 $1 1> $REDIR 2> $REDIR
	fi
}

# make_ext4( dev, nodes, check ) - Create a new ext4 filesystem on the named
#  device with the specified inode density.
# Parameters:  dev     Device node to format.
#              nodes   Inode density (1024, 2048, 4096)
#              check   Perform fs check (y or n)
make_ext4() {
	# get the size of the named partition
	SIZE=`get_part_size $1`

	# output a nice status message
	INODE_DENSITY="Inode density: 1 inode per $2 bytes."

	dialog --colors \
		--backtitle "Breeze::OS Kodiak.light Installer." \
		--title "FORMATTING with (EXT4) INODE SIZE ($2)" \
		--infobox "Formatting $1  \n\
	Size in 1K blocks: $SIZE \n\
	Filesystem type: ext4 \n\
	$INODE_DENSITY " 0 0

	# do the format
	if mount | fgrep "$1 " 1> /dev/null 2> /dev/null ; then
		umount $1 2> /dev/null
	fi

	if [ "$3" = "y" ]; then
		mkfs.ext4 -j -c -i $2 $1 1> $REDIR 2> $REDIR
	else
		mkfs.ext4 -j -i $2 $1 1> $REDIR 2> $REDIR
	fi
}

# make_jfs( dev, check ) - Create a new jfs filesystem on the named
#     device with the specified inode density.
# Parameters:  dev     Device node to format.
#              check   Perform fs check (y or n)
make_jfs() {
	# get the size of the named partition
	SIZE=`get_part_size $1`

	# output a nice status message
	dialog --clear --colors \
		--backtitle "Breeze::OS Kodiak.light Installer" \
		--title "FORMATTING $1 with JFS." \
		--infobox "Formatting $1  \n\
	Size in 1K blocks: $SIZE \n\
	Filesystem type: jfs" 0 0

	# do the format
	if mount | fgrep "$1 " 1> /dev/null 2> /dev/null ; then
		umount $1 2> /dev/null
	fi

	if [ "$2" = "y" ]; then
		mkfs.jfs -c -q $1 1> $REDIR 2> $REDIR
	else
		mkfs.jfs -q $1 1> $REDIR 2> $REDIR
	fi
}

# make_reiserfs( dev ) - Create a new reiserfs filesystem on the named dev
# Parameters:  dev     Device node to format.
make_reiserfs() {
   # get the size of the named partition
   SIZE=`get_part_size $1`
   # output a nice status message
	dialog --colors \
		--backtitle "Breeze::OS Kodiak.light Installer." \
	   --title "FORMATTING (REISER3) with INODE SIZE ($2)" \
	   --infobox "Formatting $1  \n\
Size in 1K blocks: $SIZE \n\
Filesystem type: reiserfs " 0 0
   # do the format
   if mount | fgrep "$1 " 1> /dev/null 2> /dev/null ; then
      umount $1 2> /dev/null
   fi
   if [ "$2" = "" ]; then
      echo "y" | mkfs.reiserfs $1 1> $REDIR 2> $REDIR
   elif [ ! "$2" = "2048" -a ! "$2" = "1024" ]; then
      echo "y" | mkfs.reiserfs $1 1> $REDIR 2> $REDIR
   else
      echo "y" | mkfs.reiserfs -b $2 $1 1> $REDIR 2> $REDIR
   fi
}

# make_reiserfs4( dev ) - Create a new reiserfs4 filesystem on the named dev
# Parameters:  dev     Device node to format.
make_reiserfs4() {
   # get the size of the named partition
   SIZE=`get_part_size $1`
   # output a nice status message
	dialog --colors \
		--backtitle "Breeze::OS Kodiak.light Installer." \
	   --title "FORMATTING (REISER4) with INODE SIZE ($2)" \
	   --infobox "Formatting $1  \n\
Size in 1K blocks: $SIZE \n\
Filesystem type: reiserfs " 0 0
   # do the format
   if mount | fgrep "$1 " 1> /dev/null 2> /dev/null ; then
      umount $1 2> /dev/null
   fi
   if [ "$2" = "" ]; then
      echo "y" | mkfs.reiserfs4 $1 1> $REDIR 2> $REDIR
   elif [ ! "$2" = "2048" -a ! "$2" = "1024" ]; then
      echo "y" | mkfs.reiserfs4 $1 1> $REDIR 2> $REDIR
   else
      echo "y" | mkfs.reiserfs4 -b $2 $1 1> $REDIR 2> $REDIR
   fi
}

# gen_part_list() - Prints out a partition listing for the system into the
gen_part_list() {
   export COUNT=0

   cat $TMP/SeTplist | while [ 0 ]; do
      read PARTITION;

      if [ "$PARTITION" = "" ]; then
         break;
      fi

      # Variables, variables, variables
      NAME=`echo $PARTITION | crunch | cut -f 1 -d ' '`
      SIZE=`echo "$PARTITION" | tr -d "*" | tr -d "+" | crunch | cut -f 4 -d ' '`
      ALTNAME=""
      DEVICE=`echo "$PARTITION" | tr -d "*" | crunch | cut -f 1 -d ' '`

      # See if this partition is in use already
      if fgrep "$DEVICE " $TMP/SeTnative 1> /dev/null; then # it's been used
         ON=`fgrep "$DEVICE " $TMP/SeTnative | crunch | cut -f 2 -d ' '`
         ALTNAME="$DEVICE on $ON Linux ${SIZE}K"
      fi

      # Add a menu item
      if [ "$ALTNAME" = "" ]; then
         echo "\"$NAME\" \"Linux ${SIZE}K\" \\" >> $TMP/tempscript
         echo "false" > $TMP/SeTSKIP # this flag is used for non-root parts
      else
         echo "\"(IN USE)\" \"$ALTNAME\" \\" >> $TMP/tempscript
      fi
   done
   echo "\"---\" \"(Continue with setup)\" \\" >> $TMP/tempscript
   echo "2> $TMP/retcode" >> $TMP/tempscript
}

# ask_format( dev ) - Asks the user if he/she wants to format the named device
ask_format() {
	dialog --colors --clear \
		--backtitle "Breeze::OS Kodiak.light Installer." \
		--title "FORMAT PARTITION $1" \
		--menu "If this partition is not formatted, you should format it. \
Remember that enough space must be present for installation if you choose, \
not to format the partition.\n\n\
    N.B. \Z1Formatting will erase all data on this partition\Zn.\n\n\
Would you like to format this partition ?" 16 70 3 \
   "No" "No, Do not format this partition" \
   "Format" "Quick format with no bad block checking" \
   "Check" "Slow format that checks for bad blocks" 2> $TMP/retcode

	if [ ! $? = 0 ]; then
		rm -f $TMP/retcode
		exit
	fi
}

# ask_nodes( dev ) - Asks the user for the inode density for the named device.
ask_nodes() {
	dialog --colors --clear \
		--backtitle "Breeze::OS Kodiak.light Installer." \
		--title "SELECT INODE DENSITY FOR PARTITION $1" \
		--default-item "4096" \
		--menu "The \Zb\Z4Breeze::OS Indexer\Zn will create many small files. \
If you know what your are doing; you can change the \Z1default\Zn density to one inode (file object) per 2048 or 4096 bytes.\n\n\
Which inode setting would you like ?" 14 70 3 \
   "1024" "1 inode per 1024 bytes (\Z1reiserfs\Zn)" \
   "2048" "1 inode per 2048 bytes (\Z1reiserfs\Zn)" \
   "4096" "1 inode per 4096 bytes (\Z1ext2, ext3, ext4, or jfs\Zn)" 2> $TMP/retcode

	if [ ! $? = 0 ]; then
		rm -f $TMP/retcode
		exit
	fi
}

# ask_fs( dev ) - Asks the user the type of filesystem to use for the named
#                 device.  Answer in $TMP/retcode
ask_fs() {
  unset EXT4 EXT2 EXT3 JFS REISERFS REISERFS4
  DEFAULT=ext4

  if cat /proc/filesystems | grep ext2 1> /dev/null 2> /dev/null ; then
    EXT2="Ext2 is the traditional Linux file system and is fast and stable. "
    DEFAULT=ext2
  fi
  if cat /proc/filesystems | grep ext4 1> /dev/null 2> /dev/null ; then
    EXT4="Ext4 is the susscessor to the Ext3 filesystem. "
    DEFAULT=ext3
  fi
  if cat /proc/filesystems | grep ext3 1> /dev/null 2> /dev/null ; then
    EXT3="Ext3 is the journaling version of the Ext2 filesystem. "
    DEFAULT=ext3
  fi
  # These last two will only be present if the user asked for a special kernel.
  # They should probably be the default in that case.
  if cat /proc/filesystems | grep jfs 1> /dev/null 2> /dev/null ; then
    JFS="JFS is IBM's Journaled Filesystem, currently used in IBM enterprise servers. "
    DEFAULT=jfs
  fi
  if cat /proc/filesystems | grep reiserfs 1> /dev/null 2> /dev/null ; then
    REISERFS="ReiserFS is a journaling filesystem that stores all files and filenames in a balanced tree structure. "
    DEFAULT=reiserfs
  fi
  if cat /proc/filesystems | grep reiserfs4 1> /dev/null 2> /dev/null ; then
    REISERFS4="ReiserFS(4) is the updated version of the reiserFS journaling filesystem. "
    DEFAULT=reiserfs4
  fi

	cat << EOF > $TMP/tempscript
	dialog --colors --clear \\
		--backtitle "Breeze::OS Kodiak.light Installer" \\
		--title "SELECT FILESYSTEM FOR $1" \\
		--default-item $DEFAULT --menu \\
"Please select the type of filesystem to use for the specified   \\n\\
device.  Here are descriptions of the available filesystems: $REISERFS $REISERFS4 $EXT2 $EXT3 $EXT4 $JFS" \\
0 0 0 \\
EOF
  if [ ! "$REISERFS4" = "" ]; then
    echo "\"reiserfs4\" \"Reiser's Journaling Filesystem (4)\" \\" >> $TMP/tempscript
  fi
  if [ ! "$REISERFS" = "" ]; then
    echo "\"reiserfs\" \"Reiser's Journaling Filesystem (3)\" \\" >> $TMP/tempscript
  fi
  if [ ! "$EXT4" = "" ]; then
    echo "\"ext4\" \"Successor of the ext3fs filesystem (\Z1recommended\Zn)\" \\" >> $TMP/tempscript
  fi
  if [ ! "$EXT3" = "" ]; then
    echo "\"ext3\" \"Journaling version of the ext2fs filesystem\" \\" >> $TMP/tempscript
  fi
  if [ ! "$EXT2" = "" ]; then
    echo "\"ext2\" \"Standard Linux ext2fs filesystem\" \\" >> $TMP/tempscript
  fi
  if [ ! "$JFS" = "" ]; then
    echo "\"jfs\" \"IBM's Journaled Filesystem\" \\" >> $TMP/tempscript
  fi
  echo "2> $TMP/retcode" >> $TMP/tempscript
  . $TMP/tempscript
  if [ ! $? = 0 ]; then
    rm -f $TMP/retcode
    exit
  fi
}

# get_part_size( dev ) - Return the size in KB of the named partition.
get_part_size() {
   Size=`probe -l | fgrep "$1 " | tr -d "*" | tr -d "+" | crunch | cut -f 4 -d ' '`
   echo $Size
}

## MAIN

# Set the root partition ..
ROOT_DEVICE="`cat $TMP/root-partition 2> /dev/null`"

if [ "$ROOT_DEVICE" = "" ]; then
	probe -l 2> /dev/null | egrep 'Linux$' | sort 1> $TMP/SeTplist 2> /dev/null

	if [ ! -r $TMP/SeTplist ]; then
		clear
		exit 1
	fi

	cat /dev/null >> $TMP/SeTnative
	cat << EOF > $TMP/tempscript

	dialog --colors --clear \\
		--backtitle "Breeze::OS Kodiak.light Installer" \\
		--title "Select Linux installation partition:" \\
		--cancel-label Continue \\
		--ok-label Select \\
		--menu "Choose a partition from the following list for your Linux root (/)." 13 70 5 \\
EOF
	gen_part_list

	. $TMP/tempscript

	if [ ! $? = 0 ]; then
		clear
		rm $TMP/tempscript
		exit 255
	fi

	ROOT_DEVICE="`cat $TMP/retcode`"

	rm $TMP/tempscript

	if [ "$ROOT_DEVICE" = "---" ]; then
		clear
		exit 255
	fi
fi

if [ "$ROOT_DEVICE" = "" ]; then
	dialog --clear --colors \
		--backtitle "Breeze::OS Kodiak.light Installer" \
		--title "Breeze::OS Kodiak.light Setup -- Formatting ..." \
		--infobox "\nYou must select a \Zrroot\Zn partition ..." 5 55 
	exit 1
fi

# format root partition?
ask_format $ROOT_DEVICE

DOFORMAT="`cat $TMP/retcode`"
rm -f $TMP/retcode

if [ "$DOFORMAT" = "No" ]; then
	dialog --colors \
		--backtitle "Breeze::OS Kodiak.light Installer" \
		--title "Breeze::OS Kodiak.light Setup -- Syncing ..." \
		--infobox "\n\ZrPlease Wait !\Zn -- \Zb\Z4Syncing\Zn the partition ..." 5 55 
else
  ask_fs $ROOT_DEVICE
  ROOT_SYS_TYPE="`cat $TMP/retcode`"

  # create the filesystem
  if [ "$ROOT_SYS_TYPE" = "ext2" ]; then
    ask_nodes $ROOT_DEVICE
    NODES="`cat $TMP/retcode`"

    if [ ! "$NODES" = "2048" -a ! "$NODES" = "1024" ]; then
      NODES=4096
    fi
    if [ "$DOFORMAT" = "Check" ]; then
      make_ext2 $ROOT_DEVICE $NODES "y"
    else
      make_ext2 $ROOT_DEVICE $NODES "n"
    fi
  elif [ "$ROOT_SYS_TYPE" = "ext3" ]; then
    ask_nodes $ROOT_DEVICE
    NODES="`cat $TMP/retcode`"

    if [ ! "$NODES" = "2048" -a ! "$NODES" = "1024" ]; then
      NODES=4096
    fi
    if [ "$DOFORMAT" = "Check" ]; then
      make_ext3 $ROOT_DEVICE $NODES "y"
    else
      make_ext3 $ROOT_DEVICE $NODES "n"
    fi
  elif [ "$ROOT_SYS_TYPE" = "ext4" ]; then
    ask_nodes $ROOT_DEVICE
    NODES="`cat $TMP/retcode`"

    if [ ! "$NODES" = "2048" -a ! "$NODES" = "1024" ]; then
      NODES=4096
    fi
    if [ "$DOFORMAT" = "Check" ]; then
      make_ext4 $ROOT_DEVICE $NODES "y"
    else
      make_ext4 $ROOT_DEVICE $NODES "n"
    fi
  elif [ "$ROOT_SYS_TYPE" = "reiserfs" ]; then
    make_reiserfs $ROOT_DEVICE 2048

  elif [ "$ROOT_SYS_TYPE" = "reiserfs4" ]; then
    make_reiserfs4 $ROOT_DEVICE 2048

  elif [ "$ROOT_SYS_TYPE" = "jfs" ]; then
    if [ "$DOFORMAT" = "Check" ]; then
      make_jfs $ROOT_DEVICE "y"
    else
      make_jfs $ROOT_DEVICE "n"
    fi
  fi
fi # DOFORMAT?

# Now, we need to mount the newly selected root device:
sync

# If we didn't format the partition, then we don't know what fs type it is.
# So, we will try the types we know about, and let mount figure it out
# if all else fails:
#
umount $ROOT_DEVICE 2> /dev/null

for fs in "-t ext4" "-t ext3" "-t ext2" "-t reiserfs" "-t reiserfs4" "-t jfs" "" ; do
  if mount $ROOT_DEVICE $ROOTDIR $fs 1> $REDIR 2> $REDIR ; then
    break
  fi
  sleep 1
done

sleep 1
ROOT_SYS_TYPE=`mount | grep "^$ROOT_DEVICE on " | cut -f 5 -d ' '`

# For LVM volumes, we may have to use the device node that is exposed
# by the devicemapper, instead of the LVM device node:
if [ "$ROOT_SYS_TYPE" = "" ]; then
  VG=`echo "$ROOT_DEVICE" | cut -f3 -d'/'`
  LV=`echo "$ROOT_DEVICE" | cut -f4 -d'/'`
  ROOT_SYS_TYPE=`mount | grep "^/dev/mapper/$VG-$LV on " | cut -f5 -d' '`
fi

if [ "$ROOT_SYS_TYPE" = "reiserfs" .o "$ROOT_SYS_TYPE" = "reiserfs4" ]; then
	printf "%-16s %-16s %-11s %-16s %-3s %s\n" "$ROOT_DEVICE" "/" "$ROOT_SYS_TYPE" "notail,noatime" "1" "1" 1> $TMP/SeTnative
else
	printf "%-16s %-16s %-11s %-16s %-3s %s\n" "$ROOT_DEVICE" "/" "$ROOT_SYS_TYPE" "defaults" "1" "1" 1> $TMP/SeTnative
fi

echo $ROOT_DEVICE 1> $TMP/SeTrootdev
# done mounting the target root partition

# More than one Linux partition
if [ ! "`cat $TMP/SeTplist | sed -n '2 p'`" = "" ]; then

   while [ 0 ]; do
      # OK, we will set this flag, and if we find an unused partition, we
      # change it.  If it doesn't get switched, we skip the next menu.
      rm -f $TMP/SeTSKIP
      echo "true" 1> $TMP/SeTSKIP

      cat << EOF > $TMP/tempscript
	dialog --colors --clear \\
		--backtitle "Breeze::OS Kodiak.light Installer." \\
		--title "Select other Linux partitions for /etc/fstab" \\
		--ok-label Select --cancel-label Continue \\
		--menu "You seem to have more than one partition tagged as type \Z1Linux\Zn. \\
You now have $ROOT_DEVICE mounted as your \Zb\Z4root /\Zn partition. \\
You should \Z1follow\zn the partitioning scheme you chose; \\
i.e. mount \Z4\Zb/home\Zn or \Z4\Zb/usr\Zn on separate partitions. \\
\ZrNever mount /etc, /sbin, or /bin on their own partitions\Zn. \\
Also, do not \Z1reuse\Zn a partition that you've \Z1already entered\Zn. \\
Please select one of the \Z4\ZbLinux\Zn partitions listed below, or \\
if you're done, hit <Continue>." 18 70 4 \\
EOF
      gen_part_list

      if [ "`cat $TMP/SeTSKIP`" = "true" ]; then
         break;
      fi

      rm -rf $TMP/retcode

      . $TMP/tempscript

      if [ $? = 0 ]; then
         NEXT_PARTITION=`cat $TMP/retcode`
	  else
         break;
      fi

      if [ "$NEXT_PARTITION" = "---" ]; then
         break;
      elif [ "$NEXT_PARTITION" = "(IN USE)" ]; then
         continue;
      fi

      # We now have the next partition, ask the user what to do with it:
      ask_format $NEXT_PARTITION

      DOFORMAT="`cat $TMP/retcode`"
      rm -f $TMP/retcode

      BACKT="Partition $NEXT_PARTITION will not be reformatted."

      if [ ! "$DOFORMAT" = "No" ]; then
        ask_fs $NEXT_PARTITION
        NEXT_SYS_TYPE="`cat $TMP/retcode`"
        BACKT="Partition $NEXT_PARTITION will be formatted with $NEXT_SYS_TYPE."

        # create the filesystem
        if [ "$NEXT_SYS_TYPE" = "ext2" ]; then
          ask_nodes $NEXT_PARTITION
          NODES="`cat $TMP/retcode`"

          if [ ! "$NODES" = "2048" -a ! "$NODES" = "1024" ]; then
            NODES=4096
          fi
          if [ "$DOFORMAT" = "Check" ]; then
            make_ext2 $NEXT_PARTITION $NODES "y"
          else
            make_ext2 $NEXT_PARTITION $NODES "n"
          fi
        elif [ "$NEXT_SYS_TYPE" = "ext3" ]; then
          ask_nodes $NEXT_PARTITION
          NODES="`cat $TMP/retcode`"

          if [ ! "$NODES" = "2048" -a ! "$NODES" = "1024" ]; then
            NODES=4096
          fi
          if [ "$DOFORMAT" = "Check" ]; then
            make_ext3 $NEXT_PARTITION $NODES "y"
          else
            make_ext3 $NEXT_PARTITION $NODES "n"
          fi
        elif [ "$NEXT_SYS_TYPE" = "ext4" ]; then
          ask_nodes $NEXT_PARTITION
          NODES="`cat $TMP/retcode`"

          if [ ! "$NODES" = "2048" -a ! "$NODES" = "1024" ]; then
            NODES=4096
          fi
          if [ "$DOFORMAT" = "Check" ]; then
            make_ext4 $NEXT_PARTITION $NODES "y"
          else
            make_ext4 $NEXT_PARTITION $NODES "n"
          fi
        elif [ "$NEXT_SYS_TYPE" = "reiserfs" ]; then
		  ask_nodes $NEXT_PARTITION
		  NODES=$(cat $TMP/retcode)
          make_reiserfs $NEXT_PARTITION $NODES

        elif [ "$NEXT_SYS_TYPE" = "reiserfs4" ]; then
		  ask_nodes $NEXT_PARTITION
		  NODES=$(cat $TMP/retcode)
          make_reiserfs4 $NEXT_PARTITION $NODES

        elif [ "$NEXT_SYS_TYPE" = "jfs" ]; then
          if [ "$DOFORMAT" = "Check" ]; then
            make_jfs $NEXT_PARTITION "y"
          else
            make_jfs $NEXT_PARTITION "n"
          fi
        fi
      fi # DOFORMAT?

	if [ "$PARTITION_LIST" != "" ]; then
	  # Mount the new filesystem using the provided list ...
	  MTPT="`echo $PARTITION_LIST | grep $NEXT_PARTITION`"
      MTPT="`echo $MTPT | sed -e 's/^[^ ]*[ ]//g'`"
    else
	  # Now ask the user where to mount this new filesystem:
	  dialog --colors --clear \
		--backtitle "Breeze::OS Kodiak.light Installer -- $BACKT" \
		--title "SELECT MOUNT POINT FOR $NEXT_PARTITION" \
		--inputbox "OK, now you must specify the mount path of the new partition.  \
For example, if you want to locate it at \Zb\Z4/home\Zn, then respond: /home\n\
Where would you like to mount $NEXT_PARTITION?" 11 59 2> $TMP/retcode

      if [ ! $? = 0 ]; then
         continue
      fi

      MTPT=`cat $TMP/retcode`
      rm $TMP/retcode

      if [ "$MTPT" = "" ]; then # abort if blank
         continue
      fi
      if [ "`echo "$MTPT" | cut -b1`" = " " ]; then # bail if 1st char is space
         continue
      fi
      if [ ! "`echo "$MTPT" | cut -b1`" = "/" ]; then # add / to start of path
         MTPT="/$MTPT"
      fi
	fi

		# Now, we need to mount the newly selected device:
		if [ ! -d /mnt/$MTPT ]; then
			mkdir -p /mnt/$MTPT
		fi

		if [ "$DOFORMAT" != "No" ]; then
			mount $NEXT_PARTITION /mnt/$MTPT $NEXT_SYS_TYPE 1> $REDIR 2> $REDIR
		fi

		if [ $? != 0 ]; then
			# If the partition wasn't formatted, let mount figure it out.
			for fs in "-t ext4" "-t ext3" "-t ext2" \
				"-t reiserfs" "-t reiserfs4" "-t jfs" "" ; do
				if mount $NEXT_PARTITION /mnt/$MTPT $fs 1> $REDIR 2> $REDIR ; then
					break
				fi
				sleep 1
			done
			sleep 1
			NEXT_SYS_TYPE=`mount | grep "^$NEXT_PARTITION on " | cut -f 5 -d ' '`
		fi

		if [ "$NEXT_SYS_TYPE" = "reiserfs" ]; then
			printf "%-16s %-16s %-11s %-16s %-3s %s\n" "$NEXT_PARTITION" "$MTPT" "$NEXT_SYS_TYPE" "notail,noatime" "1" "2" >> $TMP/SeTnative
		else
			printf "%-16s %-16s %-11s %-16s %-3s %s\n" "$NEXT_PARTITION" "$MTPT" "$NEXT_SYS_TYPE" "defaults" "1" "2" >> $TMP/SeTnative
		fi
	done # next partition loop
fi # more than one Linux partition

rm -f $TMP/retcode

# Done, report to the user:
cat << EOF > $TMP/tempmsg

Adding this information to your /etc/fstab:

EOF
cat $TMP/SeTnative >> $TMP/tempmsg
dialog --colors --clear \
	--backtitle "Breeze::OS Kodiak.light Installer -- $BACKT" \
	--title "DONE ADDING LINUX PARTITIONS TO /etc/fstab" \
	--exit-label OK \
	--textbox $TMP/tempmsg 15 72

# Now, move our /tmp storage onto the target partition if possible:
#cp -rfa $TMP $MTPT/
#d-migrate.sh

