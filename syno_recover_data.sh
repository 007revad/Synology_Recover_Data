#!/usr/bin/env bash
# shellcheck disable=SC2002
#---------------------------------------------------------------------------------------
# Recover data from Synology drives using a computer
#
# GitHub: https://github.com/007revad/Synology_Recover_Data
# Script verified at https://www.shellcheck.net/
#
# Run in Ubuntu terminal:
# sudo -i /home/ubuntu/syno_recover_data.sh
#
#---------------------------------------------------------------------------------------
# Resources used to develop this script:
#
# https://kb.synology.com/en-global/DSM/tutorial/How_can_I_recover_data_from_my_DiskStation_using_a_PC
#
# https://xpenology.com/forum/topic/54545-dsm-7-and-storage-poolarray-functionality/
#
#---------------------------------------------------------------------------------------
# Ubuntu 20.04.6 LTS and 22.04.4 LTS issues:
#
# WARNING: PV /dev/sdX in VG vgXX is using an old PV header, modify the VG to update
# https://access.redhat.com/solutions/5906681
# Can we just ignore the warning and not update header?
# https://community.synology.com/enu/forum/1/post/155289
#
# The latest mdadm does not support DSM's superblock location
# mount: /dev/XXXX: can't read superblock
# https://gist.github.com/cllu/5da648850ecfd30211bba140b132e824
# 
#---------------------------------------------------------------------------------------
# Ubuntu 19.10 issues (solved)
#
# Getting old Ubuntu versions to download mdadm
# https://community.synology.com/enu/forum/1/post/155289
#
# Installing curl fails with 'apt-get install curl' so had to use 'apt install curl'
#---------------------------------------------------------------------------------------

#mount_path="/mnt"
#mount_path="/media"
mount_path="/home/ubuntu"

home_path="/home/ubuntu"  # Location of .rkey files for decrypting volumes


scriptver="v1.1.13"
script=Synology_Recover_Data
repo="007revad/Synology_Recover_Data"

# Show script version
#echo -e "$script $scriptver\ngithub.com/$repo\n"
echo "$script $scriptver"

# Shell Colors
#Black='\e[0;30m'   # ${Black}
#Red='\e[0;31m'     # ${Red}
#Green='\e[0;32m'   # ${Green}
#Yellow='\e[0;33m'  # ${Yellow}
#Blue='\e[0;34m'    # ${Blue}
#Purple='\e[0;35m'  # ${Purple}
Cyan='\e[0;36m'     # ${Cyan}
#White='\e[0;37m'   # ${White}
Error='\e[41m'      # ${Error}
Off='\e[0m'         # ${Off}

ding(){ 
    printf \\a
}

# Check script is running as root
if [[ $( whoami ) != "root" ]]; then
    ding
    echo -e "\n${Error}ERROR${Off} This script must be run as sudo or root!"
    exit 1  # Not running as root
fi

# Check script is NOT running on a Synology NAS
if uname -a | grep -i synology >/dev/null; then
    ding
    echo -e "\nThis script is running on a Synology NAS!"
    echo "You need to run it from a Linux USB boot drive."
    exit 1  # Is a Synology NAS
fi

# Check script is NOT running on a Asustor NAS
if grep -s 'ASUSTOR' /etc/nas.conf >/dev/null; then
    ding
    echo -e "\nThis script is running on an Asustor NAS!"
    echo "You need to run it from a Linux USB boot drive."
    exit 1  # Is a Asustor NAS
fi

# Check mount path exists
while [[ ! -d $mount_path ]]; do
    ding
    echo -e "\n${Cyan}$mount_path${Off} folder does not exist!"
    echo "Enter a valid path to mount your volume(s) then press enter."
    read -r mount_path
done

# Set Ubuntu to get older version of mdadm that works with DSM's superblock location
sed -i "s|archive.ubuntu|old-releases.ubuntu|" /etc/apt/sources.list
sed -i "s|security.ubuntu|old-releases.ubuntu|" /etc/apt/sources.list

install_executable(){ 
    # $1 is mdadm, lvm2 or btrfs-progs
    #if ! apt list --installed | grep -q "^${1}/"; then  # Don't use apt in script
    if ! apt-cache show "$1" >/dev/null; then
        echo -e "\nInstalling $1"
        if [[ $aptget_updated != "yes" ]]; then
            apt-get update
            aptget_updated="yes"
        fi
        if [[ $1 == "mdadm" ]]; then
            # apt-get won't install mdadm in Ubuntu 19.10
            apt install -y mdadm
        else
            apt-get install -y "$1"
        fi
    fi
}

# Install curl if missing
install_executable curl

#------------------------------------------------------------------------------
# Check latest release with GitHub API

# Get latest release info
# Curl timeout options:
# https://unix.stackexchange.com/questions/94604/does-curl-have-a-timeout
release=$(curl --silent -m 10 --connect-timeout 5 \
    "https://api.github.com/repos/$repo/releases/latest")

# Release version
tag=$(echo "$release" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
#shorttag="${tag:1}"

if ! printf "%s\n%s\n" "$tag" "$scriptver" |
        sort --check=quiet --version-sort >/dev/null ; then
    echo -e "\n${Cyan}There is a newer version of this script available.${Off}"
    echo -e "Current version: ${scriptver}\nLatest version:  $tag"
fi

#------------------------------------------------------------------------------

# Install mdadm, lvm2 and btrfs-progs if missing
install_executable mdadm
install_executable lvm2
install_executable btrfs-progs

# Assemble all the drives removed from the Synology NAS
if which mdadm >/dev/null; then
    echo -e "\nAssembling your Synology drives"
    # mdadm options:
    # -A --assemble  Assemble a previously created array.
    # -s --scan      Scan config file for missing information.
    # -f --force     Assemble the array even if some superblocks appear out-of-date.
    #                This involves modifying the superblocks.
    # -R --run       Try to start the array even if not enough devices for a full array are present.
#    if ! mdadm -AsfR && vgchange -ay ; then
#        ding
#        echo -e "${Error}ERROR${Off} Assembling drives failed!"
#        exit 1
    mdadm -AsfR  # Ignore "no arrays found" because it could be a single drive
    vgchange -ay
#    fi
else
    ding
    echo -e "${Error}ERROR${Off} mdadm not installed!"
    exit 1
fi

# Get device path(s)
if lvs | grep 'volume_' >/dev/null; then
    # Classic RAID/SHR with multiple volume support
    readarray -t array < <(lvs | grep 'volume_')

    # volume_1 vg1 -wi-ao---- 43.63t
    # /dev/${VG}/${LV}
    # /dev/vg1/volume_1
    for d in "${array[@]}"; do
        LV="$(echo -n "$d" | awk '{print $1}')"
        VG="$(echo -n "$d" | awk '{print $2}')"
        device_paths+=("/dev/$VG/$LV")
    done
elif lvs | grep -E 'vg[0-9][0-9][0-9][0-9]' >/dev/null; then
    # SHR with single volume support
    readarray -t array < <(lvs | grep -E 'vg[0-9][0-9][0-9][0-9]')

    # lv vg1000 -wi-a----- 43.63t
    # /dev/${VG}/${LV}
    # /dev/vg1000/lv
    for d in "${array[@]}"; do
        LV="$(echo -n "$d" | awk '{print $1}')"
        VG="$(echo -n "$d" | awk '{print $2}')"
        device_paths+=("/dev/$VG/$LV")
    done
else
    # Classic RAID with single volume
    readarray -t array < <(cat /proc/mdstat | grep '^md' | awk '{print $1}')

    # /dev/${md}
    # /dev/md4
    for d in "${array[@]}"; do
        if [[ $d != "md0" ]] && [[ $d != "md1" ]]; then
            device_paths+=("/dev/$d")
        fi
    done
fi

# Ask user which device they want to mount (if there's more than 1)
if [[ ${#device_paths[@]} -gt "1" ]]; then
    echo ""
    PS3="Select the volume to mount: "
    select device_path in "${device_paths[@]}"; do
        if [[ $device_path ]]; then
            if [[ -L $device_path ]]; then
                echo "You selected $device_path"
                break
            else
                ding
                echo -e "Line ${LINENO}: ${Error}ERROR${Off} $device_path not found!"
                exit 1  # Selected device_path not found
            fi
        else
            echo "Invalid choice!"
        fi
    done
elif [[ ${#device_paths[@]} -eq "1" ]]; then
    device_path="${device_paths[0]}"
else
    ding
    echo -e "\n${Error}ERROR${Off} No volumes found!"
    exit 1  # No volumes found
fi

get_mount_dir(){ 
    case "${1,,}" in
        /dev/md*)
            mount_dir="$(basename -- "$1")"
            ;;
        /dev/vg*/volume_*)
            mount_dir="$(basename -- "$1")"
            maybe_encripted="yes"
            ;;
        /dev/vg*/lv)
            mount_dir="$(echo "$1" | cut -d"/" -f3)"
            ;;
    esac
}

get_mount_dir "$device_path"

# Check if volume is already mounted
if findmnt "${mount_path}/$mount_dir" >/dev/null; then
    echo -e "\n$device_path already mounted to ${mount_path}/$mount_dir"
    findmnt "${mount_path}/$mount_dir"  # debug
    echo -e "\nYou can recover your data from:"
    echo -e "- Files > Home > ${Cyan}${mount_dir}${Off}"
    echo -e "- Files > ${Cyan}${mount_dir}${Off}"
    echo -e "- ${Cyan}${mount_path}/${mount_dir}${Off} via Terminal\n"
    exit
fi

# Check user is ready
echo -e "\nType ${Cyan}yes${Off} if you are ready to mount $device_path"
echo "to ${mount_path}/$mount_dir"
read -r answer
if [[ ${answer,,} != "yes" ]]; then
    exit
fi

get_rkeys(){ 
    # [NASNAME]_volume1.rkey
    rkeys=( )
    for rkey in "${home_path}"/*_volume"${device_path##*_}".rkey; do
        #echo "$rkey"  # debug
        if [[ -f "$rkey" ]]; then
            rkeys+=("$rkey")
        fi
    done
}

select_rkey(){ 
    echo ""
    if [[ ${#rkeys[@]} -gt 1 ]]; then
        PS3="Select the correct recovery key: "
        select recovery_key in "${rkeys[@]}"; do
            if [[ $recovery_key ]]; then
                if [[ -f $recovery_key ]]; then
                    echo -e "You selected $recovery_key"
                    break
                else
                    ding
                    echo -e "Line ${LINENO}: ${Error}ERROR${Off} $recovery_key not found!"
                    exit 1  # Selected recovery key not found
                fi
            else
                echo "Invalid choice!"
            fi
        done
    elif [[ ${#rkeys[@]} -eq 1 ]]; then
        recovery_key=${rkeys[0]}
        echo -e "Using recovery key: $recovery_key"
    else
        ding
        echo -e "Line ${LINENO}: ${Error}ERROR${Off} No recovery key found!"
        exit 1  # No recovery key found
    fi
}

# Encrypted volume
if [[ $maybe_encripted == "yes" ]]; then
    echo -e "\nType ${Cyan}yes${Off} if $mount_dir is an encrypted volume"
    read -r answer
    if [[ ${answer,,} == "yes" ]]; then
        # Get recovery key
        get_rkeys
        select_rkey

        # Install cryptsetup if missing
        install_executable cryptsetup

        # Decode recovery key to file
        base64_decode_output_path="${recovery_key%.*}"
        base64 --decode "${recovery_key}" > "${base64_decode_output_path}"
        code="$?"
        if [[ $code -gt "0" ]]; then exit 1; fi

        # Test recovery key
        # cryptsetup open --test-passphrase /dev/vgX/volume_Y -S 1 -d ${base64_decode_output_path}
        cryptsetup open --test-passphrase "$device_path" -S 1 -d "${base64_decode_output_path}"
        code="$?"
        if [[ $code -gt "0" ]]; then exit 1; fi

        # Decrypt the encrypted volume
        cryptvol="cryptvol_${device_path##*_}"
        #echo "cryptvol: $device_path"  # debug

        # Remove any existing /dev/mapper/cryptvol_${device_path##*_}
        if [[ -e "/dev/mapper/$cryptvol" ]]; then
            umount -f "/dev/mapper/$cryptvol"
            dmsetup remove -f "/dev/mapper/$cryptvol"
        fi

        # cryptsetup open --allow-discards /dev/vgX/volume_Y cryptvol_Y -S 1 -d ${base64_decode_output_path}
        cryptsetup open --allow-discards "$device_path" "$cryptvol" -S 1 -d "${base64_decode_output_path}"
        code="$?"
        #if [[ $code -gt "0" ]]; then exit 1; fi

        # Set device_path
        device_path="/dev/mapper/$cryptvol"
        #echo "device_path: $device_path"  # debug
    fi
fi


# NEED TO CREATE A MOUNT POINT FOR EACH DEVICE PATH IN ARRAY IF ALL SELECTED
# Create mount point(s)
echo -e "\nCreating mount point folder(s)"
if [[ ! -d "${mount_path}/$mount_dir" ]]; then
    #mkdir -m777 "${mount_path}/$mount_dir"
    #mkdir -m444 "${mount_path}/$mount_dir"
    mkdir -m744 "${mount_path}/$mount_dir"

    # Allow user to unmount volume from UI
    chown ubuntu "${mount_path}/$mount_dir"
fi


# NEED TO MOUNT EACH DEVICE PATH IN ARRAY IF ALL SELECTED
# Mount the volume as read only
echo -e "\nMounting volume(s)"
mount "${device_path}" "${mount_path}/${mount_dir}" -o ro
code="$1"
#
# mount has the following return codes (the bits can be ORed):
# 0 success
# 1 incorrect invocation or permissions
# 2 system error (out of memory, cannot fork, no more loop devices)
# 4 internal mount bug or missing nfs support in mount
# 8 user interrupt
# 16 problems writing or locking /etc/mtab
# 32 mount failure
# 64 some mount succeeded

# Finished
if [[ $code -gt "0" ]]; then
    ding
    echo -e "${Error}ERROR${Off} $code Failed to mount volume!\n"
else
    # Successful mount has null exit code
    echo -e "\nThe volume is now mounted as ${Cyan}read only.${Off}\n"
    echo -e "You can now recover your data from:"
    echo -e "- Files > Home > ${Cyan}${mount_dir}${Off}"
    echo -e "- Files > ${Cyan}${mount_dir}${Off}"
    echo -e "- ${Cyan}${mount_path}/${mount_dir}${Off} via Terminal\n"
fi

exit

