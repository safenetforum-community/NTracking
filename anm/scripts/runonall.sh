#!/usr/bin/env bash

#sudo rm /etc/cron.d/node_balance

#NodePath=$(which safenode)
#LatestNodeVer=$($NodePath -V | awk '{print $3}')

#if [[ "$LatestNodeVer" != "0.110.0" ]]; then
#rm /var/safenode-manager/config
#fi

#sudo swapoff -a

#sudo ufw disable
#echo "y" | sudo ufw reset
#sudo ufw default allow outgoing
#sudo ufw default deny incoming
#sudo ufw allow 4574/tcp comment 'SSH'
#echo "y" | sudo ufw enable

#sudo rm -rf /var/safenode-manager

#touch $HOME/runonallsystems

#sudo rm -f /usr/bin/anms.sh* && sudo wget -P /usr/bin https://raw.githubusercontent.com/safenetforum-community/NTracking/main/anm/scripts/anms.sh && sudo chmod u+x /usr/bin/anms.sh
#sudo rm -f /usr/bin/influx-resources.sh* && sudo wget -P /usr/bin https://raw.githubusercontent.com/safenetforum-community/NTracking/main/influx-resources.sh && sudo chmod u+x /usr/bin/influx-resources.sh

#make swap file

#sudo mkdir -v /var/cache/swap
#sudo dd if=/dev/zero of=/var/cache/swap/swapfile bs=1K count=128M
#sudo chmod 600 /var/cache/swap/swapfile && sudo mkswap /var/cache/swap/swapfile && sudo swapon /var/cache/swap/swapfile

#remove 

#sudo swapoff -a
#sleep 5
#sudo rm /var/cache/swap/swapfile

#sudo rm -rf $HOME/.local/share/safe/node

#sudo rm -rf /home/safe/.local/share/safe


#sed -i "s/^\\(NodeCap=\\).*/\\NodeCap=70/" /var/safenode-manager/config
#sed -i "s/^\\(MaxLoadAverageAllowed=\\).*/\\MaxLoadAverageAllowed=24.0/" /var/safenode-manager/config
#sed -i "s/^\\(DesiredLoadAverage=\\).*/\\DesiredLoadAverage=18.0/" /var/safenode-manager/config


#sed -i "s/^\\(MemLessThan=\\).*/\\MemLessThan=75/" /var/safenode-manager/config
#sed -i "s/^\\(MemRemove=\\).*/\\MemRemove=95/" /var/safenode-manager/config


#rm -rf $HOME/.local/share/safe/




# setup NTRACKING

#######################################remove this block after all instances of telegraf in docker are removed
# stop Telegraf docker if running
docker compose --project-directory $HOME/.local/share/tig-stack/telegraf down
# remove telegraf contaner
docker remove telegraf
#remove old folders and config files if they exist 
sudo rm -rf $HOME/.local/share/tig-stack/telegraf
sudo rm -rf /tmp/influx-resources

# enter the ipaddress and port of the influx instalation
INFLUXDB_IP_PORT="safe-byres.ddns.net:8086"

# enter the token that will allow data to be writen to the influx DB
INFLUXDB_TOKEN="7RK9_qwZh9IPwOX_v6QunwMGTPEvUOA30IMEWKpBE6QC8YlgiK2iijjwTanUCiTV9TndylTtu3zSo7wDlI-bFQ=="

#setup cron job for resources
echo "*/15 * * * * $USER /usr/bin/mkdir -p /tmp/influx-resources && /bin/bash /usr/bin/influx-resources.sh > /tmp/influx-resources/influx-resources" | sudo tee /etc/cron.d/influx_resources

#set utc time zone
sudo timedatectl set-timezone UTC

#install jq
sudo apt-get install jq -y

#install bc
sudo apt-get install bc -y

################################################################### download script to gather node resources

#remove old script if exists
sudo rm /usr/bin/influx-resources.sh*

# download latest script from git hub
sudo wget -P /usr/bin  https://raw.githubusercontent.com/safenetforum-community/NTracking/main/influx-resources.sh

#make executable
sudo chmod u+x /usr/bin/influx-resources.sh

#####################################


# install telegraf and stop it for writing config file

curl -s https://repos.influxdata.com/influxdata-archive_compat.key > influxdata-archive_compat.key
echo '393e8779c89ac8d958f81f942f9ad7fb82a25e133faddaf92e15b16e6ac9ce4c influxdata-archive_compat.key' | sha256sum -c && cat influxdata-archive_compat.key | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/influxdata-archive_compat.gpg > /dev/null
echo 'deb [signed-by=/etc/apt/trusted.gpg.d/influxdata-archive_compat.gpg] https://repos.influxdata.com/debian stable main' | sudo tee /etc/apt/sources.list.d/influxdata.list
sudo apt-get update && sudo apt-get install telegraf

sleep 1
sudo systemctl stop telegraf.service
sleep 1

############################################################################################################################################# create telegraf config file
sudo tee /etc/telegraf/telegraf.conf 2>&1 > /dev/null <<EOF
# Configuration for telegraf agent
[agent]
  interval = "30s"
  round_interval = true
  metric_batch_size = 1000
  metric_buffer_limit = 10000
  collection_jitter = "0s"
  flush_interval = "10s"
  flush_jitter = "0s"
  precision = ""
  hostname = ""
  omit_hostname = false
  
[[outputs.influxdb_v2]]
  urls = ["http://$INFLUXDB_IP_PORT"]
  token = "$INFLUXDB_TOKEN"
  organization = "safe-org"
  bucket = "telegraf"

# cpu stats
[[inputs.cpu]]
  percpu = false
  totalcpu = true
  collect_cpu_time = false
  report_active = false

# Read metrics about memory usage
[[inputs.mem]]
  # no configuration

# Read metrics about swap memory usage
[[inputs.swap]]
  # no configuration

[[inputs.diskio]]
  devices = ["xvda3", "sd?", "md?", "nvme?", "nvme?n?"]

# Read metrics about system load & uptime
[[inputs.system]]
  # no configuration

# Read metrics about temperature
[[inputs.temp]]

# Get the number of processes and group them by status
[[inputs.processes]]
  # no configuration

# Read metrics about disk usage by mount point
[[inputs.disk]]
  ## By default stats will be gathered for all mount points.
  ## Set mount_points will restrict the stats to only the specified mount points.
  mount_points = ["/"]
  ## Ignore mount points by filesystem type.
  # ignore_fs = ["tmpfs", "devtmpfs", "devfs", "iso9660", "overlay", "aufs", "squashfs"]

[[inputs.net]]
  interfaces = ["enp*", "ens*", "eno*", "eth*", "ib*", "wl*"]

[[inputs.tail]]
  files = ["/tmp/influx-resources/influx-resources"]
  data_format = "influx"
EOF
################################################################################################################################################## End of Telegraf config
sudo systemctl unmask telegraf.service
sleep 1
sudo systemctl start telegraf.service