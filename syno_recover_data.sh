#!/usr/bin/env bash
# shellcheck disable=SC2002
#---------------------------------------------------------------------------------------
# Recover data from Synology drives using a computer
#
# GitHub: https://github.com/007revad/Synology_Recover_Data
# Script verified at https://www.shellcheck.net/
#
# Run in Ubuntu terminal:
# sudo bash /cdrom/syno_recover_data.sh
#
#---------------------------------------------------------------------------------------
# Resources used to develop this script:
#
# https://kb.synology.com/en-global/DSM/tutorial/How_can_I_recover_data_from_my_DiskStation_using_a_PC
#
# https://xpenology.com/forum/topic/54545-dsm-7-and-storage-poolarray-functionality/
#
# https://askubuntu.com/questions/517136/list-of-ubuntu-versions-with-corresponding-linux-kernel-version
#
#---------------------------------------------------------------------------------------
# https://isc.sans.edu/diary/rss/30904
# mdadm --assemble --readonly --scan --force --run
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
#
#---------------------------------------------------------------------------------------

#mount_path="/mnt"
#mount_path="/media"
mount_path="/home/ubuntu"

home_path="/home/ubuntu"  # Location of .rkey files for decrypting volumes

# Set up paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOME_DIR="/home/ubuntu"  # Location for log files and compiled binaries
MDADM_BINARY="${HOME_DIR}/mdadm-3.4"
BTRFS_MODULE="${SCRIPT_DIR}/btrfs.ko"
CRYPTSETUP_BINARY="${HOME_DIR}/cryptsetup-static"

scriptver="v2.0.19"
script=Synology_Recover_Data
repo="007revad/Synology_Recover_Data"

# Show script version
#echo -e "$script $scriptver\ngithub.com/$repo\n"
echo "$script $scriptver"

# Linux distributor and version
lsb_release -ds

linux_version=$(lsb_release -rs)
linux_distro=$(lsb_release -is)

# Detect host architecture for lib paths and .deb downloads
host_arch=$(dpkg --print-architecture)              # e.g. amd64, arm64
#lib_arch=$(dpkg-architecture -qDEB_HOST_MULTIARCH)  # e.g. x86_64-linux-gnu, aarch64-linux-gnu
lib_arch=$(dpkg-architecture -qDEB_HOST_MULTIARCH 2>/dev/null || gcc -print-multiarch 2>/dev/null || echo "x86_64-linux-gnu")

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
#sed -i "s|archive.ubuntu|old-releases.ubuntu|" /etc/apt/sources.list
##sed -i "s|security.ubuntu|old-releases.ubuntu|" /etc/apt/sources.list
##sed -i "s|old-releases.ubuntu|security.ubuntu|" /etc/apt/sources.list

install_executable(){ 
    # $1 is mdadm, lvm2 or btrfs-progs
    code=""
    if [[ $aptget_updated != "yes" ]]; then
        apt-get update > /dev/null 2>&1
        aptget_updated="yes"
    fi
    if [[ $1 == "lvm2" ]] && [[ $linux_version == "18.04" ]]; then
        # Ubuntu 18.04 needs the full lvm2 installed
        apt-get install -y "lvm2" 1>/dev/null
        code="$?"
    else
        #if ! apt list --installed | grep -q "^${1}/"; then  # Don't use apt in script
        #if ! apt-cache show "$1" >/dev/null; then
        # https://stackoverflow.com/questions/1298066/how-can-i-check-if-a-package-is-installed-and-install-it-if-not
        if ! dpkg-query -s "$1" >/dev/null; then
            echo -e "\n${Cyan}Installing $1${Off}"
#            if [[ $1 == "mdadm" ]]; then
#                # apt-get won't install mdadm in Ubuntu 19.10
#                apt install -y mdadm 1>/dev/null
#                code="$?"
#            else
                apt-get install -y "$1" 1>/dev/null
                code="$?"
#            fi
        fi
    fi
    if [[ $code -gt "0" ]]; then
        ding
        echo -e "${Error}Error $code${Off} Failed to install $1"
    fi
}

# Install curl if missing
# Changed to use wget instead to avoid installing curl
#install_executable curl

#------------------------------------------------------------------------------
# Check latest release with GitHub API

# Get latest release info
# Curl timeout options:
# https://unix.stackexchange.com/questions/94604/does-curl-have-a-timeout
#release=$(curl --silent -m 10 --connect-timeout 5 \
#    "https://api.github.com/repos/$repo/releases/latest")

# Use wget to avoid installing curl in Ubuntu
release=$(wget -qO- -q --connect-timeout=5 \
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
#install_executable mdadm
#install_executable lvm2
#install_executable btrfs-progs

# Compile mdadm-3.4 from source if binary is missing
if [[ ! -x "$MDADM_BINARY" ]]; then
    echo -e "\n${Cyan}Compiling mdadm 3.4 from source...${Off}"
    mdadm_log="${HOME_DIR}/mdadm_compile.log"
    mdadm_src="${HOME_DIR}/mdadm-3.4"

    # Install build dependencies
    # apt-get no longer works in Ubuntu 19.10 (apt repo no longer exists)
    #apt-get install -y build-essential > "$mdadm_log" 2>&1

    # Download source
    echo "Downloading mdadm 3.4 source..." | tee "$mdadm_log"
    wget -q --connect-timeout=10 \
        "https://mirrors.edge.kernel.org/pub/linux/utils/raid/mdadm/mdadm-3.4.tar.gz" \
        -O "${HOME_DIR}/mdadm-3.4.tar.gz" >> "$mdadm_log" 2>&1

    if [[ ! -s "${HOME_DIR}/mdadm-3.4.tar.gz" ]]; then
        ding
        echo -e "${Error}ERROR${Off} Failed to download mdadm source!"
        exit 1
    fi

    # Extract
    echo "Extracting..." | tee -a "$mdadm_log"
    tar xzf "${HOME_DIR}/mdadm-3.4.tar.gz" -C "$HOME_DIR" >> "$mdadm_log" 2>&1
    chown -R ubuntu:ubuntu "${mdadm_src}"

    # Patch and compile
    echo "Compiling..." | tee -a "$mdadm_log"
    for f in "${mdadm_src}"/*.c; do
        sed -i '1s/^/#include <sys\/sysmacros.h>\n/' "$f"
    done
    make -C "$mdadm_src" \
        LDFLAGS="-static" \
        CFLAGS="-Wall -Wstrict-prototypes -ggdb -DNO_COROSYNC -DNO_DLM -D_GNU_SOURCE" \
        >> "$mdadm_log" 2>&1
    code="$?"

    if [[ $code -gt "0" ]] || [[ ! -x "$MDADM_BINARY" ]]; then
        ding
        echo -e "${Error}ERROR${Off} Failed to compile mdadm! See $mdadm_log"
        exit 1
    fi

    echo -e "${Cyan}mdadm compiled successfully.${Off}"

    # Cleanup source files to save space
    rm -f "${HOME_DIR}/mdadm-3.4.tar.gz"
    # Save the binary, then remove entire source dir and restore binary
    mv "${mdadm_src}/mdadm" "${HOME_DIR}/mdadm-3.4-static"
    rm -rf "${mdadm_src}"
    mv "${HOME_DIR}/mdadm-3.4-static" "${HOME_DIR}/mdadm-3.4"

    chown ubuntu "${HOME_DIR}/mdadm-3.4"
    chown ubuntu "${mdadm_log}"
fi

# Compile libdevmapper.a from lvm2 source if missing (needed for cryptsetup static build)
if [[ ! -s "/usr/lib/${lib_arch}/libdevmapper.a" ]]; then
    echo -e "\n${Cyan}Compiling libdevmapper.a from lvm2 source...${Off}"
    lvm2_log="${HOME_DIR}/lvm2_compile.log"
    lvm2_src="${HOME_DIR}/LVM2.2.03.02"

    # Download source
    echo "Downloading lvm2 2.03.02 source..." | tee "$lvm2_log"
    wget -q --connect-timeout=10 \
        "https://sourceware.org/pub/lvm2/LVM2.2.03.02.tgz" \
        -O "${HOME_DIR}/LVM2.2.03.02.tgz" >> "$lvm2_log" 2>&1

    if [[ ! -s "${HOME_DIR}/LVM2.2.03.02.tgz" ]]; then
        ding
        echo -e "${Error}ERROR${Off} Failed to download lvm2 source!"
        exit 1
    fi

    # Extract
    echo "Extracting..." | tee -a "$lvm2_log"
    tar xzf "${HOME_DIR}/LVM2.2.03.02.tgz" -C "$HOME_DIR" >> "$lvm2_log" 2>&1
    chown -R ubuntu:ubuntu "${lvm2_src}"

    echo "Patching libaio.h..." | tee -a "$lvm2_log"
    mkdir -p /usr/local/include
    echo '#ifndef LIBAIO_H' > /usr/local/include/libaio.h
    echo '#define LIBAIO_H' >> /usr/local/include/libaio.h
    echo '#endif' >> /usr/local/include/libaio.h

    # Configure and build just device-mapper
    echo "Configuring..." | tee -a "$lvm2_log"
    (cd "$lvm2_src" && ./configure \
        --enable-static_link \
        --disable-selinux \
        --disable-udev-systemd-background-jobs \
        --with-cache=none \
        --with-mirrors=none \
        --with-snapshots=none \
        --disable-readline \
        --disable-libaio \
        >> "$lvm2_log" 2>&1)
    code="$?"

    if [[ $code -gt "0" ]]; then
        ding
        echo -e "${Error}ERROR${Off} Failed to configure lvm2! See $lvm2_log"
        exit 1
    fi

    echo "Compiling libdevmapper.a..." | tee -a "$lvm2_log"
    make -C "$lvm2_src" device-mapper >> "$lvm2_log" 2>&1
    code="$?"

    if [[ ! -s "${lvm2_src}/libdm/ioctl/libdevmapper.a" ]]; then
        ding
        echo -e "${Error}ERROR${Off} Failed to compile libdevmapper.a! See $lvm2_log"
        exit 1
    fi

    # Install static lib so cryptsetup configure and linker can find it
    cp "${lvm2_src}/libdm/ioctl/libdevmapper.a" "/usr/lib/${lib_arch}/"
    echo -e "${Cyan}libdevmapper.a compiled successfully.${Off}"

    # Cleanup
    rm -f "${HOME_DIR}/LVM2.2.03.02.tgz"
    rm -rf "${lvm2_src}"

    chown ubuntu "$lvm2_log"
fi

# Compile cryptsetup 2.4.3 from source if binary is missing
if [[ ! -x "$CRYPTSETUP_BINARY" ]]; then
    echo -e "\n${Cyan}Compiling cryptsetup 2.4.3 from source...${Off}"
    cryptsetup_log="${HOME_DIR}/cryptsetup_compile.log"
    cryptsetup_src="${HOME_DIR}/cryptsetup-2.4.3"

    # Install build dependencies from old-releases (apt-get no longer works on Ubuntu 19.10)
    echo "Installing build dependencies..." | tee "$cryptsetup_log"
    old_releases="http://old-releases.ubuntu.com/ubuntu/pool"
    deps=(
            "main/l/lvm2/libdevmapper-dev_1.02.155-2ubuntu6_${host_arch}.deb"
            "main/p/popt/libpopt-dev_1.16-12_${host_arch}.deb"
            "main/o/openssl/libssl-dev_1.1.1c-1ubuntu4_${host_arch}.deb"
            "main/u/util-linux/uuid-dev_2.34-0.1ubuntu2_${host_arch}.deb"
            "main/j/json-c/libjson-c-dev_0.13.1+dfsg-4ubuntu0.3_${host_arch}.deb"
            "main/u/util-linux/libblkid-dev_2.34-0.1ubuntu2_${host_arch}.deb"
            "main/s/systemd/libudev-dev_242-7ubuntu3_${host_arch}.deb"
            "main/libs/libselinux/libselinux1-dev_2.9-2_${host_arch}.deb"
            "main/libs/libsepol/libsepol1-dev_2.9-2_${host_arch}.deb"
        )
    for dep in "${deps[@]}"; do
        deb="${HOME_DIR}/$(basename "$dep")"
        if ! dpkg-query -s "$(basename "$dep" | cut -d_ -f1)" >/dev/null 2>&1; then
            wget -q --connect-timeout=10 "${old_releases}/${dep}" -O "$deb" >> "$cryptsetup_log" 2>&1
            if [[ ! -s "$deb" ]]; then
                ding
                echo -e "${Error}ERROR${Off} Failed to download $(basename "$dep")!"
                exit 1
            fi
            dpkg -i --force-depends "$deb" >> "$cryptsetup_log" 2>&1
            rm -f "$deb"
        fi
    done

    # Download source
    echo "Downloading cryptsetup 2.4.3 source..." | tee -a "$cryptsetup_log"
    wget -q --connect-timeout=10 \
        "https://cdn.kernel.org/pub/linux/utils/cryptsetup/v2.4/cryptsetup-2.4.3.tar.gz" \
        -O "${HOME_DIR}/cryptsetup-2.4.3.tar.gz" >> "$cryptsetup_log" 2>&1

    if [[ ! -s "${HOME_DIR}/cryptsetup-2.4.3.tar.gz" ]]; then
        ding
        echo -e "${Error}ERROR${Off} Failed to download cryptsetup source!"
        exit 1
    fi

    # Extract
    echo "Extracting..." | tee -a "$cryptsetup_log"
    tar xzf "${HOME_DIR}/cryptsetup-2.4.3.tar.gz" -C "$HOME_DIR" >> "$cryptsetup_log" 2>&1
    chown -R ubuntu:ubuntu "${cryptsetup_src}"

    # Configure and compile
    echo "Configuring..." | tee -a "$cryptsetup_log"
    (cd "$cryptsetup_src" && ./configure \
        --enable-static-cryptsetup \
        --disable-shared \
        --disable-ssh-token \
        >> "$cryptsetup_log" 2>&1)
    code="$?"
    if [[ $code -gt "0" ]]; then
        ding
        echo -e "${Error}ERROR${Off} Failed to configure cryptsetup! See $cryptsetup_log"
        exit 1
    fi

    # Patch Makefile to allow dynamic libudev and end with -Bdynamic for gcc libs
    sed -i 's/cryptsetup_static_LDFLAGS = $(AM_LDFLAGS) -all-static/cryptsetup_static_LDFLAGS = $(AM_LDFLAGS) -Wl,-Bdynamic,-ludev,-Bstatic,-Bdynamic/' \
        "${cryptsetup_src}/Makefile"
    sed -i 's/-ldevmapper -lm -ludev/-ldevmapper -lm/' \
        "${cryptsetup_src}/Makefile"
    # Prevent make from regenerating Makefile from config.status
    touch "${cryptsetup_src}/config.status"
    touch "${cryptsetup_src}/Makefile"

    echo "Compiling..." | tee -a "$cryptsetup_log"
    (cd "$cryptsetup_src" && make cryptsetup.static >> "$cryptsetup_log" 2>&1)
    code="$?"
    if [[ $code -gt "0" ]] || [[ ! -x "${cryptsetup_src}/cryptsetup.static" ]]; then
        ding
        echo -e "${Error}ERROR${Off} Failed to compile cryptsetup! See $cryptsetup_log"
        exit 1
    fi

    echo -e "${Cyan}cryptsetup compiled successfully.${Off}"

    # Cleanup source files to save space
    rm -f "${HOME_DIR}/cryptsetup-2.4.3.tar.gz"
    mv "${cryptsetup_src}/cryptsetup.static" "${HOME_DIR}/cryptsetup-static"
    rm -rf "${cryptsetup_src}"

    chown ubuntu "${HOME_DIR}/cryptsetup-static"
    chown ubuntu "$cryptsetup_log"
fi

# Assemble all the drives removed from the Synology NAS
#if which mdadm >/dev/null; then
#if which "$MDADM_BINARY" >/dev/null; then
if [[ -x "$MDADM_BINARY" ]]; then
    echo -e "\n$("$MDADM_BINARY" --version 2>&1)"
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
    #mdadm -AsfR  # Ignore "no arrays found" because it could be a single drive
    "$MDADM_BINARY" -AsfR  # Ignore "no arrays found" because it could be a single drive
    vgchange -ay
#    fi

    # Get member drives and disable their standby timers
    mapfile -t member_drives < <("$MDADM_BINARY" --detail --scan 2>/dev/null | \
        awk '{print $2}' | \
        xargs -I{} "$MDADM_BINARY" --detail {} 2>/dev/null | \
        awk '/\/dev\/sd/ {print $NF}' | sort -u)

    if [[ ${#member_drives[@]} -gt 0 ]]; then
        echo -e "\nDisabling standby timers on source drives"
        for dev in "${member_drives[@]}"; do
            hdparm -S 0 "$dev" 2>/dev/null && echo "  $dev: standby disabled"
        done
    fi
else
    ding
    echo -e "${Error}ERROR${Off} mdadm not installed!"
    exit 1
fi


echo -e "\nlvs"                                   # debug
lvs | grep 'volume_'                              # debug
echo ""                                           # debug
echo -e "cat /proc/mdstat"                        # debug
#cat /proc/mdstat | grep '^md' | awk '{print $1}'  # debug
cat /proc/mdstat                                  # debug
echo ""                                           # debug


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
        #install_executable cryptsetup

        # Decode recovery key to file
        base64_decode_output_path="${recovery_key%.*}"
        base64 --decode "${recovery_key}" > "${base64_decode_output_path}"
        code="$?"
        if [[ $code -gt "0" ]]; then
            ding
            echo -e "Line ${LINENO}: ${Error}ERROR $code${Off} Decoding recovery key failed!"
            exit 1
        fi

        # Test recovery key
        # cryptsetup open --test-passphrase /dev/vgX/volume_Y -S 1 -d ${base64_decode_output_path}
        #cryptsetup open --test-passphrase "$device_path" -S 1 -d "${base64_decode_output_path}"
        "$CRYPTSETUP_BINARY" open --test-passphrase "$device_path" -S 1 -d "${base64_decode_output_path}"
        code="$?"
        if [[ $code -gt "0" ]]; then
            ding
            echo -e "Line ${LINENO}: ${Error}ERROR $code${Off} Testing recovery key failed!"
            exit 1
        fi

        # Decrypt the encrypted volume
        cryptvol="cryptvol_${device_path##*_}"
        #echo "cryptvol: $device_path"  # debug

        # Remove any existing /dev/mapper/cryptvol_${device_path##*_}
        if [[ -e "/dev/mapper/$cryptvol" ]]; then
            umount -f "/dev/mapper/$cryptvol"
            dmsetup remove -f "/dev/mapper/$cryptvol"
        fi

        # cryptsetup open --allow-discards /dev/vgX/volume_Y cryptvol_Y -S 1 -d ${base64_decode_output_path}
        #cryptsetup open --allow-discards "$device_path" "$cryptvol" -S 1 -d "${base64_decode_output_path}"
        "$CRYPTSETUP_BINARY" open --allow-discards "$device_path" "$cryptvol" -S 1 -d "${base64_decode_output_path}"
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


# Load patched btrfs module if available (fixes Synology custom root flags)
load_btrfs_module(){
    if [[ -f "$BTRFS_MODULE" ]]; then
        echo -e "\n${Cyan}Loading patched btrfs module...${Off}"
        # Load required dependencies
        modprobe raid6_pq 2>/dev/null
        modprobe xor 2>/dev/null
        modprobe zstd 2>/dev/null
        modprobe libcrc32c 2>/dev/null
        # Unload existing btrfs module if loaded
        rmmod btrfs 2>/dev/null
        # Load patched module
        if insmod "$BTRFS_MODULE"; then
            echo -e "${Cyan}Patched btrfs module loaded successfully.${Off}"
        else
            echo -e "${Error}ERROR${Off} Failed to load patched btrfs module!"
            echo "Continuing with default btrfs module..."
        fi
    fi
}
load_btrfs_module


# NEED TO MOUNT EACH DEVICE PATH IN ARRAY IF ALL SELECTED
# Mount the volume as read only
echo -e "\nMounting volume(s)"
mount "${device_path}" "${mount_path}/${mount_dir}" -o ro,users
code="$?"
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

