# Synology recover data

<a href="https://github.com/007revad/Synology_recover_data/releases"><img src="https://img.shields.io/github/release/007revad/Synology_recover_data.svg"></a>
<a href="https://hits.seeyoufarm.com"><img src="https://hits.seeyoufarm.com/api/count/incr/badge.svg?url=https%3A%2F%2Fgithub.com%2F007revad%2FSynology_recover_data&count_bg=%2379C83D&title_bg=%23555555&icon=&icon_color=%23E7E7E7&title=views&edge_flat=false"/></a>
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
- Ubuntu version 18.041

**Not applicable to:**
- Volumes using read-write SSD cache

**Currently the script does NOT support:**
- Encrypted volumes
- Encrypted shared folders

At the moment the script only support mounting 1 volume at a time. You'd need to run the script again to mount a 2nd volume.

### Screenshots

<p align="center">DSM 6 single volume</p>
<p align="center"><img src="/images/image-1.png"></p>

<br>

<p align="center">DSM 7 with storage pools and volumes</p>
<p align="center"><img src="/images/image-2.png"></p>
