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

. d-chroot-setup.sh

if [ -f ${1} ]; then
	EXEC_FILE="$1"

elif [ -f ${BRZDIR}/bin/${1} ]; then
	EXEC_FILE="$BRZDIR/bin/$1"

elif [ -f /tmp/${1} ]; then
	EXEC_FILE="/tmp/$1"
fi

if [ -z "$EXEC_FILE" ]; then
	echo "No such script or utility -- $1" >> $TMP/chroot.err
	echo "INSTALLER: FAILURE L_NO_SUCH_SCRIPT_CHROOT !" 
	exit 1
fi

touch $TMP/chroot.err

cp -af $BRZDIR/bin/d-dirpaths.sh $ROOTDIR/tmp/

cp -af $EXEC_FILE $ROOTDIR/tmp/
EXEC="$(basename $EXEC_FILE)"
chmod a+rx $ROOTDIR/tmp/$EXEC

chroot_setup
chroot $ROOTDIR /tmp/$EXEC
retcode=$?
chroot_cleanup

unlink $ROOTDIR/tmp/$EXEC 2> /dev/null

if [ "$retcode" = 0 ]; then
	echo "INSTALLER: SUCCESS"
	exit 0
fi

echo "Failure $EXEC" >> $TMP/chroot.err
echo "INSTALLER: FAILURE"
exit 1

# end Breeze::OS setup script
