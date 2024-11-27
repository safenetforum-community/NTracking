#!/usr/bin/env bash

#sudo rm /etc/cron.d/node_balance

#NodePath=$(which safenode)
#LatestNodeVer=$($NodePath -V | awk '{print $3}')

#if [[ "$LatestNodeVer" != "0.110.0" ]]; then
#rm /var/safenode-manager/config
#fi

#sudo apt install linux-tools-generic -y
# cpupower -c all frequency-info | grep gov ; cpupower frequency-info
#sudo cpupower frequency-set --governor performance

#sudo swapoff -a

#sudo ufw disable
#echo "y" | sudo ufw reset
#sudo ufw default allow outgoing
#sudo ufw default deny incoming
#sudo ufw allow 4574/tcp comment 'SSH'
#echo "y" | sudo ufw enable

#sudo rm -rf /var/safenode-manager

#touch $HOME/runonallsystems

sudo rm -f /usr/bin/anms.sh* && sudo wget -P /usr/bin https://raw.githubusercontent.com/safenetforum-community/NTracking/main/anm/scripts/anms.sh && sudo chmod u+x /usr/bin/anms.sh
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



#sed -i "s/^\\(UpgradeHour=\\).*/\\UpgradeHour=16/" /var/safenode-manager/config
#sed -i "s/^\\(NodeCap=\\).*/\\NodeCap=100/" /var/safenode-manager/config

#sed -i "s/^\\(MaxLoadAverageAllowed=\\).*/\\MaxLoadAverageAllowed=12.0/" /var/safenode-manager/config
#sed -i "s/^\\(DesiredLoadAverage=\\).*/\\DesiredLoadAverage=9.4/" /var/safenode-manager/config


sed -i "s/^\\(MemLessThan=\\).*/\\MemLessThan=90/" /var/safenode-manager/config
sed -i "s/^\\(MemRemove=\\).*/\\MemRemove=96/" /var/safenode-manager/config


#rm -rf $HOME/.local/share/safe/
#rm -rf $HOME/.local/share/wallets

#safePath=$(which safe)
#sudo rm $safePath

#sed -i "s/^\\(MaxLoadAverageAllowed=\\).*/\\1$(echo "$(nproc) "*" 3.5" | bc)/" /var/safenode-manager/config

#sudo sed -i 's/PGRADEHOUR=18/UpgradeHour=19/g' /var/safenode-manager/config

#sudo apt update
#$HOME/.cargo/bin/rustup target install x86_64-unknown-linux-musl
#sudo apt install musl musl-dev musl-tools -y

sed -i "s/^\\(DelayStart=\\).*/\\DelayStart=5/" /var/safenode-manager/config
sed -i "s/^\\(DelayUpgrade=\\).*/\\DelayUpgrade=5/" /var/safenode-manager/config

#rm $HOME/.local/share/anm-wallet
