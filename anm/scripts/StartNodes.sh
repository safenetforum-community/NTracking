#!/usr/bin/env bash
source ~/.config/safe/env

ClientVersion="--version 0.94.0"
NodeVersion="--version 0.110.0"

#disable swap
sudo swapoff -a

# update safe
safeup client $ClientVersion
safeup node  $NodeVersion

# install / update script
sudo rm -f /usr/bin/anms.sh* && sudo wget -P /usr/bin  https://github.com/safenetforum-community/NTracking/edit/main/anm/scripts/anms.sh && sudo chmod u+x /usr/bin/anms.sh
echo "* * * * * $USER /bin/bash /usr/bin/anms.sh >> /var/safenode-manager/log" | sudo tee /etc/cron.d/anm

# install NTracking
sudo rm -f /usr/bin/influx-resources.sh* && sudo wget -P /usr/bin  https://raw.githubusercontent.com/safenetforum-community/NTracking/main/influx-resources.sh && sudo chmod u+x /usr/bin/influx-resources.sh
echo "*/15 * * * * $USER /usr/bin/mkdir -p /tmp/influx-resources && /bin/bash /usr/bin/influx-resources.sh > /tmp/influx-resources/influx-resources" | sudo tee /etc/cron.d/influx_resources

# create manager directory for nodes
sudo mkdir -p /var/safenode-manager
sudo chown -R $USER:$USER /var/safenode-manager

