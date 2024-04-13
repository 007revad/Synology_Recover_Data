# Synology Recover Data

<a href="https://github.com/007revad/Synology_Recover_Data/releases"><img src="https://img.shields.io/github/release/007revad/Synology_Recover_Data.svg"></a>
<a href="https://hits.seeyoufarm.com"><img src="https://hits.seeyoufarm.com/api/count/incr/badge.svg?url=https%3A%2F%2Fgithub.com%2F007revad%2FSynology_Recover_Data&count_bg=%2379C83D&title_bg=%23555555&icon=&icon_color=%23E7E7E7&title=views&edge_flat=false"/></a>
[![](https://img.shields.io/static/v1?label=Sponsor&message=%E2%9D%A4&logo=GitHub&color=%23fe8e86)](https://github.com/sponsors/007revad)
[![committers.top badge](https://user-badge.committers.top/australia/007revad.svg)](https://user-badge.committers.top/australia/007revad)

### Description

A script to make it easy to recover your data from your Synology's drives using a computer

### This is still a work in progress...

If you are willing to test it, all feedback is welcome.

### What does the script do?

The script automatically does steps 4 to 15 from this web page: <br>
https://kb.synology.com/en-id/DSM/tutorial/How_can_I_recover_data_from_my_DiskStation_using_a_PC

So you need to do steps 1 to 3 from that web page.

The same environment rules as on Synology's web page apply:

**Applicable to:**
- DSM version 6.2.x and above
- Volumes using the Btrfs or ext4 file systems
- Ubuntu 22.04.4 LTS (Synology's recommended 18.04 has a bug with persistent partition)

**Not applicable to:**
- Volumes using read-write SSD cache

**Currently the script does NOT support:**
- Encrypted volumes
- Encrypted shared folders

At the moment the script only support mounting 1 volume at a time. You'd need to run the script again to mount a 2nd volume.

### Setup to recover data using a PC

1. Make sure your PC has sufficient drive slots for drive installation (you can use a USB dock).
2. Remove the drives from your Synology NAS and install them in your PC or USB dock. For RAID or SHR configurations, you must install all the drives (excluding hot spare drives) in your PC at the same time.
3. Download the Desktop image for [Ubuntu version 22.04.4 LTS](https://releases.ubuntu.com/jammy/)
4. You'll need an 8GB or larger USB drive.
5. Prepare a Ubuntu environment by following the instructions in [this tutorial](https://ubuntu.com/tutorials/create-a-usb-stick-on-windows) with 1 exception:
    - Set Persistent partition size in [Rufus](https://rufus.ie/en/) to greater than 0 so any changes you make in Ubuntu are saved to the USB drive.
    <p align="left"> &nbsp; &nbsp; &nbsp; &nbsp;<img src="/images/rufus.png"></p>
6. Once Rufus has finished creating the boot drive you can reboot the computer, enter the BIOS and set ti to boot from the USB drive, and boot into Ubuntu.

### Setup in Ubuntu

1. Open Firefox from the tool bar and go to [https://github.com/007revad/Synology_Recover_Data](https://github.com/007revad/Synology_Recover_Data/releases) and download the latest release's zip file.
2. Open Files from the tool bar and click on Downloads, right-click on the zip file and select Extract.
3. Right-click on the syno_restore_data.sh file and select Properties.
    - Click Permissions.
    - Tick Allow executing file as program.
    <p align="left"> &nbsp; &nbsp; &nbsp; <img src="/images/script-permissions-2.png"></p>
4. Copy syno_recover_data.sh up 1 level to home.
    <p align="left"> &nbsp; &nbsp; &nbsp; <img src="/images/home.png"></p>
5. Click on the Applications icon on the bottom left of the desktop.
6. Right-click on Terminal and click on Save to favorites.

### Running the script

1. Open Terminal from the tool bar.
2. Type `sudo -i /home/ubuntu/syno_recover_data.sh` and press enter.
    <p align="left"> &nbsp; &nbsp; &nbsp; <img src="/images/run-script.png"></p>

### Screenshots

<p align="center">DSM 7 with 2 storage pools and volumes</p>
<p align="center"><img src="/images/image-2.png"></p>

<br>

<p align="center">DSM 6 single volume</p>
<p align="center"><img src="/images/image-1.png"></p>

