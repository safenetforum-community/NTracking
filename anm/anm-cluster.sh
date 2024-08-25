#!/usr/bin/env bash

ClientVersion="--version 0.94.0"
NodeVersion="--version 0.110.0"

export PATH=$PATH:$HOME/.local/bin

#run with
# bash <(curl -s https://raw.githubusercontent.com/safenetforum-community/NTracking/main/anm/anm-cluster.sh)
Location="https://raw.githubusercontent.com/safenetforum-community/NTracking/main/"

export NEWT_COLORS='
window=,white
border=black,white
textbox=black,white
button=black,white
'

machines="m00 m01 m02 m03 m04 m05"

############################################## select test net action
SELECTION=$(whiptail --title "aatonnomicc cluster node manager" --radiolist \
    "                 ANM Cluster options                              " 20 70 10 \
    "1" "Exit" ON \
    "2" "Change load levels" OFF \
    "3" "Upgrade nodes" OFF \
    "4" "NTracking upgrade" OFF \
    "5" "Start all nodes" OFF \
    "6" "Stop all nodes" OFF \
    "7" "Run on systems                 " OFF 3>&1 1>&2 2>&3)

if [[ $? -eq 255 ]]; then
    exit 0
fi

# load custom machine names and function
. $HOME/.local/share/anm-cluster

################################################################################################################ exit
if [[ "$SELECTION" == "1" ]]; then

    exit 0

######################################################################################################################## Change load levels
elif [[ "$SELECTION" == "2" ]]; then

    LoadLevel=$(whiptail --title "System loading   " --radiolist \
        "How much to load the system                      " 20 70 10 \
        "1" "Low     -Recomended-       " OFF \
        "2" "Medium  -Default-          " ON \
        "3" "High                       " OFF \
        "4" "Extreme -Use Caution       " OFF 3>&1 1>&2 2>&3)
    if [[ $? -eq 255 ]]; then
        exit 0
    fi

    if [[ "$LoadLevel" == "1" ]]; then
        #Low
        #max load average
        override='sleep 120 && sed -i "s/^\\(DesiredLoadAverage=\\).*/\\1$(echo "$(nproc) "*" 1.5" | bc)/" /var/safenode-manager/config && sed -i "s/^\\(MaxLoadAverageAllowed=\\).*/\\1$(echo "$(nproc) "*" 2.5" | bc)/" /var/safenode-manager/config'
    elif [[ "$LoadLevel" == "2" ]]; then
        #Medium
        override='sleep 120 && sed -i "s/^\\(DesiredLoadAverage=\\).*/\\1$(echo "$(nproc) "*" 2.0" | bc)/" /var/safenode-manager/config && sed -i "s/^\\(MaxLoadAverageAllowed=\\).*/\\1$(echo "$(nproc) "*" 3.0" | bc)/" /var/safenode-manager/config'
    elif [[ "$LoadLevel" == "3" ]]; then
        #high
        override='sleep 120 && sed -i "s/^\\(DesiredLoadAverage=\\).*/\\1$(echo "$(nproc) "*" 2.5" | bc)/" /var/safenode-manager/config && sed -i "s/^\\(MaxLoadAverageAllowed=\\).*/\\1$(echo "$(nproc) "*" 3.5" | bc)/" /var/safenode-manager/config'
    else
        #Extream
        override='sleep 120 && sed -i "s/^\\(DesiredLoadAverage=\\).*/\\1$(echo "$(nproc) "*" 3.0" | bc)/" /var/safenode-manager/config && sed -i "s/^\\(MaxLoadAverageAllowed=\\).*/\\1$(echo "$(nproc) "*" 4.0" | bc)/" /var/safenode-manager/config'
    fi

    for machine in $machines; do
        # will only afect systems thats name begins with "h" !!
        if [[ "$machine" == "h"* ]]; then
            ssh -t $machine ''$override'' >/dev/null 2>&1 &
            disown
            sleep 2
            echo
            echo "$machine Change Load request sent"
        fi

    done &
    disown

######################################################################################################################## upgrade nodes
elif [[ "$SELECTION" == "3" ]]; then

    for machine in $machines; do
        ssh -t $machine 'sed -i "s/^\\(NodeVersion=\\).*/NodeVersion=\"'$NodeVersion'\"/" /var/safenode-manager/config && safeup node '$NodeVersion'' >/dev/null 2>&1 &
        disown
        echo "$machine Upgrade nodes request sent"
        sleep 2
    done &
    disown

######################################################################################################################## update NTracking
elif [[ "$SELECTION" == "4" ]]; then

    for machine in $machines; do
        ssh -t $machine 'sudo rm -f /usr/bin/influx-resources.sh"*" && sudo wget -P /usr/bin  "$Location"influx-resources.sh && sudo chmod u+x /usr/bin/influx-resources.sh && echo ""*"/15 "*" "*" "*" "*" $USER /usr/bin/mkdir -p /tmp/influx-resources && /bin/bash /usr/bin/influx-resources.sh > /tmp/influx-resources/influx-resources" | sudo tee /etc/cron.d/influx_resources' >/dev/null 2>&1 &
        disown
        echo "$machine Upgrade influx request sent"
        sleep 2
    done &
    disown

######################################################################################################################## Start nodes
elif [[ "$SELECTION" == "5" ]]; then

    for machine in $machines; do
        override=""
        CustomSetings

        ssh -t $machine 'bash <(curl -s "$Location"anm/scripts/StartNodes.sh) '$override'' >/dev/null 2>&1 &
        disown
        sleep 2
        echo
        echo "$machine Start nodes request sent"
    done &
    disown

######################################################################################################################## Stop nodes
elif [[ "$SELECTION" == "6" ]]; then

    for machine in $machines; do
        ssh -t $machine 'bash <(curl -s "$Location"anm/scripts/anm_Stop.sh)' >/dev/null 2>&1 &
        disown
        echo "$machine Stop nodes request sent"
        sleep 0
    done &
    disown

######################################################################################################################## Run on all systems
elif [[ "$SELECTION" == "7" ]]; then

    for machine in $machines; do
        ssh -t $machine 'bash <(curl -s "$Location"anm/scripts/runonall.sh)' >/dev/null 2>&1 &
        disown
        echo "$machine Run on all machines request sent"
        sleep 2
    done &
    disown

fi