#!/bin/bash
#
# Copyright 2011 Pierre Innocent, Tsert Inc. All rights reserved.
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
ROOTDIR=/mnt/root

cd $ROOTDIR

if [ ! -d media ]; then
	mkdir media
fi

cd media

if ! [ -d cdrom0 ]; then
	mkdir cdrom0
	ln -s cdrom0/ cdrom
fi

if ! [ -d usb0 ]; then
	mkdir usb0
	ln -s usb0/ usb
fi

if ! [ -d dvd0 ]; then
	mkdir dvd0
	ln -s dvd0/ dvd
	ln -s dvd0/ sr0
fi

if ! [ -d floppy0 ]; then
	mkdir floppy0
	ln -s floppy0/ floppy
fi

exit 0

