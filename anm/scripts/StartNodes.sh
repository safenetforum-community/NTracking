#!/usr/bin/env bash
 
Location="https://raw.githubusercontent.com/safenetforum-community/NTracking/main/"

ClientVersion="--version 0.3.8"
NodeVersion="--version 0.3.7"

NodeRestarVer1="0.3.7"
NodeRestarVer2="0.2.7"

#export PATH=$PATH:$HOME/.local/bin:$HOME/.cargo/bin/
export PATH=$PATH:$HOME/.local/bin:$HOME/.cargo/bin/:/usr/bin/

# disable swap
sudo swapoff -a
# set performance
sudo cpupower frequency-set --governor performance

# enable swap file
#sudo swapon /var/cache/swap/swapfile

# install antup
#curl -sSL https://raw.githubusercontent.com/maidsafe/antup/main/install.sh | bash
#curl -sSL https://raw.githubusercontent.com/maidsafe/antup/main/install.sh | sudo bash
#antup node

# update antnode

if [[ -f "$HOME/.local/share/anm-control.sh" ]]; then
    chmod u+x $HOME/.local/share/anm-control.sh
    . $HOME/.local/share/anm-control.sh
else
    antup client $ClientVersion
    antup node $NodeVersion
fi

# install / update script
sudo rm -f /usr/bin/anms.sh* && sudo wget -P /usr/bin "$Location"anm/scripts/anms.sh && sudo chmod u+x /usr/bin/anms.sh
echo "* * * * * $USER /bin/bash /usr/bin/anms.sh >> /var/antctl/log" | sudo tee /etc/cron.d/anm

# install NTracking
sudo rm -f /usr/bin/influx-resources.sh* && sudo wget -P /usr/bin "$Location"influx-resources.sh && sudo chmod u+x /usr/bin/influx-resources.sh
echo "*/20 * * * * $USER /usr/bin/mkdir -p /tmp/influx-resources && /bin/bash /usr/bin/influx-resources.sh > /tmp/influx-resources/influx-resources" | sudo tee /etc/cron.d/influx_resources

# create manager directory for nodes
sudo mkdir -p /var/antctl
sudo chown -R $USER:$USER /var/antctl
