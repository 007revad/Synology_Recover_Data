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
# https://kb.synology.com/en-global/DSM/tutorial/How_can_I_recover_data_from_my_DiskStation_using_a_PC
#---------------------------------------------------------------------------------------

#mount_path="/home/ubuntu/mount"
mount_path="/home/ubuntu"


scriptver="v0.0.3"
script=Synology_Recover_Data
#repo="007revad/Synology_Recover_Data"
#scriptname=syno_recover_data

# Show script version
#echo -e "$script $scriptver\ngithub.com/$repo\n"
echo -e "$script $scriptver\n"

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
    echo -e "${Error}ERROR${Off} This script must be run as sudo or root!"
    exit 1  # Not running as root
fi

# Check script is NOT running on a Synology NAS
if uname -a | grep -i synology >/dev/null; then
    ding
    echo "This script is running on a Synology NAS!"
    echo "You need to run it from a Linux USB boot drive."
    exit 1  # Is a Synology NAS
fi

# Check script is NOT running on a Asustor NAS
if grep -s 'ASUSTOR' /etc/nas.conf >/dev/null; then
    ding
    echo "This script is running on an Asustor NAS!"
    echo "You need to run it from a Linux USB boot drive."
    exit 1  # Is a Asustor NAS
fi

# Check mount path exists
while [[ ! -d $mount_path ]]; do
    ding
    echo -e "${Cyan}$mount_path${Off} folder does not exist!"
    echo "Enter a valid path to mount your volume(s) then press enter."
    read -r mount_path
done

# Install mdadm, lvm2 and btrfs-progs if missing
install_executable(){ 
    # $1 is mdadm, lvm2 or btrfs-progs
    if ! which "$1" >/dev/null; then
        echo -e "\nInstalling $1"
        apt-get update
        apt-get install -y "$1"
    fi
}
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
    if ! mdadm -AsfR && vgchange -ay ; then
        ding
        echo "Assembling drives failed!"
        exit 1
    fi
else
    ding
    echo "mdadm not install!"
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
        VG="v$(echo -n "$d" | cut -d"v" -f3 | cut -d" " -f1)"
        LV="v$(echo -n "$d" | cut -d"v" -f2 | cut -d" " -f1)"
        device_paths+=("/dev/$VG/$LV")
    done
elif lvs | grep -E 'vg[0-9][0-9]' >/dev/null; then
    # SHR with single volume support
    readarray -t array < <(lvs | grep -E 'vg[0-9][0-9]')

    # lv vg1000 -wi-a----- 43.63t
    # /dev/${VG}/${LV}
    # /dev/vg1000/LV
    for d in "${array[@]}"; do
        VG="v$(echo -n "$d" | cut -d"v" -f3 | cut -d" " -f1)"
        device_paths+=("/dev/$VG/LV")
    done
else
    # Classic RAID with single volume
    readarray -t array < <(cat /proc/mdstat | grep md | cut -d" " -f1)

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
else
    device_path="${device_paths[0]}"
fi

get_mount_dir(){ 
    case "${1,,}" in
        /dev/md*|/dev/vg*/volume_*)
            mount_dir="$(basename -- "$1")"
            ;;
        /dev/vg*/LV)
            mount_dir="$(echo "$1" | cut -d"/" -f2)"
            ;;
    esac
}

get_mount_dir "$device_path"

#echo "mount_dir: $mount_dir"  # debug


# Check user is ready
echo -e "\nType ${Cyan}yes${Off} if you are ready to mount $device_path"
echo "to ${mount_path}/$mount_dir"
read -r answer
if [[ ${answer,,} != "yes" ]]; then
    exit
fi


# NEED TO CREATE A MOUNT POINT FOR EACH DEVICE PATH IN ARRAY IF ALL SELECTED
# Create mount point(s)
echo -e "\nCreating mount point folder(s)"
if [[ ! -d "${mount_path}/$mount_dir" ]]; then
    mkdir -m777 "${mount_path}/$mount_dir"
fi


# NEED TO MOUNT EACH DEVICE PATH IN ARRAY IF ALL SELECTED
# Mount the drives as read only
echo -e "\nMounting volume(s)"
mount "${device_path}" "${mount_path}/${mount_dir}" -o ro
code="$1"

# Finished
if [[ $code != "0" ]]; then
    ding
    echo -e "${Error}ERROR${Off} Failed to mount volume!"
else
    echo -e "\nYou can now recover your data from $mount_path\n"
fi

exit


