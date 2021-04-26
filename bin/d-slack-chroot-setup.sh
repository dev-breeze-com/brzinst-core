# Modified by dev@tsert.com copyright 2011
#
# GNU GENERAL PUBLIC LICENSE -- Version 3
# Debian.org copyright 2011
# Setup for using apt to install packages in /target.
#
mountpoints () {
	cut -d" " -f2 /proc/mounts | sort | uniq
}

# Make sure mtab in the chroot reflects the currently mounted partitions.
update_mtab() {

	mtab=/target/etc/mtab

	if [ -h "$mtab" ]; then
		logger -t $0 "warning: $mtab won't be updated since it is a symlink."
		return 0
	fi

	egrep '^[^ ]+ /target' /proc/mounts | (
	while read devpath mountpoint fstype options n1 n2 ; do
		devpath=$(mapdevfs $devpath || echo $devpath)
		mountpoint="${mountpoint#/target}"
		# mountpoint for root will be empty
		if [ -z "$mountpoint" ] ; then
			mountpoint="/"
		fi
		echo $devpath $mountpoint $fstype $options $n1 $n2
	done ) > $mtab
}

chroot_setup () {

	# Bail out if directories we need are not there
	if [ ! -d /target/sbin ] || [ ! -d /target/usr/sbin ] || \
	   [ ! -d /target/proc ]; then
		return 1
	fi
	if [ -d /sys/devices ] && [ ! -d /target/sys ]; then
		return 1
	fi

	if [ -e /var/run/chroot-setup.lock ]; then
		cat >&2 <<EOF
apt-install or in-target is already running, so you cannot run either of
them again until the other instance finishes. You may be able to use
'chroot /target ...' instead.
EOF
		return 1
	fi
	touch /var/run/chroot-setup.lock

	# Create a policy-rc.d to stop maintainer scripts using invoke-rc.d 
	# from running init scripts. In case of maintainer scripts that don't
	# use invoke-rc.d, add a dummy start-stop-daemon.
	cat > /target/usr/sbin/policy-rc.d <<EOF
#!/bin/bash
exit 101
EOF
	chmod a+rx /target/usr/sbin/policy-rc.d
	
	if [ -e /target/sbin/start-stop-daemon ]; then
		mv /target/sbin/start-stop-daemon /target/sbin/start-stop-daemon.REAL
	fi
	cat > /target/sbin/start-stop-daemon <<EOF
#!/bin/bash
echo 1>&2
echo 'Warning: Fake start-stop-daemon called, doing nothing.' 1>&2
exit 0
EOF
	chmod a+rx /target/sbin/start-stop-daemon
	
	# If Upstart is in use, add a dummy initctl to stop it starting jobs.
	if [ -x /target/sbin/initctl ]; then
		mv /target/sbin/initctl /target/sbin/initctl.REAL
		cat > /target/sbin/initctl <<EOF
#!/bin/bash
echo 1>&2
echo 'Warning: Fake initctl called, doing nothing.' 1>&2
exit 0
EOF
		chmod a+rx /target/sbin/initctl
	fi

	# Record the current mounts
	mountpoints > /tmp/mount.pre

	# Some packages (eg. the kernel-image package) require a mounted
	# /proc/. Only mount it if not mounted already
	if [ ! -f /target/proc/cmdline ]; then
		mount -t proc proc /target/proc
	fi

	# For installing >=2.6.14 kernels we also need sysfs mounted
	# Only mount it if not mounted already
	if [ ! -d /target/sys/devices ]; then
		mount -t sysfs sysfs /target/sys
	fi

	# In Lenny, /dev/ lacks the pty devices, so we need devpts mounted
	if [ ! -e /target/dev/pts/0 ]; then
		mkdir -p /target/dev/pts
		mount -t devpts devpts -o noexec,nosuid,gid=5,mode=620 \
			/target/dev/pts
	fi

	mountpoints > /tmp/mount.post

	update_mtab

	LANG="$(cat $TMP/selected-locale)"
	export LANG PERL_BADLANG=0

	return 0
}

chroot_cleanup () {

	if [ -x /target/sbin/initctl.REAL ]; then
		mv /target/sbin/initctl.REAL /target/sbin/initctl
	fi

	# Undo the mounts done by the packages during installation.
	# Reverse sorting to umount the deepest mount points first.
	# Items with count of 1 are new.
	#
	for dir in $( (cat /tmp/mount.pre /tmp/mount.pre; mountpoints ) | \
		     sort -r | uniq -c | grep "^[[:space:]]*1[[:space:]]" | \
		     sed "s/^[[:space:]]*[0-9][[:space:]]//"); do
		if ! umount $dir; then
			logger -t $0 "warning: Unable to umount '$dir'"
		fi
	done

	rm -f /tmp/mount.pre /tmp/mount.post
	rm -f /var/run/chroot-setup.lock
}

# Variant of chroot_cleanup that only cleans up chroot_setup's mounts.
chroot_cleanup_localmounts () {

	rm -f /target/usr/sbin/policy-rc.d
	mv /target/sbin/start-stop-daemon.REAL /target/sbin/start-stop-daemon

	if [ -x /target/sbin/initctl.REAL ]; then
		mv /target/sbin/initctl.REAL /target/sbin/initctl
	fi

	# Undo the mounts done by the packages during installation.
	# Reverse sorting to umount the deepest mount points first.
	# Items with count of 1 are new.
	#
	for dir in $( (cat /tmp/mount.pre /tmp/mount.pre /tmp/mount.post ) | \
		     sort -r | uniq -c | grep "^[[:space:]]*1[[:space:]]" | \
		     sed "s/^[[:space:]]*[0-9][[:space:]]//"); do
		if ! umount $dir; then
			logger -t $0 "warning: Unable to umount '$dir'"
		fi
	done

	rm -f /tmp/mount.pre /tmp/mount.post
	rm -f /var/run/chroot-setup.lock
}

exit 0

