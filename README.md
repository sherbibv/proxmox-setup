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

Installing and configurind Powertop to optimize resource power consumption on Proxmox VE host.

1. To install powertop run ```apt-get install -y powertop```
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

The same steps need to be done inside ```OMV VM``` to that media drives report their SMART metrics to Scrutiny.

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

Obs: this is now longer required since the media drives get passedthrough via the ASMedia Technology Inc. ASM1166 Serial ATA Controller.

### ASMedia Technology Inc. ASM1166 Serial ATA Controller Passthrough

To passthrough the controller to ```OMV VM``` the following steps are required.

Edit the boot config (either grub or systemd-boot) and add ```intel_iommu=on iommu=pt``` if missing. In my case it was ```/etc/kernel/cmdline```.
Ass the following inside ```/etc/modules``` is missing:
```
vfio
vfio_iommu_type1
vfio_pci
```

To prevent the card from being used by the sistem add the following two lines inside a new blacklist file ```/etc/modprobe.d/vfio.conf```:
```
options vfio-pci ids=1b21:1166,2116:2116
softdep ahci pre: vfio-pci
```
Obs: replace ```1b21:1166``` with your controller id (can be extracted from the command ```lspci -nn```).
Note: If the file ```vfio.conf``` exists from iGPU/GPU configurations, add the ids separated by comas in the ids field and ```softdep ahci pre: vfio-pci``` on a new line eg:

```
options vfio-pci ids=10de:2504,10de:228e,1b21:1166,2116:2116
softdep ahci pre: vfio-pci
```
Here you can see I had my Nvidia GPU configured beforehand.

Run ```update-initramfs -u -k all``` and reboot.

After the reboot you can passthrough the controller to ```OMV VM``` by going to ```Hardware``` -> ```Add``` -> ```PCIE Device``` -> ```Raw device```, and select the SATA Controller from the list.

Reference: [1](https://forum.proxmox.com/threads/pcie-passthrough-of-asmedia-1166-sata-controller.137838/), [2](https://forum.proxmox.com/threads/prevent-a-sata-controller-to-be-loaded-by-ahci.136983/#post-608815), [3](https://forum.proxmox.com/threads/pci-gpu-passthrough-on-proxmox-ve-8-installation-and-configuration.130218/)

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

### Portainer update
To update Portainer run the command:

```
sudo bash -c "$(wget -qLO - https://raw.githubusercontent.com/sherbibv/proxmox-setup/main/portainer/update-portainer.sh)"
```

### MergerFS

To install MergerFS run the following commands:

```
wget $(curl -s https://api.github.com/repos/trapexit/mergerfs/releases/latest | jq -r ".assets[] | select(.name | test(\"jammy_amd64\")) | .browser_download_url")
dpkg -i mergerfs_*jammy_amd64.deb
rm mergerfs_*jammy_amd64.deb
```
Obs: using release type ```jammy_amd64```, change this as required.


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

### SMB drive configuration
The drives are mounted usinf fstab. For this scenario, SMB server is located ar ```10.69.0.16``` and exposes a share named ```mediaPool```

fstab snippet:

```
# SMB mergerfs media share
//10.69.0.16/mediaPool /mnt/cifs/media cifs vers=3.0,gid=1000,uid=1000,iocharset=utf8,credentials=/etc/smbcred 0 0
```

Notice that the share required a credential file. Before mounting the share, create the smbcred file with the following contents:

```
username=USER_GOES_HERE
password=PASS_GOES_HERE
```

Remember to set the permissions of the file ```chmod 600 /etc/smbcreds```

### Expanding root drive
In order to expand the size of the Ubuntu VM root drive use the following steps:

Locate the root partition by running ```lsblk``` (for me it was sda3). 
Run ```cfdisk``` and expand your root partition with the available free space (if present after VM disk resize from Proxmox VE GUI + VM reboot) by using the ```Resize``` option.

Resize partition using the command ```pvresize /dev/sda3```.

Next, we will need to get the Logical Volume (LV) path we want to alter using ```sudo lvdisplay```. Note the LV Path value, we will use this in the next command.

Run ```lvextend -l +100%FREE /dev/ubuntu-vg/ubuntu-lv``` that will extend the volume.

Lastly, run ```sudo resize2fs /dev/mapper/ubuntu--vg-ubuntu--lv``` to resize the volume to the desires size.


### iGPU passthrough
Firstly make sure the hardware supports passthrough and enable IOMMU.
On the Proxmox VE change the ```/etc/kernel/cmdline``` file to look like this:

```
root=ZFS=rpool/ROOT/pve-1 boot=zfs i915.enable_gvt=1 intel_iommu=on
```

Also load the following modules in ```/etc/modules```:
```
kvmgt
vfio_pci
vfio_virqfd
vfio
vfio_iommu_type1
vfio-mdev
i915
```

Before rebooting update initramfs:
```
update-initramfs -u -k all
```

After reboot check if IOMMU is enabled
```
dmesg | grep -e DMAR -e IOMMU
```
Look for something that says ```IOMMU enabled``` and ```Remapping enabled```.

Enable Unsafe Interrupts
```
echo "options vfio_iommu_type1 allow_unsafe_interrupts=1" > "/etc/modprobe.d/iommu.conf"
```
Check that device has separate IOMMU group:
```
lspci -nnk | grep Intel
```
Take note of the Display controller of VGA controller id.
Run the following command to verify that the iGPU is the only device in a group:
```
find /sys/kernel/iommu_groups/ -type l
```

After a reboot check the supported types of your iGPU device (for me the iGPU is 0000:00:02.0):
```
ls "/sys/bus/pci/devices/0000:00:02.0/mdev_supported_types"
```
In order to passthrough the iGPU to he VM, first stop it.
Create a new Resource Mapping (```Datacente```r -> ```Resource Mappings``` -> ```PCIE Device```), and tick the ```Use with Mediated Devices```. The iGPU should appear in the list.
After creating the resource mappings, go to the ```VM``` you want to passthrough the iGPU -> ```Hardware``` -> ```Add``` -> ```PCIE Device``` -> ```Mapped Devices```, and select the igpu resource mapping. Select MDev Type ```i915-GVTg_V5_4```. DO NOT tick ```Primary GPU```.

Start the VM and validate the iGPU is passedthrough correctly by running ```lspci -nnk``` and checkif the device is detected and using the i915 driver.

Optionally, to monitor Intel iGPU install ```intel-gpu-tools``` and ```vainfo``` and use the command ```sudo intel_gpu_top```.


### GPU passthrough

First check if the right kernel drivers for the GPU are being used on the Proxmox VE:
```
lspci -v
```
Check property ```kernel driver in use``` and if it's anything but ```vfio-pci``` continue with the tutorial.

Instruct the kernel to load the vfio kernel modules by adding ```vfio-pci``` to the ```/etc/modules-load.d/vfio-pci.conf``` file.
Now instruct the kernel to whick PCIE device to attach the vfio kernel modules.
To do this we first need to find the GPU devices IDs by using the command:
```
lspci -nn | grep -i nvidia
```
Obs: the IDs are specified at the end of each line. There should be two devices, one VGA compatible controller and one Audio device. Take note f both IDs.

Eg:
```
01:00.0 VGA compatible controller [0300]: NVIDIA Corporation GA106 [GeForce RTX 3060 Lite Hash Rate] [10de:2504] (rev a1)
01:00.1 Audio device [0403]: NVIDIA Corporation GA106 High Definition Audio Controller [10de:228e] (rev a1)
```

With the IDs in mind (for me it was 10de:1d81 and 10de:10f2) add the line below to ```/etc/modules-load.d/vfio.conf```:
```
options vfio-pci ids=10de:1d81,10de:10f2
```

Next enable IOMMU groups.
On the Proxmox VE change the ```/etc/kernel/cmdline``` file to look like this:

```
root=ZFS=rpool/ROOT/pve-1 boot=zfs **i915.enable_gvt=1 intel_iommu=on**
```
Basically, add ```intel_iommu=on``` to the line. For this to work you will need Intel VT-d and IOMMU to be enabled in BIOS.

Finally run ```update-initramfs -u -k all``` and reboot.

After reboot verify the GPU is in the correct kernel drivers by running ```lspci -v``` and checking the GPU ```kernel driver in use``` that should be ```vfio-pci```.
To check if the GPU is in the correct IOMMU group, run ```find /sys/kernel/iommu_groups/ -type l``` and check if the device IDs are in the same group as the iGPU.
```
/sys/kernel/iommu_groups/2/devices/0000:00:01.0
/sys/kernel/iommu_groups/2/devices/0000:01:00.0
/sys/kernel/iommu_groups/2/devices/0000:01:00.1
```
Host setup is done, now we need to passthrough the GPU to the VM.
Go to the ```VM``` you want to passthrough the iGPU -> ```Hardware``` -> ```Add``` -> ```PCIE Device``` -> ```Raw device```, and select the GPU from the list. Make sure to check ```All functions``` but keep ```Primary GPU``` unchecked.
Thats it, continue with instalation of Nvidia drivers on the VM.

First check to see if the GPU got passedthrough successfuly by running ```lspci -v``` and check the ```kernel driver in use``` property. If should be ```nvidia``` but since no Nvidia drivers were installed it's most probably ```nouveau```.
We need to blacklist this module by adding the following contents to ```/etc/modprobe.d/blacklist-nvidia-nouveau.conf```.
```
blacklist nouveau
options nouveau modset=0
```
Run ```update-initramfs -u``` afterwards and reboot.
Aftre the VM boots up install the Nvidia drivers by running the command and reboot after it's finished:
```
apt install nvidia-headless-550-server nvidia-utils-550-server libnvidia-encode-550-server libnvidia-decode-550-server
```
ATM version 550 is the latest version - check for updates.
After the VM boots up you wan use ```nvidia-smi ``` to see GPU stats.
Install nvidia-toolkit.
Obs: ```sudo nvidia-smi -pm ENABLED``` and ```nvidia-persistenced``` helped me lower GPU power draw.

To purge drivers use command ```sudo apt purge nvidia* libnvidia*```

## VS Server
Instalation done using scripts provided by tteck [here](https://tteck.github.io/Proxmox/). 

### Update 
Run the command below to update VS Server version.

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

### Cloud backup
In order to comply with the 3-2-1 back-up strategy, we should be able to upload out PBS backups to our cloud provider of choice. For this I am going to be using ```rclone``` with Backblaze.

First we install rclone and fuse3 using the commands:
```
apt install rclone fuse3
```

Configure rclone to connect to Backblaze B2. Here you will have to setup a connection name for your B2 instance (for me it was ```bz2-pbs-nitro```)
```
rclone config
```

After configuration, create a new bucket if you haven't done so already. (Obs: make sure to set the versioning inside Backblaze bucket settings to ot version uploads so that it will delete missing files from the source)
```
rclone mkdir UNIQUE_CONNECTION_NAME:UNIQUE_BUCKET_NAME
```
Replace ```UNIQUE_CONNECTION_NAME``` with your connection name (for me ```bz2-pbs-nitro```) and ```UNIQUE_BUCKET_NAME``` with the name of the bucket you want to create (in my instance it was ```pbs-nitro```).
Eg:
```
rclone mkdir bz2-pbs-nitro:pbs-nitro
```

In order to backup PBS data, you will need to sync the ```/mnt/datastore``` directory from your PBS machine.
To setup a job that will periodically sync your PBS backups to Backblaze B2 go to ```/etc/systemd/system``` and a new service and a timer.

```
nano rclone-sync.service
```

And add the following lines:

```
[Unit]
Description=Rclone Backup Sync Service
After=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/bin/rclone sync -vv --b2-hard-delete -P /mnt/datastore bz2-pbs-nitro:pbs-nitro
```
Obs: replace ```bz2-pbs-nitro:pbs-nitro``` with your details.

Create the timer file 
```
nano rclone-sync.timer
```

And add then lines:

```
[Unit]
Description=Run Rclone Backup Sync weekly on Sunday at 9 AM

[Timer]
OnCalendar=Sun 09:00
Persistent=true

[Install]
WantedBy=timers.target
```

I've set this up to run every Sunday at 9:00 AM. This can be customized as you see fit.

```
rclone sync -vv --b2-hard-delete -P --log-file=rclone.txt /mnt/datastore bz2-pbs-nitro:pbs-nitro
```

Finally, run the following commands to enable the timer.

```
systemctl daemon-reload
systemctl enable rclone-sync.timer
systemctl start rclone-sync.timer
```

If you checkout your Backblaze bucket you will see files starting to appear. You're all set.

# Router setup

TODO


