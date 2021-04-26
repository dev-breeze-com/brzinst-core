#!/bin/bash
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

BOOT_BLOCK="$(cat $TMP/selected-drive 2> /dev/null)"
DRIVE_TOTAL="$(cat $TMP/drive-total 2> /dev/null)"
SECTOR_SIZE="$(cat $TMP/sector-size 2> /dev/null)"
NB_PACKAGES="$(cat $TMP/total-nb-packages 2> /dev/null)"
DISK_SPACE="$(cat $TMP/total-disk-space 2> /dev/null)"

SELECTED_DRIVE="$(cat $TMP/selected-drive 2> /dev/null)"
SELECTED_DEVICE="$(cat $TMP/selected-device 2> /dev/null)"
SELECTED_SOURCE="$(cat $TMP/selected-source 2> /dev/null)"
SELECTED_TARGET="$(cat $TMP/selected-target 2> /dev/null)"
SELECTED_SOURCE_PATH="$(cat $TMP/selected-source-path 2> /dev/null)"

SELECTED_DESKTOP="$(cat $TMP/selected-desktop 2> /dev/null)"
SELECTED_HOSTNAME="$(cat $TMP/selected-hostname 2> /dev/null)"
SELECTED_KERNEL="$(cat $TMP/selected-kernel 2> /dev/null)"
SELECTED_KEYMAP="$(cat $TMP/selected-keymap 2> /dev/null)"
SELECTED_LOCALE="$(cat $TMP/selected-locale 2> /dev/null)"
SELECTED_TIMEZONE="$(cat $TMP/selected-timezone 2> /dev/null)"
SELECTED_MAPNAME="$(cat $TMP/selected-keymap 2> /dev/null)"
SELECTED_MEDIA="$(cat $TMP/selected-media 2> /dev/null)"
SELECTED_DDCLIENT_FQDN="$(cat $TMP/selected-ddclient-fqdn 2> /dev/null)"
SELECTED_DDCLIENT_PASSWORD="$(cat $TMP/selected-ddclient-password 2> /dev/null)"
SELECTED_DDCLIENT_USER="$(cat $TMP/selected-dclient-username 2> /dev/null)"
SELECTED_HOSTNAME="$(cat $TMP/selected-hostname 2> /dev/null)"
SELECTED_NET="$(cat $TMP/selected-network 2> /dev/null)"
SELECTED_ISP="$(cat $TMP/selected-isp 2> /dev/null)"
SELECTED_ISP_PASSWORD="$(cat $TMP/selected-isp-password 2> /dev/null)"
SELECTED_ISP_USER="$(cat $TMP/selected-isp-username 2> /dev/null)"
SELECTED_KEYBOARD="$(cat $TMP/selected-keyboard 2> /dev/null)"
SELECTED_LOCALE="$(cat $TMP/selected-locale 2> /dev/null)"
SELECTED_MEDIA="$(cat $TMP/selected-media 2> /dev/null)"
SELECTED_PASSWORD="$(cat $TMP/selected-password 2> /dev/null)"
SELECTED_SCHEME="$(cat $TMP/selected-scheme 2> /dev/null)"
SELECTED_USER="$(cat $TMP/selected-username 2> /dev/null)"

