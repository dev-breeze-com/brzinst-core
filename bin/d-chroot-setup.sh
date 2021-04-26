#!/bin/bash
#
# GNU GENERAL PUBLIC LICENSE Version 3
#
# Taken from Debian installer 
# Modified by devel@breezeos.com
#
mountpoints()
{
	cut -d" " -f2 /proc/mounts | sort | uniq
	return 0
}

# Make sure mtab in the chroot reflects the currently mounted partitions.
update_mtab()
{
	mtab=$ROOTDIR/etc/mtab

	if [ -h "$mtab" ]; then
		#logger -t $0 "warning: $mtab won't be updated since it is a symlink."
		return 0
	fi

	egrep '^[^ ]+ $ROOTDIR' /proc/mounts | (
	while read devpath mountpoint fstype options n1 n2 ; do
		devpath=$(mapdevfs $devpath || echo $devpath)
		mountpoint="${mountpoint#$ROOTDIR}"

		# mountpoint for root will be empty
		if [ -z "$mountpoint" ] ; then
			mountpoint="/"
		fi
		echo $devpath $mountpoint $fstype $options $n1 $n2
	done ) > $mtab
	return 0
}

chroot_setup()
{
	mkdir -p /var/tmp/

	if [ ! -d $ROOTDIR/sbin ] || [ ! -d $ROOTDIR/usr/sbin ] || \
	   [ ! -d $ROOTDIR/proc ]; then
		return 1
	fi

	if [ -d /sys/devices ] && [ ! -d $ROOTDIR/sys ]; then
		return 1
	fi

	if [ -e /var/tmp/chroot-exec.lock ]; then
		cat >&2 <<EOF
Instance is already running !
EOF
		return 1
	fi

	mkdir -p /var/tmp/
	touch $ROOTDIR/var/tmp/chrooted
	touch /var/tmp/chroot-exec.lock

	# Some packages (eg. the kernel-image package) require a mounted
	# /proc/. Only mount it if not mounted already
	if [ ! -f $ROOTDIR/proc/cmdline ]; then
		mount -t proc proc $ROOTDIR/proc
	fi

	# For installing >=2.6.14 kernels we also need sysfs mounted
	# Only mount it if not mounted already
	if [ ! -d $ROOTDIR/sys/devices ]; then
		mount -t sysfs sysfs $ROOTDIR/sys
	else
        mount -o bind /sys $CHROOT_DIR/sys
	fi

	mount -o bind /dev $ROOTDIR/dev
	chmod -R a+rx $ROOTDIR/dev/input/

	# /dev/ may lacks the pty devices, so we need devpts mounted
	if [ ! -e $ROOTDIR/dev/pts/0 ]; then
		mkdir -p $ROOTDIR/dev/pts
		#mount -o bind /dev/pts $ROOTDIR/dev/pts
		mount -t devpts devpts -o noexec,nosuid,gid=5,mode=620 $ROOTDIR/dev/pts
	fi

	mkdir -p $ROOTDIR/run/udev
	mount -o bind /run/udev $ROOTDIR/run/udev

	update_mtab

	LANG="en_US"
	export LANG #PERL_BADLANG=0

	return 0
}

chroot_cleanup()
{
#	umount $ROOTDIR/tmp 2> /dev/null
	umount -R -f $ROOTDIR/dev/pts 2> /dev/null
	umount -R -f $ROOTDIR/dev 2> /dev/null
	umount -R -f $ROOTDIR/sys 2> /dev/null
	umount -R -f $ROOTDIR/proc 2> /dev/null
	umount -R -f $ROOTDIR/run/udev 2> /dev/null

	unlink $ROOTDIR/var/tmp/chrooted 2> /dev/null
	unlink /var/tmp/chroot-exec.lock 2> /dev/null

	return 0
}
