#!/bin/bash
#
# Copyright 2013 Pierre Innocent, Tsert Inc. All rights reserved.
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

add_lvm() {

	local lv="$1"
	local vg="$2"
	local percent="$3"
	local mtpt="$4"
	local mbytes="$5"
	local size=$(( $mbytes * $percent / 100 ))
	local vgroup="$(grep -m1 -F "$mtpt," $TMP/lvm-physical.csv | cut -f3 -d',')"

	if [ "$vgroup" != "" ]; then vg="$vgroup"; fi

	footprint=$(( $footprint + $size ))

	echo "$lv,linear,$vg,$size,64,ext4,$mtpt,format" >> $TMP/lvm.lst
	return 0
}

output_results() {

	echo "$footprint" 1> "$TMP/lvm-footprint"
	echo "$lvm_swap_size" 1> "$TMP/lvm-swap-size"

	if [ ! -s $TMP/pvscan.lst ]; then 
		echo "INSTALLER: FAILURE L_NO_PV_FOUND"
		return 1
	fi

	# Output the CSV list
	cat $TMP/pvscan.lst
	return 0
}

argument="$(echo "$1" | tr '[:upper:]' '[:lower:]')"
command="$(echo "$2" | tr '[:upper:]' '[:lower:]')"

SCHEME="$(extract_value scheme 'scheme')"

if [ "$argument" = "pv" ]; then # Physical Volumes

	drives="$(cat $TMP/all-disks | cut -f1 -d' ')"

	unlink $TMP/lvm-partitions.lst 2> /dev/null
	touch $TMP/lvm-partitions.lst 2> /dev/null

	unlink $TMP/pvscan.lst 2> /dev/null
	touch $TMP/pvscan.lst

	footprint=0
	lvm_swap_size=0

	for harddrive in $drives; do

		sgdisk -p $harddrive 1> $TMP/sgdisk.log 2> /dev/null

		grep -E '^[ ]+[0-9]+[ ]' $TMP/sgdisk.log 1> $TMP/sgdisk1.log

		if [ -s $TMP/sgdisk1.log ]; then
			harddrive="$(basename $harddrive)"
			sed -r -i "s/^[ ][ ]*/\/dev\/$harddrive/g" $TMP/sgdisk1.log
			cat $TMP/sgdisk1.log >> $TMP/lvm-partitions.lst
		fi
	done

	crunch_file "$TMP/lvm-partitions.lst" all

	if [ "$command" = "scan" ]; then # Physical Volumes

		pvs --noheadings --segments --nosuffix --verbose \
			--units 'm' --separator ',' 1> $TMP/pv.lst 2> /dev/null

		if [ -s "$TMP/pv.lst" ]; then

			strip_file "$TMP/pv.lst"

			while read line; do

				if ! $(echo "$line" | grep -q -m1 -E '^/') ; then
					continue
				fi

				device="$(echo "$line" | cut -f 1 -d',')"
				vgroup="$(echo "$line" | cut -f 2 -d',')"
				lvolume="$(echo "$line" | cut -f 9 -d',')"
				size="$(echo "$line" | cut -f 5 -d',')"
				size="$(echo "$size" | sed 's/[.].*$//g')"

				footprint=$(( $footprint + $size ))

				echo "yes,$device,$vgroup,$lvolume,$size,keep" >> $TMP/pvscan.lst

			done < $TMP/pv.lst
		fi
		output_results
		exit $?
	fi

	if [ "$command" != "create" ]; then # Physical Volumes
		echo "INSTALLER: FAILURE L_INVALID_ARGUMENT"
		exit 1
	fi

	while read line; do

		device="$(echo "$line" | cut -f 1 -d' ')"
		start="$(echo "$line" | cut -f 2 -d' ')"
		end="$(echo "$line" | cut -f 3 -d' ')"
		ptype="$(echo "$line" | cut -f 6 -d' ' | tr '[:upper:]' '[:lower:]')"

		size=$(( $end - $start ))
		size=$(( $size * 512 / 1024 / 1024 ))

		#line="$(grep -m1 -F "$device" $TMP/pvscan.lst)"
		pline=""

		if test "$size" -le "5" ; then
			continue
		fi

		if [ "$ptype" = "ef02" ]; then
			continue
		fi

		devname="$(basename "$device" | sed 's/[0-9]*//g')"

		if [ -f "$TMP/partitions-${devname}.csv" ]; then
			pline="$(grep -m1 -F "$device" $TMP/partitions-${devname}.csv)"
		fi

		pptype="$(echo "$pline" | cut -f2 -d, | tr '[:upper:]' '[:lower:]')"

		if [ "$pptype" != "8e00" -a "$pptype" != "8200" ]; then
			continue
		fi

		if [ -f "$TMP/partitions-${devname}.csv" ]; then
			pline="$(grep -m1 -F "$device" $TMP/partitions-${devname}.csv)"
		fi

		mtpt="$(echo "$pline" | cut -f5 -d, | sed 's/\///g')"

		if [ "$mtpt" = "" ]; then
			mtpt="root"
		fi

		if [ "$ptype" = "8200" ]; then
			lvm_swap_size=$(( $lvm_swap_size + $size ))
		fi

		footprint=$(( $footprint + $size ))

		if [ "$ptype" = "8200" ]; then
			echo "no,$device,vg_swap,,$size,ignore" >> $TMP/pvscan.lst
		else
			echo "yes,$device,vg_$mtpt,,$size,create" >> $TMP/pvscan.lst
		fi

	done < $TMP/lvm-partitions.lst

	output_results
	exit $?
fi

if [ "$argument" = "lv" ]; then # Logical Volumes

	footprint=0

	lvs --unquoted --noheadings --segments --nosuffix \
		--units 'm' --separator ',' 1> $TMP/lv.lst 2> /dev/null

	unlink $TMP/lvscan.lst 2> /dev/null
	touch $TMP/lvscan.lst

	if [ -s "$TMP/lv.lst" ]; then

		strip_file "$TMP/lv.lst"

		while read line; do

			lvolume="$(echo "$line" | cut -f 1 -d',')"
			vgroup="$(echo "$line" | cut -f 2 -d',')"
			stripe="$(echo "$line" | cut -f 4 -d',')"

			type="$(echo "$line" | cut -f 5 -d',')"
			size="$(echo "$line" | cut -f 6 -d',')"
			size="$(echo "$size" | sed 's/[.].*$//g')"

			device="/dev/${vgroup}/${lvolume}"

			stripe=$(( $stripe * 64 ))
			footprint=$(( $footprint + $size ))

			fstype="$(lsblk -n -l -o 'fstype' $device)"
			mtpt="$(lsblk -n -l -o 'mountpoint' $device)"

			echo "$lvolume,$type,$vgroup,$size,$stripe,$fstype,$mtpt,format" >> $TMP/lvscan.lst
		done < $TMP/lv.lst
	fi

	if [ ! -s "$TMP/lvscan.lst" ]; then

		pvs --noheadings --segments --nosuffix --verbose \
			--units 'm' --separator ',' 1> $TMP/pv.lst 2> /dev/null

		strip_file "$TMP/pv.lst"

		while read line; do

			if ! $(echo "$line" | grep -q -m1 -E '^/') ; then
				continue
			fi

			device="$(echo "$line" | cut -f 1 -d',')"
			vgroup="$(echo "$line" | cut -f 2 -d',')"
			lvolume="$(echo "$line" | cut -f 9 -d',')"
			type="$(echo "$line" | cut -f 11 -d',')"

			size="$(echo "$line" | cut -f 5 -d',')"
			size="$(echo "$size" | sed 's/[.][0-9]*//g')"

			footprint=$(( $footprint + $size ))

			if [ "$lvolume" = "" ]; then
				lvolume="$(echo "$lvolume" | sed 's/vg_/lv_/g')"

				if [ "$vgroup" = "lvmstore" -o "$vgroup" = "vg_root" ]; then
					mtpt="/"
					fstype="ext4"
				elif [ "$vgroup" = "vg_swap" ]; then
					mtpt="/swap"
					fstype="swap"
				else
					mtpt="$(echo "$vgroup" | sed 's/vg_//g')"
					mtpt="/$mtpt"
					fstype="ext4"
				fi
			else
				device="/dev/${vgroup}/${lvolume}"
				fstype="$(lsblk -n -l -o 'fstype' $device)"
				mtpt="$(lsblk -n -l -o 'mountpoint' $device)"
			fi

			echo "$lvolume,$type,$vgroup,$size,64,$fstype,$mtpt,format" >> $TMP/lvscan.lst
		done < $TMP/pv.lst
	fi

#	if [ ! -s "$TMP/lvscan.lst" ]; then
#
#		MBYTES="$(cat $TMP/lvm-footprint 2> /dev/null)"
#		LVM_SWAP="$(cat $TMP/lvm-swap-size 2> /dev/null)"
#		SCHEME="$(cat $TMP/selected-scheme 2> /dev/null)"
#
#		if test $LVM_SWAP -gt 0; then
#			add_lvm lv_swap vg_swap 100 "/swap" $LVM_SWAP
#			MBYTES=$(( $MBYTES - $LVM_SWAP ))
#		fi
#
#		if [ "$SCHEME" = "root" ]; then
#			add_lvm lv_root lvmstore 100 "/" $MBYTES
#
#		elif [ "$SCHEME" = "root-home" ]; then
#			add_lvm lv_root lvmstore 30 "/" $MBYTES
#			add_lvm lv_home lvmstore 70 "/home" $MBYTES
#
#		elif [ "$SCHEME" = "root-var" ]; then
#			add_lvm lv_root lvmstore 20 "/" $MBYTES
#			add_lvm lv_var lvmstore 20 "/var" $MBYTES
#			add_lvm lv_home lvmstore 60 "/home" $MBYTES
#
#		elif [ "$SCHEME" = "root-share" ]; then
#			add_lvm lv_root lvmstore 20 "/" $MBYTES
#			add_lvm lv_var lvmstore 20 "/var" $MBYTES
#			add_lvm lv_share lvmstore 20 "/share" $MBYTES
#			add_lvm lv_home lvmstore 40 "/home" $MBYTES
#
#		elif [ "$SCHEME" = "root-srv" ]; then
#			add_lvm lv_root lvmstore 20 "/" $MBYTES
#			add_lvm lv_home lvmstore 20 "/var" $MBYTES
#			add_lvm lv_share lvmstore 20 "/share" $MBYTES
#			add_lvm lv_srv lvmstore 20 "/srv" $MBYTES
#			add_lvm lv_var lvmstore 20 "/home" $MBYTES
#		fi
#	fi

	echo "$footprint" 1> "$TMP/lvm-footprint"

	if [ ! -s $TMP/lvscan.lst ]; then 
		echo "INSTALLER: FAILURE L_NO_PV_FOUND"
		exit 1
	fi

	# Output the CSV list
	cat $TMP/lvscan.lst
	exit 0
fi

echo "INSTALLER: FAILURE L_INVALID_ARGUMENT"
exit 1

# end Breeze::OS setup script
