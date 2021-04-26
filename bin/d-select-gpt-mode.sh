#!/bin/bash
#
# d-select-drive.sh create disk partitions <dev@tsert.com>
# Copyright 2013, Pierre Innocent, Tsert Inc. All Rights Reserved
#
TMP=/var/tmp

unlink $TMP/selected-gpt-mode 2> /dev/null

dialog --colors --clear \
	--backtitle "Breeze::OS Kodiak.light Installer" \
	--title "Breeze::OS Kodiak.light Setup (v0.9.0)" \
	--menu "\n\Z1UEFI\Zn stands for Unified Extensible Firmware Interface; and should only be used, if you have a computer preloaded with Windows which is \Z1newer\Zn than 2010; and you want to do the installation on the primary hard drive.\n\n\Z1GPT\Zn stands for GUID Partitioning Table; and allows hard drives greater than 2TB to be partitioned. GPT works with computers \Z1older\Zn than 2010; but should be selected for computers \Z1newer\Zn than 2010.\n\nSelect your partitioning mode ?" 21 65 3 \
"MBR" "Standard partitioning for computers older than 2010" \
"GPT" "Modern partitioning to create partitions > 2TB" \
"EFI" "UEFI partitioning for computers newer than 2010" 2> $TMP/selected-gpt-mode

if [ "$?" != 0 ]; then
	clear
	unlink $TMP/selected-gpt-mode 2> /dev/null
	exit 1
fi

exit 0

