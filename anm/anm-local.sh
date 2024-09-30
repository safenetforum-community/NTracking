#!/usr/bin/env bash

ClientVersion="--version 0.95.0"
NodeVersion="--version 0.111.2"

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
    "2" "Change load level" OFF \
    "3" "Upgrade nodes" OFF \
    "4" "NTracking Upgrade" OFF \
    "5" "Start nodes" OFF \
    "6" "Stop nodes                          " OFF 3>&1 1>&2 2>&3)

if [[ $? -eq 255 ]]; then
    exit 0
fi

################################################################################################################ exit
if [[ "$SELECTION" == "1" ]]; then

    exit 0

################################################################################################################ change load levels
elif [[ "$SELECTION" == "2" ]]; then

    if [[ ! -f "/var/safenode-manager/config" ]]; then
        clear
        echo && echo "Start some nodes first" && echo
        exit 0
    fi

    LoadLevel=$(whiptail --title "System loading   " --radiolist \
        "How much to load the system                      " 20 70 10 \
        "1" "Low     -Default-                     " OFF \
        "2" "Medium  -Recomended-                  " ON \
        "3" "High    -Use Caution-                 " OFF \
        "4" "Extreme -Extra Caution-               " OFF 3>&1 1>&2 2>&3)
    if [[ $? -eq 255 ]]; then
        exit 0
    fi

    if [[ "$LoadLevel" == "1" ]]; then
        #Low
        #max load average
        sed -i "s/^\\(MaxLoadAverageAllowed=\\).*/\\1$(echo "$(nproc) * 2.5" | bc)/" /var/safenode-manager/config
        #desierd load average
        sed -i "s/^\\(DesiredLoadAverage=\\).*/\\1$(echo "$(nproc) * 1.5" | bc)/" /var/safenode-manager/config
        # set mem cpu hd
        sed -i "s/^\\(CpuLessThan=\\).*/\\CpuLessThan=80/" /var/safenode-manager/config
        sed -i "s/^\\(MemLessThan=\\).*/\\MemLessThan=80/" /var/safenode-manager/config
        sed -i "s/^\\(HDLessThan=\\).*/\\HDLessThan=80/" /var/safenode-manager/config

    elif [[ "$LoadLevel" == "2" ]]; then
        #Medium
        #max load average
        sed -i "s/^\\(MaxLoadAverageAllowed=\\).*/\\1$(echo "$(nproc) * 3.0" | bc)/" /var/safenode-manager/config
        #desierd load average
        sed -i "s/^\\(DesiredLoadAverage=\\).*/\\1$(echo "$(nproc) * 2.0" | bc)/" /var/safenode-manager/config
        # set mem cpu hd
        sed -i "s/^\\(CpuLessThan=\\).*/\\CpuLessThan=80/" /var/safenode-manager/config
        sed -i "s/^\\(MemLessThan=\\).*/\\MemLessThan=80/" /var/safenode-manager/config
        sed -i "s/^\\(HDLessThan=\\).*/\\HDLessThan=80/" /var/safenode-manager/config

    elif [[ "$LoadLevel" == "3" ]]; then
        #Medium
        #max load average
        sed -i "s/^\\(MaxLoadAverageAllowed=\\).*/\\1$(echo "$(nproc) * 3.5" | bc)/" /var/safenode-manager/config
        #desierd load average
        sed -i "s/^\\(DesiredLoadAverage=\\).*/\\1$(echo "$(nproc) * 2.5" | bc)/" /var/safenode-manager/config
        # set mem cpu hd
        sed -i "s/^\\(CpuLessThan=\\).*/\\CpuLessThan=90/" /var/safenode-manager/config
        sed -i "s/^\\(MemLessThan=\\).*/\\MemLessThan=90/" /var/safenode-manager/config
        sed -i "s/^\\(HDLessThan=\\).*/\\HDLessThan=90/" /var/safenode-manager/config

    else
        #Extream
        #max load average
        sed -i "s/^\\(MaxLoadAverageAllowed=\\).*/\\1$(echo "$(nproc) * 4.0" | bc)/" /var/safenode-manager/config
        #desierd load average
        sed -i "s/^\\(DesiredLoadAverage=\\).*/\\1$(echo "$(nproc) * 3.0" | bc)/" /var/safenode-manager/config
        # set mem cpu hd
        sed -i "s/^\\(CpuLessThan=\\).*/\\CpuLessThan=95/" /var/safenode-manager/config
        sed -i "s/^\\(MemLessThan=\\).*/\\MemLessThan=95/" /var/safenode-manager/config
        sed -i "s/^\\(HDLessThan=\\).*/\\HDLessThan=95/" /var/safenode-manager/config

    fi

######################################################################################################################## upgrade nodes
elif [[ "$SELECTION" == "3" ]]; then

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
elif [[ "$SELECTION" == "4" ]]; then

    sudo rm -f /usr/bin/influx-resources.sh* && sudo wget -P /usr/bin "$Location"influx-resources.sh && sudo chmod u+x /usr/bin/influx-resources.sh
    echo "*/10 * * * * $USER /usr/bin/mkdir -p /tmp/influx-resources && /bin/bash /usr/bin/influx-resources.sh > /tmp/influx-resources/influx-resources" | sudo tee /etc/cron.d/influx_resources

######################################################################################################################## Start nodes
elif [[ "$SELECTION" == "5" ]]; then

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
    Discord_Username=$(whiptail --title "Discord Username" --inputbox "\nEnter Discord Username" 8 40 "timbobjohnes" 3>&1 1>&2 2>&3)
    if [[ $? -eq 255 ]]; then
        exit 0
    fi
    if [ -z "${Discord_Username// /}" ]; then
        # Set no owner for nodes and keep the nanos
        sudo sed -i 's/--owner timbobjohnes//g' /usr/bin/anms.sh
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
        sudo sed -i 's/--owner timbobjohnes/--owner '$Discord_Username'/g' /usr/bin/anms.sh
    fi

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
elif [[ "$SELECTION" == "6" ]]; then

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
