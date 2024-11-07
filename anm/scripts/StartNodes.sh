#!/usr/bin/env bash

Location="https://raw.githubusercontent.com/safenetforum-community/NTracking/main/"

ClientVersion="--version 0.1.4"
NodeVersion="--version 0.112.3"

#export PATH=$PATH:$HOME/.local/bin:$HOME/.cargo/bin/
export PATH=$PATH:$HOME/.local/bin:$HOME/.cargo/bin/:/usr/bin/

# disable swap
sudo swapoff -a

# enable swap file
#sudo swapon /var/cache/swap/swapfile

# install safeup
#curl -sSL https://raw.githubusercontent.com/maidsafe/safeup/main/install.sh | bash

# update safe

if [[ -f "$HOME/.local/share/anm-control" ]]; then
    . $HOME/.local/share/anm-control
    #safeup client $ClientVersion
    #safeup node $NodeVersion
else
    safeup client $ClientVersion
    safeup node $NodeVersion
fi

# install / update script
sudo rm -f /usr/bin/anms.sh* && sudo wget -P /usr/bin "$Location"anm/scripts/anms.sh && sudo chmod u+x /usr/bin/anms.sh
echo "* * * * * $USER /bin/bash /usr/bin/anms.sh >> /var/safenode-manager/log" | sudo tee /etc/cron.d/anm

# install NTracking
sudo rm -f /usr/bin/influx-resources.sh* && sudo wget -P /usr/bin "$Location"influx-resources.sh && sudo chmod u+x /usr/bin/influx-resources.sh
echo "*/10 * * * * $USER /usr/bin/mkdir -p /tmp/influx-resources && /bin/bash /usr/bin/influx-resources.sh > /tmp/influx-resources/influx-resources" | sudo tee /etc/cron.d/influx_resources

# create manager directory for nodes
sudo mkdir -p /var/safenode-manager
sudo chown -R $USER:$USER /var/safenode-manager
