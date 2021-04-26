#!/bin/sh
#
# rc.pcmcia: Script to initialize PCMCIA subsystem.
#	     Based in an example found in cardmgr-to-pcmciautils.txt
#	     and in Slackware rc.pcmcia found in pcmcia-cs package.
#

# Set this to the driver to use, one of:
# probe, yenta_socket, i82365, i82092, pd6729, tcic, etc.
#
DRIVER=probe
DRIVER_OPTS=

. d-dirpaths.sh

case "$1" in
	start)
		d-wifi-modprobe.sh

		echo "Starting PCMCIA services:"
		fgrep -q pcmcia /proc/devices

		if [ $? -ne 0 ] ; then
			if [ "$DRIVER" = "probe" ]; then
			   echo "  <Probing for PCIC: edit /etc/rc.d/rc.pcmcia>"
			   for DRV in yenta_socket i82365 tcic ; do
				modprobe $DRV > /dev/null 2>&1
				pccardctl status | grep -q Socket && break 
				modprobe -r $DRV > /dev/null 2>&1
			   done
			else
			echo "  <Loading PCIC: $DRIVER>"
			   modprobe $DRIVER $DRIVER_OPTS > /dev/null 2>&1
			fi
			modprobe pcmcia > /dev/null 2>&1 # just in case it's not auto-loaded
		else
			echo "  <PCIC already loaded>"
		fi
		;;

	stop)
        echo -n "Shutting down PCMCIA services: "
		echo -n "cards "
		pccardctl eject
		MODULES=`/sbin/lsmod | grep "pcmcia " | awk '{print $4}' | tr , ' '`

		for i in $MODULES ; do
			echo -n "$i "
			modprobe -r $i > /dev/null 2>&1
		done

		echo -n "pcmcia "
		modprobe -r pcmcia > /dev/null 2>&1

		if [ "$DRIVER" = "probe" ]; then
			for DRV in yenta_socket i82365 tcic ; do
				grep -qw $DRV /proc/modules && modprobe -r $DRV && \
					echo -n "$DRV " && break
			done
		else	
			modprobe -r $DRIVER > /dev/null 2>&1
		fi
		echo -n "rsrc_nonstatic "
		modprobe -r rsrc_nonstatic > /dev/null 2>&1
		echo "pcmcia_core"
		modprobe -r pcmcia_core > /dev/null 2>&1
		;;
	
	restart)
		$0 stop
		$0 start
		;;
esac

exit 0
