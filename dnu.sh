#!/usr/bin/env bash

CLIENT=0.92.0
NODE=0.106.5
FAUCET=161.35.173.105:8000
NODE_MANAGER=0.8.0
# get from https://sn-testnet.s3.eu-west-2.amazonaws.com/network-contacts

#run with
# bash <(curl -s https://raw.githubusercontent.com/safenetforum-community/NTracking/main/dnu.sh)

# first node port can edited in menu later
NODE_PORT_FIRST=12001
NUMBER_NODES=40
NUMBER_COINS=1
DELAY_BETWEEN_NODES=151000

export NEWT_COLORS='
window=,white
border=black,white
textbox=black,white
button=black,white
'

############################################## select test net action

SELECTION=$(whiptail --title "Autonomi Network Beta 1.13 " --radiolist \
"Testnet Actions                              " 20 70 10 \
"1" "Install & Start Nodes " OFF \
"2" "Upgrade Client to Latest" OFF \
"3" "Stop Nodes update upgrade & restart system!!  " OFF \
"4" "Get Test Coins" ON \
"5" "Upgrade Nodes" OFF \
"6" "Start Vdash" OFF \
"7" "Spare                        " OFF \
"8" "Spare   " OFF 3>&1 1>&2 2>&3)

if [[ $? -eq 255 ]]; then
exit 0
fi

################################################################################################################ start or Upgrade Client & Node to Latest
if [[ "$SELECTION" == "1" ]]; then

Discord_Username=$(whiptail --title "Discord Username" --inputbox "\nEnter Discord Username" 8 40 "timbobjohnes" 3>&1 1>&2 2>&3)
if [[ $? -eq 255 ]]; then
exit 0
fi
if [ -z "${Discord_Username// /}" ]; then
    sleep 0
else
   Discord_Username="--owner $Discord_Username";
fi

NODE_TYPE=$(whiptail --title "Safe Network Testnet   " --radiolist \
"Type of Nodes to start                              " 20 70 10 \
"1" "Node from home no port forwarding    " OFF \
"2" "Cloud based nodes with port forwarding   " ON 3>&1 1>&2 2>&3)

if [[ $? -eq 255 ]]; then
exit 0
fi

#remove influx resources
sudo rm -f /usr/bin/influx-resources.sh
sudo rm -f /etc/cron.d/influx_resources

#install latest load balancing script
sudo rm -f /usr/bin/node-balance.sh
sudo rm -f /etc/cron.d/node_balance

##############################  close fire wall
yes y | sudo ufw delete $(sudo ufw status numbered |(grep 'safe nodes'|awk -F"[][]" '{print $2}')) && yes y | sudo ufw delete $(sudo ufw status numbered |(grep 'safe nodes'|awk -F"[][]" '{print $2}'))

NUMBER_NODES=$(whiptail --title "Number of Nodes to start" --inputbox "\nEnter number of nodes" 8 40 $NUMBER_NODES 3>&1 1>&2 2>&3)
if [[ $? -eq 255 ]]; then
exit 0
fi


if [[ "$NODE_TYPE" == "2" ]]; then

NODE_PORT_FIRST=$(whiptail --title "Port Number of first Node" --inputbox "\nEnter Port Number of first Node" 8 40 $NODE_PORT_FIRST 3>&1 1>&2 2>&3)
if [[ $? -eq 255 ]]; then
exit 0
fi
############################## open ports
sudo ufw allow $NODE_PORT_FIRST:$(($NODE_PORT_FIRST+$NUMBER_NODES-1))/udp comment 'safe nodes'
sleep 2

fi

############################## Stop Nodes and delete safe folder

yes y | sudo env "PATH=$PATH" safenode-manager reset

# sudo snap remove curl
# sudo apt install curl

# disable installing safe up for every run
#curl -sSL https://raw.githubusercontent.com/maidsafe/safeup/main/install.sh | bash
#source ~/.config/safe/env

rm -rf $HOME/.local/share/safe
rm $HOME/.local/bin/safe
rm /usr/bin/safe

safeup node-manager
safeup client
#--version "$CLIENT"


cargo install vdash

############################## start nodes

mkdir -p /tmp/influx-resources

if [[ "$NODE_TYPE" == "2" ]]; then
# for cloud instances
sudo env "PATH=$PATH" safenode-manager add --node-port "$NODE_PORT_FIRST"-$(($NODE_PORT_FIRST+$NUMBER_NODES-1))  --count "$NUMBER_NODES" $Discord_Username --enable-metrics-server --metrics-port $(($NODE_PORT_FIRST+1000))-$(($NODE_PORT_FIRST+$NUMBER_NODES-1+1000))
else
# for home nodes hole punching
sudo env "PATH=$PATH" safenode-manager add --home-network --count "$NUMBER_NODES" $Discord_Username
#--peer "/ip4/104.152.208.126/udp/12040/quic-v1/p2p/12D3KooWNUYCcX3iJaJX5i7RZMKK1rLAFrKCNnWyrFjCdPLd5pcd"
fi

# --version "$NODE"

sudo env "PATH=$PATH" safenode-manager start --interval $DELAY_BETWEEN_NODES | tee /tmp/influx-resources/nodemanager_output & disown

##sudo env "PATH=$PATH" safenode-manager add --node-port "$NODE_PORT_FIRST"-$(($NODE_PORT_FIRST+$NUMBER_NODES-1))  --count "$NUMBER_NODES"  --peer "$PEER"  --url http://safe-logs.ddns.net/safenode.tar.gz


######################################################################################################################## Upgrade Client to Latest
elif [[ "$SELECTION" == "2" ]]; then
############################## Stop client and delete safe folder

rm -rf $HOME/.local/share/safe/client

safeup client

safe wallet get-faucet "$FAUCET"

######################################################################################################################## Stop Nodes
elif [[ "$SELECTION" == "3" ]]; then

sudo pkill -e safe

# stop nodes
# nuke safe node manager services 1 - 500 untill nuke comand exists

for i in {1..500}
do
 # your-unix-command-here
 sudo systemctl disable --now safenode$i
done

sudo rm /etc/systemd/system/safenode*
sudo systemctl daemon-reload

sudo rm -rf /var/safenode-manager
sudo rm -rf /var/log/safenode

rm -rf $HOME/.local/share/safe/node
sudo rm -rf $HOME/node-*

sleep 2

############################## close fire wall

yes y | sudo ufw delete $(sudo ufw status numbered |(grep 'safe nodes'|awk -F"[][]" '{print $2}')) && yes y | sudo ufw delete $(sudo ufw status numbered |(grep 'safe nodes'|awk -F"[][]" '{print $2}'))
yes y | sudo ufw delete $(sudo ufw status numbered |(grep 'safe nodes'|awk -F"[][]" '{print $2}')) && yes y | sudo ufw delete $(sudo ufw status numbered |(grep 'safe nodes'|awk -F"[][]" '{print $2}'))
yes y | sudo ufw delete $(sudo ufw status numbered |(grep 'safe nodes'|awk -F"[][]" '{print $2}')) && yes y | sudo ufw delete $(sudo ufw status numbered |(grep 'safe nodes'|awk -F"[][]" '{print $2}'))

rm /tmp/influx-resources/nodemanager_output.lock

rustup update
sudo apt update -y && sudo apt upgrade -y
sudo reboot


######################################################################################################################## Get Test Coins
elif [[ "$SELECTION" == "4" ]]; then
NUMBER_COINS=$(whiptail --title "Number of Coins" --inputbox "\nEnter number of Coins" 8 40 $NUMBER_COINS 3>&1 1>&2 2>&3)
if [[ $? -eq 255 ]]; then
exit 0
fi

for (( c=1; c<=$NUMBER_COINS; c++ ))
do
   safe wallet get-faucet "$FAUCET"
   sleep 1
done

######################################################################################################################### Upgrade Nodes
elif [[ "$SELECTION" == "5" ]]; then

sudo env "PATH=$PATH" safenode-manager upgrade --interval 11000  | tee -a /tmp/influx-resources/node_upgrade_report

######################################################################################################################### Start Vdash
elif [[ "$SELECTION" == "6" ]]; then

# Function to generate log paths
generate_log_paths() {
    local start=$1
    local end=$2
    local log_paths=""
    for i in $(seq $start $end); do
        log_paths="$log_paths $HOME/node-logs/safenode$i/safenode.log"
    done
    echo $log_paths
}

# Prompt the user for input
echo "Enter a single number or a range (e.g., 1-5):"
read input

# Determine if the input is a range or a single number
if [[ $input =~ ^[0-9]+-[0-9]+$ ]]; then
    # Input is a range
    start=$(echo $input | cut -d'-' -f1)
    end=$(echo $input | cut -d'-' -f2)
elif [[ $input =~ ^[0-9]+$ ]]; then
    # Input is a single number
    start=$input
    end=$input
else
    echo "Invalid input. Please enter a single number or a range (e.g., 1-5)."
    exit 1
fi

# Generate log paths
log_paths=$(generate_log_paths $start $end)

# Execute vdash command
vdash $log_paths

######################################################################################################################### spare
elif [[ "$SELECTION" == "7" ]]; then

echo "spare 7"

######################################################################################################################### spare
elif [[ "$SELECTION" == "8" ]]; then

echo "spare 8"

fi
