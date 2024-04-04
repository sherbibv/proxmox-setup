# proxmox-setup

This file will detail the steps needes to setup Proxmox VE.
Also use the scripts provided by tteck at https://github.com/tteck/Proxmox shoutout to him!

## host

### Backups

Configuring Proxmox Backup Server to easily restore backed-up VMs and CTs

1. Navigate to ```Datacenter > Storage > Add > Proxmox Backup Server```
2. Use PBS login details (```root@pam```), Datastore name and coresponding Fingerprint``
3. Configure backup schedules in ```Datacenter > Backup > Add ```
4. For ```Storage``` select the newly created PBS storage ID
5. Configure schedule and what VMs and CTs to backup


### Powertop

Installing and configurind Powertop to optimize resource power consumption

1. To install powertop run ```sudo apt-get install -y powertop```
2. Create a new systemd service that will run powertop after every reboot ```nano /etc/systemd/system/powertop.service```

```
[Unit]
Description=Auto-tune power savings (oneshot)

[Service]
Type=oneshot
ExecStart=/usr/sbin/powertop --auto-tune
ExecStart=/bin/sh -c "echo 'on' > '/sys/bus/pci/devices/0000:00:16.0/power/control'"
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
```
In this config optimizations for PCIE device ```0000:00:16.0``` was turned off.
To enable service run the following commands in this order: 
1. ```systemctl daemon-reload```
2. ```systemctl enable powertop.service```


### ASPM optimizations

First identify what device dont have ASPM enabled by inslecting the output of:
```
lspci -vv | awk '/ASPM/{print $0}' RS= | grep --color -P '(^[a-z0-9:.]+|ASPM )'
```

For this scenario device ```00:01.0``` needs ASPM enabled. 
After identifying the device, create a script that will enable ASPM at startup. See ```aspm-script.sh``` script.

Create a new systemd service that will schedule the ASPM enabling after each reboot ```nano /etc/systemd/system/aspm-script.service```
```
[Unit]
Description=Enable ASPM

[Service]
ExecStart=/root/aspm-script.sh

[Install]
WantedBy=multi-user.target
```

**Optional:** To force ASPM edit file ```nano /etc/default/grub``` and add ```pcie_aspm=force``` to the ```GRUB_CMDLINE_LINUX_DEFAULT``` property (whitespace separated) (eg: ```GRUB_CMDLINE_LINUX_DEFAULT="quiet pcie_aspm=force"```)

**Note:** you can read [this Reddit post](https://www.reddit.com/r/debian/comments/8c6ytj/active_state_power_management_aspm/) for mode details about the process.

### Scrutiny Spoke

Install using the existing tutorial: [Scuritiny Spoke setup](https://github.com/AnalogJ/scrutiny/blob/master/docs/INSTALL_HUB_SPOKE.md).
Setup a scheduler that will push data to Scrutiny docker container

Create a new systemd timer that will schedule the Scritiny Spoke ```nano /etc/systemd/system/scrutiny.timer```
Add the following to the timer service:
```
[Unit]
Description=Scrutiny scheduler

[Timer]
OnUnitActiveSec=120m
OnBootSec=120m

[Install]
WantedBy=timers.target
```

Create a new systemd service for Scritiny Spoke ```nano /etc/systemd/system/scrutiny.service```
Add the following to the service:
```
[Unit]
Description=Scrutiny job

[Service]
Type=oneshot
ExecStart=/opt/scrutiny/bin/scrutiny-collector-metrics-linux-amd64 run --api-endpoint "http://SCRUTINY_HOST:SCRUTINY_PORT"
```

Replace ```SCRUTINY_HOST``` and ```SCRUTINY_PORT``` with the corect details for the existing Scrutiny instance.
To enable service run the following commands in this order: 
```
systemctl daemon-reload
systemctl enable scrutiny.service
systemctl enable scrutiny.timer
systemctl start scrutiny.timer
```

### Drive configuration

The drives were passed to the ```[VM-ID]``` using the following command:
```
/sbin/qm set [VM-ID] -virtioX /dev/disk/by-uuid/[UUID]
```
Where ```[UUID]``` is obtained by running the command:

```
ls -n /dev/disk/by-uuid/
```
This will list all available drives and their ```UUID``` value. This is preffered againced ID property. Remember to change the ```-virtioX``` flag to the coresponding number from 0 to 15.

## TvHeadend

Running inside a LXC based on debian 12. 
To install TVHeadend run the following:
```
apt update
apt upgrade -y
apt install curl -y
bash -c "$(wget -qLO - https://dl.cloudsmith.io/public/tvheadend/tvheadend/setup.deb.sh)"
apt update  
apt install tvheadend -y
```
While running the mux fetching, it will get stuck at ~30%. In order to fix this, you will need to run the command
```
px aux | grep tvheadend
```
Notice the pid and corresponding process command. Proceed with killing the process and starting is back up using the correct command (take notice of it in the command above).

In order to use the USB TV Tuner, a few changes need to be done to the .conf file located on the **host**.
Edit the file located at ```/etc/pve/lxc/ContainerID.conf``` where ```ContainerID``` is the ID of the TvHeadend LXC.

Add the following lines:
```
lxc.cgroup2.devices.allow: c 212:* rwm
lxc.mount.entry: /dev/dvb dev/dvb none bind,optional,create=dir
lxc.hook.pre-start: sh -c "/bin/chown 100000:100044 -R /dev/dvb"
```
For more details see [this Proxmox thread](https://forum.proxmox.com/threads/pass-usb-device-to-lxc.124205).

## Ubuntu Server

Ubuntu Server VM running all Docker containers.

### Drives configuration

The drives were mounted using fstab. MergerFS was used to merge the two 6Tb drives that were passed through and mounted inside the guest VM.

fstab snippet:

```
# 6Tb media drive
UUID=5dc2532a-80a6-483e-a679-f092caebe7b5 /mnt/hdd1 ext4 defaults 0 0

# 6Tb media drive
UUID=9e301c01-633a-4595-bdd8-6fc27a66404b /mnt/hdd2 ext4 defaults 0 0

# MergerFS media pool
/mnt/hdd1:/mnt/hdd2 /mnt/pool fuse.mergerfs category.create=mfs,cache.files=full,use_ino,nonempty,defaults,allow_other,nofail,minfreespace=20G,moveonenospc=true,fsname=mergerfsPool 0 0
```

## VS Server
Instalation done using scripts provided by tteck [here](https://tteck.github.io/Proxmox/). 

### Update 
To update version run the scripts provided under vs-server folder inside the container.

```
bash -c "$(wget -qLO - https://raw.githubusercontent.com/sherbibv/proxmox-setup/main/vs-server/update.sh)"
```

A reboot is required.

### PBS exclusion

To exclude dirs from PBS: [here](https://pbs.proxmox.com/docs/backup-client.html#excluding-files-directories-from-a-backup)
Create a file ```.pxarexclude``` near the dir you want to exclude. Add the paths that you want to exclude:
```
/models/*
/ollama/models/*
```

# Proxmox Backup Server setup

Aftre reinstall, proceed with running the post-install scripts provided by tteck [here](https://tteck.github.io/Proxmox/). 

### Install Powertop
Follow the steps presented [above](#Powertop) and adapt as needed. 

### Mount old backup datastore drive
Mount the previous backup datastore drive at the same location as before (eg: ```/mnt/datastore/s920-share```).
   
The mount can be done by editing ```/etc/fstab```, or by adding a new service inside ```/etc/systemd/system```.
If the initial ```Directory``` was created using the PBS GUI, the mount will be done using a service.

Create service ```'mnt-datastore-s920\x2dshare.mount'``` with the following contents:
```
[Install]
WantedBy=multi-user.target

[Mount]
Options=defaults
Type=ext4
What=/dev/disk/by-uuid/97b995db-ec8c-4eaa-84be-7d04c1bc3c53
Where=/mnt/datastore/s920-share

[Unit]
Description=Mount datatstore 's920-share' under '/mnt/datastore/s920-share'
```

Obs: the UUID othe drive can be found using ```ls -n /dev/disk/by-uuid/``` command

### Restore datastore config
Initialize the datastore from ```/etc/proxmox-backup/datastore.cfg```:
```
datastore: s920-share
        gc-schedule 09:00
        path /mnt/datastore/s920-share
```

Obs: The other files can also be backed-up and restored if needed. They contain configuration for GC, Verify jobs, Prunes etc.

# Router setup

TODO


