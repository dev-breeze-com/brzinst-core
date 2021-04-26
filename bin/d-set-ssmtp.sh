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

ROOT="$(extract_value root ssmtp)"
MAILHUB="$(extract_value mailhub ssmtp)"
REWRITE="$(extract_value domain ssmtp)"
HOSTNAME="$(extract_value hostname ssmtp)"
USETLS="$(extract_value 'use-tls' ssmtp)"
OVERRIDE="$(extract_value 'override' ssmtp)"

SSMTP="$ROOTDIR/etc/ssmp/ssmtp.conf"

/bin/sed -i "s/^root=.*$/root=$ROOT/g" $SSMTP
/bin/sed -i "s/^mailhub=.*$/mailhub=$MAILHUB/g" $SSMTP
/bin/sed -i "s/^hostname.*$/hostname=$HOSTNAME/g" $SSMTP
/bin/sed -i "s/^From.*$/FromLineOverride=$OVERRIDE/g" $SSMTP
/bin/sed -i "s/^rewrite.*$/rewriteDomain=$REWRITE/g" $SSMTP
/bin/sed -i "s/^AuthUser.*$/AuthUser=$USERNAME/g" $SSMTP
/bin/sed -i "s/^AuthPass.*$/AuthPass=$PASSWORD/g" $SSMTP
/bin/sed -i "s/^Use.*$/UseTLS=$USETLS/g" $SSMTP

exit 0

# end Breeze::OS setup script
