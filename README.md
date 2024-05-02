# Synology Recover Data

<a href="https://github.com/007revad/Synology_Recover_Data/releases"><img src="https://img.shields.io/github/release/007revad/Synology_Recover_Data.svg"></a>
<a href="https://hits.seeyoufarm.com"><img src="https://hits.seeyoufarm.com/api/count/incr/badge.svg?url=https%3A%2F%2Fgithub.com%2F007revad%2FSynology_Recover_Data&count_bg=%2379C83D&title_bg=%23555555&icon=&icon_color=%23E7E7E7&title=views&edge_flat=false"/></a>
[![Donate](https://img.shields.io/badge/Donate-PayPal-green.svg)](https://www.paypal.com/paypalme/007revad)
[![](https://img.shields.io/static/v1?label=Sponsor&message=%E2%9D%A4&logo=GitHub&color=%23fe8e86)](https://github.com/sponsors/007revad)
[![committers.top badge](https://user-badge.committers.top/australia/007revad.svg)](https://user-badge.committers.top/australia/007revad)

### Description

A script to make it easy to recover your data from your Synology's drives using a computer.

Now supports encrypted volumes.


### Confirmed working on

<details>
  <summary>Click here to see list</summary>

| Drive source | DSM version    | Btrfs/Ext | Storage Pool type | RAID  | Encrypted | Notes           |
|--------------|----------------|-----------|-------------------|-------|-----------|-----------------|
| DS720+       | 7.2.1 Update 4 | Btrfs     | Multiple Volume   | SHR   | Volume    | Single drive    |
| DS720+       | 7.2.1 Update 4 | Btrfs     | Multiple Volume   | SHR   | no        | Single drive    |
| DS1812+      | 6.2.4 Update 7 | Btrfs     | Multiple Volume   | SHR   | no        | Single drive    |
| DS1812+      | 6.2.4 Update 7 | Btrfs     | Single Volume     | Basic | no        | **Failed, faulty HDD** |

</details>


### What does the script do?

The script automatically does steps 4 to 15 from this web page: <br>
https://kb.synology.com/en-id/DSM/tutorial/How_can_I_recover_data_from_my_DiskStation_using_a_PC

So you need to do steps 1 to 3 from that web page.

The same environment rules as on Synology's web page apply:

**Applicable to:**
- DSM version 6.2.x and above
- Volumes using the Btrfs or ext4 file systems
- Encrypted volumes using the Btrfs or ext4 file systems
- Ubuntu 19.10 only (Synology's recommended 18.04 has a bug with persistent partition)

**Not applicable to:**
- Volumes using read-write SSD cache

**Currently the script does NOT support:**
- Encrypted shared folders

At the moment the script only supports mounting 1 volume at a time. You'd need to run the script again to mount a 2nd volume.


### Setup to recover data using a PC

1. Make sure your PC has sufficient drive slots for drive installation (you can use a USB dock).
2. Remove the drives from your Synology NAS and install them in your PC or USB dock. For RAID or SHR configurations, you must install all the drives (excluding hot spare drives) in your PC at the same time.
3. Download the **Desktop image** for [Ubuntu version 19.10 Eoan Ermine](https://old-releases.ubuntu.com/releases/19.10/)
   - Synology's recommended 18.04 has a bug with persistent partition so any changes you make in Ubuntu will be lost when you shut down Ubuntu.
   - Newer Ubuntu versions like 20.04.6 LTS and 22.04.4 LTS require an 8GB USB drive and install an mdadm version that won't work with DSM's superblock location.
5. You'll need a 4GB or larger USB drive.
6. Prepare a Ubuntu environment by following the instructions in [this tutorial](https://ubuntu.com/tutorials/create-a-usb-stick-on-windows) with 1 exception:
    - Set Persistent partition size in [Rufus](https://rufus.ie/en/) to greater than 0 so any changes you make in Ubuntu are saved to the USB drive.
    <p align="left"> &nbsp; &nbsp;<img src="/images/rufus.png"></p>
7. If the drives contain an encrytped volume, or volumes:
    - Find your [NASNAME]_volume#.rkey for each encrypted volume. e.g. MYNAS_volume1.rkey, DISKSTATION_volume1.rkey or RACKSTATION_volume1.rkey etc.
    - Copy the *.rkey file or files to a USB drive or network share.
8. Once Rufus has finished creating the boot drive you can reboot the computer, [enter the BIOS](https://www.tomshardware.com/reviews/bios-keys-to-access-your-firmware,5732.html) and set it to boot from the USB drive, and boot into Ubuntu.
    - I highly recommend unplugging the SATA cables from the PC's drives, while the computer is turned off, so you don't accidentially install Ubuntu on them.
9. **IMPORTANT!** When Ubuntu asks if you want to want to "Try Ubuntu" or "Install Ubuntu" select "**Try Ubuntu**".

### Extra steps if the volume is encrypted

After booting into Ubuntu:
1. Plug in the USB drive containing the *.rkey file or files, or browse to the network share where your *.rkey file or files are located.
3. Copy the *.rkey file or files to Home.

### Setup in Ubuntu

1. Open Firefox from the tool bar and go to [https://github.com/007revad/Synology_Recover_Data](https://github.com/007revad/Synology_Recover_Data) or https://tinyurl.com/synorecover and download the latest release's zip file.
2. Open Files from the tool bar and click on Downloads, right-click on the zip file and select Extract.
3. Right-click on the syno_restore_data.sh file and select Properties.
    - Click Permissions.
    - Tick Allow executing file as program.
    <p align="left"> &nbsp; <img src="/images/script-permissions-2.png"></p>
4. Copy syno_recover_data.sh up 1 level to home.
    <p align="left"> &nbsp; <img src="/images/home.png"></p>
5. Click on the Show Applications icon on the bottom left of the desktop.
6. Type terminal in the search bar.
7. Right-click on Terminal and click on Save to favorites.
8. Press Esc twice to return to the desktop.


### Running the script

1. Open Terminal from the tool bar.
2. Type `sudo -i /home/ubuntu/syno_recover_data.sh` and press enter.
    <p align="left"> &nbsp; <img src="/images/run-script.png"></p>


### Accessing your data

There are 2 ways you can access you data:

- Accessing your volume from the Home folder
<p align="left"> &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; <img src="/images/volume_in_home-2.png"></p>

- Accessing your volume from Media on the tool bar
<p align="left"> &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; <img src="/images/volume_in_media-4.png"></p>

<br>


---
### Screenshots

<p align="left">DSM 7 with 2 storage pools and volumes</p>
<p align="left"> &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; <img src="/images/image-volume_2-2.png"></p>

<br>

<p align="left">DSM 7 SHR single volume</p>
<p align="left"> &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; <img src="/images/image-vg1000-2.png"></p>

<br>

<p align="left">DSM 6 Classic RAID single volume</p>
<p align="left"> &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; <img src="/images/image-md-2.png"></p>

<br>

<p align="left">DSM 7 Encrypted volume</p>
<p align="left"> &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; <img src="/images/image-encrypted-volume-2.png"></p>

