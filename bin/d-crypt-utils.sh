#!/bin/bash
#
# GNU GENERAL PUBLIC LICENSE Version 3
#
# Copyright 2016, Pierre Innocent, Tsert Inc. All Rights Reserved
#
# Initialize folder paths
. d-dirpaths.sh

shred_file()
{
	shred --remove --zero "$1"
	return $?
}

get_crypto_options()
{
	local maindev="$1"
	local driveid="$(basename $1)"

	local cipher="$(extract_value crypto-${driveid} 'cipher')"
	local hashalgo="$(extract_value crypto-${driveid} 'hash')"
	local keysize="$(extract_value crypto-${driveid} 'key-size')"
	local ctype="$(extract_value crypto-${driveid} 'crypto-type')"

	if [ "$ctype" = "encfs" ]; then
		echo "--type luks"
	elif [ "$ctype" = "ecryptfs" ]; then
		echo "--type luks"
	elif [ "$cipher" = "default" ]; then
		echo "--type luks"
	else
		echo "--cipher $cipher --hash $hashalgo --key-size $keysize"
	fi
	return 0
}

init_crypto_encfs()
{
	local rc=1
	local device="$1"
	local folder="$2"
	local user="$3"
	local options="$(get_crypto_options $device)"

	mkdir -p $folder/.encfs 

	if [ "$folder" = "/home" ]; then

		mkdir -p /home/.encfs/$user 
		mv /home/$user /home/${user}.bak
		mkdir -p /home/$user 
		chown $user:users /home/$user /home/.enc/$user 

		encfs $options $folder/.encfs/$user /home/$user

		if [ "$?" = 0 ]; then
			mv /home/${user}.bak/* /home/$user/
			mv /home/${user}.bak/.* /home/$user/
			rm -rf /home/${user}.bak
			rc=0
		fi
	else
		encfs $options $folder/.encfs $folder/
		rc=$?
	fi
	return $rc
}

init_crypto_ecryptfs()
{
	local rc=1
	local device="$1"
	local folder="$2"
	local user="$3"
	local options="$(get_crypto_options $device)"

	ecryptfs $options $device crypto
	rc=$?
	echo "$device"

	return $rc
}

init_crypto_luks()
{
	local maindev="$1"
	local device="$2"
	local crypto="$3"
	local driveid="$(basename $1)"
	local options="$(get_crypto_options $maindev)"
	local rc=1

	if [ "$crypto" = "luks-lvm" ]; then
		cryptsetup $options $device lvmcrypto
		rc=$?
		echo "/dev/mapper/lvmcrypto"

	elif [ "$crypto" = "lvm-luks" ]; then
		cryptsetup $options $device lvmstore
		rc=$?
		echo "/dev/mapper/lvmstore"

	elif [ "$crypto" = "luks" ]; then
		cryptsetup $options $device crypto
		rc=$?
		echo "/dev/mapper/crypto"
	fi

	return $rc
}

restore_luks_header()
{
	local device="$1"
	local target="$2"

	cryptsetup -v --header $hdrfile open $device luks_test 

	if [ $? = 0 ]; then
		mkdir /mnt/luks_test
		mount /dev/mapper/luks_test /mnt/luks_test && ls /mnt/luks_test 

		if [ $? = 0 ]; then
			umount /mnt/luks_test 
			cryptsetup close luks_test 
			sync
			cryptsetup luksHeaderRestore $device \
				--header-backup-file $hdrfile
		fi
	fi
	return $?
}

backup_luks_header()
{
	local device="$1"
	local target="$2"
	# Cryptsetup's luksHeaderBackup action stores a binary backup
	# of the LUKS header and keyslot area:
	cryptsetup luksHeaderBackup $device \
		--header-backup-file $target #/mnt/<backup>/<file>.img
	return $?
}

sleep_one_second() { # somehow sleep in the popen child blocks parent process

	while true; do
		count=$(( $count +  1 ))
		if [ "$count" -gt 1000 ]; then
			break
		fi
		usleep 1000
	done
	return 0
}

# end Breeze::OS script
