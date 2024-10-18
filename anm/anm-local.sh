#!/usr/bin/env bash

ClientVersion="--version 0.95.3"
NodeVersion="--version 0.111.4"

#run with
# bash <(curl -s https://raw.githubusercontent.com/safenetforum-community/NTracking/main/anm/anm-local.sh)
# sudo rm -f /usr/bin/anms.sh* && sudo wget -P /usr/bin https://raw.githubusercontent.com/safenetforum-community/NTracking/main/anm/scripts/anms.sh && sudo chmod u+x /usr/bin/anms.sh
Location="https://raw.githubusercontent.com/safenetforum-community/NTracking/main/"

export PATH=$PATH:$HOME/.local/bin

export NEWT_COLORS='
window=,white
border=black,white
textbox=black,white
button=black,white
'

############################################## select test net action
SELECTION=$(whiptail --title "aatonnomicc node manager v 1.0" --radiolist \
    "                 ANM Local options                              " 20 70 10 \
    "1" "Exit" ON \
    "2" "View log" OFF \
    "3" "Change node Count" OFF \
    "4" "Upgrade nodes" OFF \
    "5" "NTracking Upgrade" OFF \
    "6" "Start nodes" OFF \
    "7" "Stop nodes                          " OFF 3>&1 1>&2 2>&3)

if [[ $? -eq 255 ]]; then
    exit 0
fi

################################################################################################################ exit
if [[ "$SELECTION" == "1" ]]; then

    exit 0

################################################################################################################ view log
elif [[ "$SELECTION" == "2" ]]; then

    if [[ ! -f "/var/safenode-manager/config" ]]; then
        clear
        echo && echo "Start some nodes first" && echo
        exit 0
    fi

    clear && tail -f /var/safenode-manager/log

################################################################################################################ change node count
elif [[ "$SELECTION" == "3" ]]; then

    if [[ ! -f "/var/safenode-manager/config" ]]; then
        clear
        echo && echo "Start some nodes first" && echo
        exit 0
    fi

    ### set nodecount
    NodeCount=$(whiptail --title "Set node count" --inputbox "\nEnter node count" 8 40 "20" 3>&1 1>&2 2>&3)
    if [[ $? -eq 255 ]]; then
        exit 0
    fi

    # Set new nodecount
    sed -i "s/^\\(NodeCap=\\).*/\\NodeCap=$NodeCount/" /var/safenode-manager/config

######################################################################################################################## upgrade nodes
elif [[ "$SELECTION" == "4" ]]; then

    if [[ ! -f "/var/safenode-manager/config" ]]; then
        clear
        echo && echo "Start some nodes first" && echo
        exit 0
    fi

    # update config
    sed -i "s/^\\(NodeVersion=\\).*/NodeVersion=\"$NodeVersion\"/" /var/safenode-manager/config
    # install safenode
    safeup node $NodeVersion
    safeup client $ClientVersion

######################################################################################################################## NTracking upgrade
elif [[ "$SELECTION" == "5" ]]; then

    sudo rm -f /usr/bin/influx-resources.sh* && sudo wget -P /usr/bin "$Location"influx-resources.sh && sudo chmod u+x /usr/bin/influx-resources.sh
    echo "*/10 * * * * $USER /usr/bin/mkdir -p /tmp/influx-resources && /bin/bash /usr/bin/influx-resources.sh > /tmp/influx-resources/influx-resources" | sudo tee /etc/cron.d/influx_resources

######################################################################################################################## Start nodes
elif [[ "$SELECTION" == "6" ]]; then

    #clear && echo && echo
    #echo "not updated for new release yet"
    #exit 0
    #echo && echo

    if [[ -f "/var/safenode-manager/config" ]]; then
        clear
        echo && echo "nodes running stop nodes first" && echo
        exit 0
    fi

    #disable swap
    sudo swapoff -a

    #update node and client
    safeup client $ClientVersion
    safeup node $NodeVersion

    # install / update anm script
    sudo rm -f /usr/bin/anms.sh* && sudo wget -P /usr/bin "$Location"anm/scripts/anms.sh && sudo chmod u+x /usr/bin/anms.sh

    # update NTracking
    sudo rm -f /usr/bin/influx-resources.sh* && sudo wget -P /usr/bin "$Location"influx-resources.sh && sudo chmod u+x /usr/bin/influx-resources.sh
    echo "*/10 * * * * $USER /usr/bin/mkdir -p /tmp/influx-resources && /bin/bash /usr/bin/influx-resources.sh > /tmp/influx-resources/influx-resources" | sudo tee /etc/cron.d/influx_resources

    # user options

    ### discord username
    Discord_Username=$(whiptail --title "Discord Username" --inputbox "\nEnter Discord Username" 8 40 "DiscordUserName" 3>&1 1>&2 2>&3)
    if [[ $? -eq 255 ]]; then
        exit 0
    fi
    if [ -z "${Discord_Username// /}" ]; then
        # Set no owner for nodes and keep the nanos
        sudo sed -i 's/--owner DiscordUserName//g' /usr/bin/anms.sh
        sudo rm -f /usr/bin/scrape.sh* && sudo wget -P /usr/bin "$Location"anm/scripts/scrape.sh && sudo chmod u+x /usr/bin/scrape.sh
        echo "5 * * * * $USER /bin/bash /usr/bin/scrape.sh > /var/safenode-manager/scrape.log" | sudo tee /etc/cron.d/scrape
        clear
        echo "autoscraping to client wallet is now enabled"
        echo "scraping starts at 5 min past the hour"
        echo "to view progress of scraping tail -f /var/safenode-manager/scrape.log"
        echo "sleep 10 please wait "
        echo
        sleep 10
    else
        # Set new owner for nodes
        sudo sed -i 's/--owner DiscordUserName/--owner '$Discord_Username'/g' /usr/bin/anms.sh
    fi

    ### set rewards address
    RewardsAddress=$(whiptail --title "ETH Rewards Adress" --inputbox "\nEnter ETH Rewards Adress" 8 40 "0x5c69a31F0c03ffc64aC203F6B67Cf9cC7ca93A93" 3>&1 1>&2 2>&3)
    if [[ $? -eq 255 ]]; then
        exit 0
    fi
    # Set new rewards address
    sudo sed -i 's/--rewards-address 0x5c69a31F0c03ffc64aC203F6B67Cf9cC7ca93A93/--rewards-address '$RewardsAddress'/g' /usr/bin/anms.sh

    ### set nodecount
    NodeCount=$(whiptail --title "Set node count" --inputbox "\nEnter node count" 8 40 "20" 3>&1 1>&2 2>&3)
    if [[ $? -eq 255 ]]; then
        exit 0
    fi
    # Set new nodecount
    sudo sed -i 's/NodeCap=20/NodeCap='$NodeCount'/g' /usr/bin/anms.sh

    ### set start interval
    NodeStart=$(whiptail --title "Node start interval" --inputbox "\nNode start interval" 8 40 "5" 3>&1 1>&2 2>&3)
    if [[ $? -eq 255 ]]; then
        exit 0
    fi
    # Set start interval
    sudo sed -i 's/DelayStart=5/DelayStart='$NodeStart'/g' /usr/bin/anms.sh

    ### set node upgrade interval
    NodeUpgrade=$(whiptail --title "Node upgrade interval" --inputbox "\nNode upgrade interval" 8 40 "5" 3>&1 1>&2 2>&3)
    if [[ $? -eq 255 ]]; then
        exit 0
    fi
    # Set new set upgrade interval
    sudo sed -i 's/DelayUpgrade=5/DelayUpgrade='$NodeUpgrade'/g' /usr/bin/anms.sh

    ### logging
    #Logging=$(whiptail --title "Logging" --inputbox "\nLogging yes or no" 8 40 "yes" 3>&1 1>&2 2>&3)
    #if [[ $? -eq 255 ]]; then
    #    exit 0
    #fi
    #if [[ "$Logging" != "no" ]]; then
    #    # yes set for logging
    #    sudo sed -i 's/$node_number $DiscordUsername/$node_number $DiscordUsername --log-output-dest \/var\/log\/safenode\/safenode$NextNodeToSorA --max_log_files 5 --max_archived_log_files 5/g' /usr/bin/anms.sh
    #else
    #    # continue with no loging
    #    sleep 1
    #fi

    ### portrange
    PortRange=$(whiptail --title "Node portrange start" --inputbox "\nnode range in thousands" 8 40 "55" 3>&1 1>&2 2>&3)
    if [[ $? -eq 255 ]]; then
        exit 0
    fi

    if [[ "$PortRange" == "13" ]]; then
        # change port range
        clear && echo "port range 13 thousand not allowed NTracking metrics ports" && exit 0
    elif [[ "$PortRange" != "55" ]]; then
        # change port range
        sudo sed -i 's/ntpr=55/ntpr='$PortRange'/g' /usr/bin/anms.sh
    fi

    ### node cap
    #nodecapnum=$(whiptail --title "Node cap" --inputbox "\nMax nodes to start" 8 40 "500" 3>&1 1>&2 2>&3)
    #if [[ $? -eq 255 ]]; then
    #    exit 0
    #fi
    #if [[ "$Logging" != "500" ]]; then
    #    # set new node cap
    #    sudo sed -i 's/NodeCap=500/NodeCap='$nodecapnum'/g' /usr/bin/anms.sh
    #else
    #    # continue with default node cap
    #    sleep 1
    #fi

    # create manager directory for nodes
    sudo mkdir -p /var/safenode-manager
    # change owner and allow start
    sudo chown -R $USER:$USER /var/safenode-manager
    touch /var/safenode-manager/log

    # enable anms script cron job
    echo "* * * * * $USER /bin/bash /usr/bin/anms.sh >> /var/safenode-manager/log" | sudo tee /etc/cron.d/anm

    clear
    echo
    echo "about to view log file to exit log file press ctl c"
    echo "after exiting log file nodes will continue to run on exit"
    sleep 10
    tail -f /var/safenode-manager/log

######################################################################################################################## Stop nodes
elif [[ "$SELECTION" == "7" ]]; then

    rm /var/safenode-manager/config
    clear

    while [[ -f "/var/safenode-manager/NodeDetails" ]]; do
        echo "Please wait"
        sleep 10
    done
    clear
    echo "nodes stopped"
    echo

fi
