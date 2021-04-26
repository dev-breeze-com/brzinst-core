#!/bin/bash
#
# GNU GENERAL PUBLIC LICENSE Version 3
#
# GNU GENERAL PUBLIC LICENSE Version 3
#
# Copyright 2016, Pierre Innocent, Tsert Inc. All Rights Reserved
#
# Initialize folder paths
#. d-dirpaths.sh

shred_file()
{
    if [ -f "$1" ]; then
        shred --remove --zero "$1"
        return $?
    fi
    return 1
}

#init_luks_container()
#{
#    local container="$CRYPTODIR/lockbox"
#
#    dd if=/dev/zero of=$lockbox bs=4K count=8192
##
#    modprobe cryptoloop ; sync
#
#    loopdev="$(losetup -f 2> /dev/null)"
#
#    if [ -z "$loopdev" ]; then
#        return 1
#    fi
#
#    losetup $loopdev $container
#}

ascii_password()
{
    local count=0
    local times=$1
    local password=""
    #set times i

    while test $count -lt $times ; do
        password="$password$(mktemp -qu 'XXXXXX')"
        count=$(( $count + 1 ))
    done

    echo "$password"
    return 0
}

close_crypto_device()
{
    local dev="$1"
    local hdd="$2"
    local lvmreg="$3"

    if [ -n "$lvmreg" ]; then lvmreg="|/($3)"; fi

    if ! is_safemode_drive $dev ; then
        return 1
    fi

    if ! is_safemode_drive $hdd ; then
        return 1
    fi

    if cryptsetup -v status $dev | grep -qE "${hdd}${lvmreg}" ; then
        cryptsetup luksClose $dev 2>> $TMP/umount.errs
        sync; sleep 1
    fi

    return 0
}

secure_crypto_erase()
{
    local rc=0
    local device="$1"
    local mode="$2"

    if [ -n "$device" ]; then

        if ! is_safemode_drive $device ; then
	    echo_error "L_INVALID_DEVICE_SPECIFIED"
            return 1
        fi

        if [ "$mode" = "zero" ]; then
            dd if=/dev/zero of=$device bs=1M status=none 2> /dev/null
        elif [ "$mode" = "dd" ]; then
            dd if=/dev/urandom of=$device bs=1M status=none 2> /dev/null
        elif [ "$mode" = "shred" ]; then
            shred -n 3 --random-source /dev/urandom $device
        elif [ "$mode" = "dmcrypt" ]; then
            cryptsetup -q open --type plain $device container --key-file /dev/urandom

            rc=$?

            if [ $rc = 0 ]; then
                dd if=/dev/zero of=/dev/mapper/container bs=1M status=none 2> /dev/null
                cryptsetup luksClose container
            fi
        fi
    fi

    return $rc
}

get_crypto_keyname()
{
    local device="$1"

    if [ -n "$device" ]; then
        local vgroup="$(echo "$1" | cut -f3-5 -d/)"
        vgroup="$(echo "$vgroup" | sed 's/\//-/g')"
        echo "$vgroup"
    fi

    return 0
}

get_crypto_devname()
{
    local cryptomode="$1"
    local cryptodev="$2"

    if [ "$cryptomode" = "keys" ]; then
        echo "${cryptodev}"
        return 0
    fi

    if ! grep -qF "${cryptodev}" $TMP/drives-on-atboot.lst ; then
        echo "${cryptodev}"
        return 0
    fi

    for id in 1 2 3 4 5 6 7 8 9 ; do
        if ! grep -qF "${cryptodev}_${id}" $TMP/drives-on-crypto.lst ; then
            echo "${cryptodev}_${id}"
            echo "${cryptodev}_${id}" >> $TMP/drives-on-crypto.lst
            return 0
        fi
    done

    return 1
}

get_keyfile_uniq_path()
{
    echo "$BOOT_CRYPTODIR/${1}-cryptokey.bin"
    return 0
}

get_keyfile_path()
{
    local cmd="$1"
    local drive="$2"
    local device="$3"

    local devid="$(basename $drive)"
    local cryptoname="$(get_crypto_keyname $device)"
    local usekey="$(extract_value crypto-${devid} 'keyfile')"

    if [ "$cmd" = "keys" ]; then
        echo "$BOOT_CRYPTODIR/keys-cryptokey.bin"
    elif [ "$cmd" = "master" ]; then
        echo "$BOOT_CRYPTODIR/brz-cryptokey.bin"
    elif [ "$usekey" = "unique" ]; then
        if [ "$cmd" = "format" ]; then
            echo "$BOOT_CRYPTODIR/brz-cryptokey.bin"
        else
            mkdir -p "$MNT_CRYPTODIR/etc/keys/"
            echo "$MNT_CRYPTODIR/etc/keys/brz-cryptokey.bin"
        fi
    elif [ "$cmd" = "format" ]; then
        echo "$BOOT_CRYPTODIR/${cryptoname}-cryptokey.bin"
    elif [ "$cmd" = "bootpath" ]; then
        local rawuuid="$(get_device_uuid $device)"
        echo "/etc/keys/${rawuuid}-cryptokey.bin"
        #echo "/etc/keys/${cryptoname}-cryptokey.bin"
    elif [ "$cmd" = "luksuuid" ]; then
        local rawuuid="$(get_device_uuid $device)"
        mkdir -p "$MNT_CRYPTODIR/etc/keys/"
        echo "$MNT_CRYPTODIR/etc/keys/${rawuuid}-cryptokey.bin"
    else
        mkdir -p "$MNT_CRYPTODIR/etc/keys/"
        echo "$MNT_CRYPTODIR/etc/keys/${cryptoname}-cryptokey.bin"
    fi

    return 0
}

create_crypto_keyfile()
{
    local rc=1
    local drive="$1"
    local device="$2"
    local cryptomode="$3"

    local hashpasswd="sha1"
    local devid="$(basename $drive)"
    local passwd_file="$BOOT_CRYPTODIR/keys-password.txt"
    local keyfile="$(get_keyfile_path $cryptomode $drive $device)"

    if [ "$cryptomode" = "master" -o "$cryptomode" = "format" ]; then
        dd if=/dev/urandom of=$keyfile bs=512 count=4096 2> /dev/null
        rc=$?
        sync

    elif [ "$cryptomode" = "openssl" ]; then
        openssl rand -base64 48 | \
            gpg --symmetric --cipher-algo aes --armor 1> $CRYPTODIR/key.gpg
        dd if=$CRYPTODIR/key.gpg of=$keyfile 2> /dev/null
        rc=$?
        sync

    elif [ "$cryptomode" = "gpg" ]; then
        dd if=/dev/urandom bs=512 count=4 | \
            gpg -v --cipher-algo aes256 --digest-algo sha512 -c -a \
            1> $CRYPTODIR/key.gpg
        dd if=$CRYPTODIR/key.gpg of=$keyfile 2> /dev/null
        rc=$?
        sync

    elif [ "$cryptomode" = "keys" ]; then

        #hashpasswd="$(extract_value crypto-${devid} 'passwd-type')"

        dd if=/dev/urandom of=$keyfile bs=512 count=4096 2> /dev/null
        rc=$?

        if [ "$hashpasswd" = "md5" ]; then
            md5sum $keyfile | cut -f1 -d' ' 1> $passwd_file
        elif [ "$hashpasswd" = "sha1" ]; then
            sha1sum $keyfile | cut -f1 -d' ' 1> $passwd_file
        elif [ "$hashpasswd" = "sha256" ]; then
            sha256sum $keyfile | cut -f1 -d' ' 1> $passwd_file
        elif [ "$hashpasswd" = "sha512" ]; then
            sha512sum $keyfile | cut -f1 -d' ' 1> $passwd_file
        elif [ "$hashpasswd" = "ascii-12" ]; then
            ascii_password 2 1> $passwd_file
        elif [ "$hashpasswd" = "ascii-24" ]; then
            ascii_password 4 1> $passwd_file
        elif [ "$hashpasswd" = "ascii-48" ]; then
            ascii_password 8 1> $passwd_file
        else
            sha1sum $keyfile | cut -f1 -d' ' 1> $passwd_file
        fi
        sync
    else
        dd if=/dev/urandom of=$keyfile bs=512 count=4096 2> /dev/null
        rc=$?
        sync
    fi

    return $rc
}

store_uuid_cryptokey()
{
    local drive="$1"
    local device="$2"
    local keyfile="$(get_keyfile_path "format" "$drive" "$device")"
    local rawuuid="$(get_device_uuid $device)"
    if [ -z "$rawuuid" ]; then return 1; fi
    dd if=$keyfile of=$BOOT_CRYPTODIR/${rawuuid}-cryptokey.bin 2> /dev/null
    return $?
}

get_crypto_options()
{
    local cmd="$1"
    local drive="$2"
    local crypto="$3"
    local devid="$(basename $1)"

    local keysize="512"
    local cipher="$(extract_value crypto-${devid} 'cipher')"
    local checksum="$(extract_value crypto-${devid} 'hash')"
    local blockmode="$(extract_value crypto-${devid} 'block-mode')"

    if [ "$crypto" = "encfs" ]; then
        echo "-y --type luks"

    elif [ "$crypto" = "luks" ]; then

        if [ "$cipher" = "fastest" ]; then
            cipher="camellia-xts-$blockmode"
        elif [ "$cipher" = "secure" ]; then
            cipher="serpent-xts-$blockmode"
        elif [ "$cipher" = "default" ]; then
            cipher="aes-xts-$blockmode"
        elif [ "$cipher" = "default-128" ]; then
            cipher="aes-xts-$blockmode"
            keysize="256"
        fi

        echo "-y --cipher $cipher --hash $checksum --key-size $keysize --iter-time 3000 --use-random"
    fi
    return 0
}

init_crypto_encfs()
{
    local rc=1
    local drive="$1"
    local device="$2"
    local folder="$3"
    local user="$3"
    local options="$(get_crypto_options $drive encfs)"

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

init_crypto_luks()
{
    local rc=1
    local drive="$1"
    local device="$2"
    local cryptomode="$3"
    local cryptomtpt="$(basename $4)"
    local password="$5"
    local devlabel="$6"

    local devid="$(basename $drive)"
    local crypto="$(extract_value crypto-${devid} 'type')"
    local erasure="$(extract_value crypto-${devid} 'erasure')"
    local usekey="$(extract_value crypto-${devid} 'keyfile')"
    local lukspfx="$(extract_value scheme-${devid} 'lukspfx')"

    local options="$(get_crypto_options $drive $crypto)"
    local keyfile="$(get_keyfile_path "$cryptomode" "$drive" "$device")"

    if [ -z "$lukspfx" ]; then
        lukspfx="luks"
    fi

    if [ "$cryptomtpt" = "/" -o -z "$cryptomtpt" ]; then
        cryptomtpt="${lukspfx}root"
    elif ! echo "$cryptomtpt" | grep -qF 'luks' ; then
        cryptomtpt="${lukspfx}$cryptomtpt"
    fi

    local luksdev="$(get_crypto_devname $cryptomode $cryptomtpt)"

    if ! is_safemode_drive $device ; then
	echo_error "L_INVALID_DEVICE_SPECIFIED"
        return 1
    fi

    if [ -n "$erasure" -a "$erasure" != "none" ]; then
        secure_crypto_erase $device $erasure
    fi

    if [ "$crypto" = "luks" -a "$cryptomode" = "keys" ]; then

        echo "$password" | cryptsetup -q $options luksFormat $device

        if [ $? != 0 ]; then return 1; fi

        echo "$password" | cryptsetup $options luksOpen $device $luksdev

        if [ $? != 0 ]; then return 1; fi

        if create_crypto_keyfile "$drive" "$device" "$cryptomode" ; then
            local passwd_file="$BOOT_CRYPTODIR/keys-password.txt"
            echo "$password" | cryptsetup -d $keyfile luksAddKey $device
            echo "$password" | cryptsetup -d $passwd_file luksAddKey $device
        fi
    elif [ "$crypto" = "luks" ]; then

        if [ -n "$devlabel" -a "$cryptomtpt" = "swap" ]; then
            echo "/dev/mapper/$luksdev"
            return $?
        fi

        if [ "$usekey" != "unique" ]; then
            if ! create_crypto_keyfile "$drive" "$device" "$cryptomode" ; then
                return 1
            fi
        fi

        if ! cryptsetup -q $options luksFormat $device $keyfile ; then
            return 1
        fi

        if ! cryptsetup $options -d $keyfile luksOpen $device $luksdev ; then
            return 1
        fi

        if [ -n "$password" ]; then
            echo "$password" | cryptsetup luksAddKey $device
        fi

        if [ "$cryptomode" != "keys" ]; then
            backup_luks_header $device
        fi
    fi

    echo "/dev/mapper/$luksdev"
    return $?
}

restore_luks_header()
{
    local device="$1"
    local luksname="$(get_crypto_keyname $device)"
    local hdrfile="$BOOT_CRYPTODIR/hdr-${luksname}.img"

    mkdir -p /mnt/lukstest
    mkdir -p /mnt/lukskeys

    if ! is_safemode_drive $device ; then
	echo_error "L_INVALID_DEVICE_SPECIFIED"
        return 1
    fi

    cryptsetup -v --header $hdrfile open $device lukstest 

    if [ $? = 0 ]; then

        mount /dev/mapper/lukstest /mnt/lukstest && ls /mnt/lukstest 

        if [ $? = 0 ]; then
            umount /mnt/lukstest
            sync
            cryptsetup luksClose lukstest
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
    local luksname="$(get_crypto_keyname $device)"
    local hdrfile="$BOOT_CRYPTODIR/hdr-${luksname}.img"

    unlink $hdrfile 2> /dev/null 2> /dev/null

    if ! is_safemode_drive $device ; then
	echo_error "L_INVALID_DEVICE_SPECIFIED"
        return 1
    fi

    # Cryptsetup's luksHeaderBackup action stores a binary backup
    # of the LUKS header and keyslot area:
    cryptsetup luksHeaderBackup $device --header-backup-file $hdrfile

    return $?
}

# end Breeze::OS script
