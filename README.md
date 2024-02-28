# proxmox-setup

This file will detail the steps needes to setup Proxmox VE.

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
