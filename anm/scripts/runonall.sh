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

#make swap file

#sudo mkdir -v /var/cache/swap
#cd /var/cache/swap
#sudo dd if=/dev/zero of=swapfile bs=1K count=68M
#sudo chmod 600 swapfile
#sudo mkswap swapfile
#sudo swapon swapfile

#remove 

#sudo swapoff -a
#sleep 5
#sudo rm /var/cache/swap/swapfile

sudo rm -rf $HOME/.local/share/safe/node

