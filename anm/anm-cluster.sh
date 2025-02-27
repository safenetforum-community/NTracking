#!/usr/bin/env bash

ClientVersion="--version 0.3.8"
NodeVersion="--version 0.3.7"

NodeRestarVer1="0.3.7"
NodeRestarVer2="0.2.7"

export PATH=$PATH:$HOME/.local/bin

#run with
# bash <(curl -s https://raw.githubusercontent.com/safenetforum-community/NTracking/main/anm/anm-cluster.sh)
Location="https://raw.githubusercontent.com/safenetforum-community/NTracking/main/"

export NEWT_COLORS='
root=white,red
window=white,gray
border=lightgray,gray
shadow=white,black
button=black,green
actbutton=black,red
compactbutton=lightgray,black
title=yellow,gray
roottext=red,black
textbox=lightgray,gray
acttextbox=gray,white
entry=black,lightgray
disentry=gray,black
checkbox=black,lightgray
actcheckbox=black,green
emptyscale=,lightgray
fullscale=,brown
listbox=black,lightgray
actlistbox=lightgray,black
actsellistbox=black,green
'

# machines to run on vis ssh shortcut in ~/.ssh/config
machines="m00 m01 m02 m03 m04 m05"

# load custom machine names and function
. $HOME/.local/share/anm-cluster

############################################## select test net action
SELECTION=$(whiptail --title "aatonnomicc cluster controler v 2.0 " --radiolist \
    "                 ANM Cluster options                              " 20 70 10 \
    "1" "Exit                                          " ON \
    "2" "Change node count                             " OFF \
    "3" "Upgrade nodes antup                           " OFF \
    "4" "NTracking upgrade                             " OFF \
    "5" "Start nodes                                   " OFF \
    "6" "Stop nodes                                    " OFF \
    "7" "Run on systems                                " OFF \
    "8" "Upgrade nodes                                 " OFF \
    "9" "Rolling restart                               " OFF \
    "10" "Anm-control deploy                           " OFF \
    "11" "Anm-wallet deploy                            " OFF \
    "12" "Start wallet switch                          " OFF 3>&1 1>&2 2>&3)

if [[ $? -eq 255 ]]; then
    exit 0
fi

################################################################################################################ exit
if [[ "$SELECTION" == "1" ]]; then

    exit 0

######################################################################################################################## Change node count
elif [[ "$SELECTION" == "2" ]]; then

    ### set nodecount
    NodeCount=$(whiptail --title "Set node count" --inputbox "\nEnter node count" 8 40 "20" 3>&1 1>&2 2>&3)
    if [[ $? -eq 255 ]]; then
        exit 0
    fi

    NodeCountChange='sleep 120 && sed -i "s/^\\(NodeCap=\\).*/\\NodeCap='$NodeCount'/" /var/antctl/config '
    #NodeCountChange='sleep 120 && sed -i "s/^\\(CpuRemove=\\).*/\\CpuRemove='$NodeCount'/" /var/antctl/config '
    #NodeCountChange='sleep 120 && sed -i "s/^\\(MaxLoadAverageAllowed=\\).*/\\MaxLoadAverageAllowed='$NodeCount'/" /var/antctl/config '

    for machine in $machines; do
        ssh -t $machine ''$NodeCountChange'' >/dev/null 2>&1 &
        disown
        sleep 2
        echo
        echo "$machine Change node count request sent"

    done &
    disown

######################################################################################################################## upgrade nodes
elif [[ "$SELECTION" == "3" ]]; then

    for machine in $machines; do
        ssh -t $machine 'sed -i "s/^\\(NodeVersion=\\).*/NodeVersion=\"'$NodeVersion'\"/" /var/antctl/config && antup node '$NodeVersion'' >/dev/null 2>&1 &
        disown
        echo "$machine Upgrade nodes request sent"
        sleep 2
    done &
    disown

######################################################################################################################## update NTracking
elif [[ "$SELECTION" == "4" ]]; then

    for machine in $machines; do
        ssh -t $machine 'sudo rm -f /usr/bin/influx-resources.sh""*"" && sudo wget -P /usr/bin  '"$Location"'influx-resources.sh && sudo chmod u+x /usr/bin/influx-resources.sh && echo ""*"/20 "*" "*" "*" "*" $USER /usr/bin/mkdir -p /tmp/influx-resources && /bin/bash /usr/bin/influx-resources.sh > /tmp/influx-resources/influx-resources" | sudo tee /etc/cron.d/influx_resources' >/dev/null 2>&1 &
        disown
        sleep 1
        echo
        echo "$machine Upgrade influx request sent"
    done &
    disown

######################################################################################################################## Start nodes
elif [[ "$SELECTION" == "5" ]]; then

    for machine in $machines; do
        override=""
        CustomSetings

        ssh -t $machine 'bash <(curl -s '"$Location"'anm/scripts/StartNodes.sh) '$override'' >/dev/null 2>&1 &
        disown
        sleep 1
        echo
        echo "$machine Start nodes request sent"
    done &
    disown

######################################################################################################################## Stop nodes
elif [[ "$SELECTION" == "6" ]]; then

    for machine in $machines; do
        ssh -t $machine 'rm /var/antctl/config' >/dev/null 2>&1 &
        disown
        sleep 1
        echo
        echo "$machine Stop nodes request sent"
    done &
    disown

######################################################################################################################## Run on all systems
elif [[ "$SELECTION" == "7" ]]; then

    for machine in $machines; do
        ssh -t $machine 'bash <(curl -s '"$Location"'anm/scripts/runonall.sh)' >/dev/null 2>&1 &
        disown
        sleep 1
        echo
        echo "$machine Run on all machines request sent"
    done &
    disown
######################################################################################################################## upgrade nodes
elif [[ "$SELECTION" == "8" ]]; then

    for machine in $machines; do
        ssh -t $machine 'chmod u+x $HOME/.local/share/anm-control.sh && . $HOME/.local/share/anm-control.sh' >/dev/null 2>&1 &
        disown
        echo "$machine anm-control upgrade nodes request sent"
        sleep 2
    done &
    disown

######################################################################################################################## Rolling restart
elif [[ "$SELECTION" == "9" ]]; then

    for machine in $machines; do
        ssh -t $machine 'while [[ -f "/var/antctl/block" ]]; do sleep 1; done && sed -i 's/",$NodeRestarVer1,"/",$NodeRestarVer2,"/g' /var/antctl/NodeDetails' >/dev/null 2>&1 &
        disown
        echo "$machine Rolling restart request sent"
        sleep 2
    done &
    disown

######################################################################################################################## deploy anm control
elif [[ "$SELECTION" == "10" ]]; then

    if [[ -f "$HOME/.local/share/anm-control.sh" ]]; then
        for machine in $machines; do
            rsync -avz --update $HOME/.local/share/anm-control.sh $machine:$HOME/.local/share/anm-control.sh >/dev/null 2>&1 &
            disown
            echo "$machine anm-control deploy request sent"
            sleep 2
        done &
        disown
    else
        echo "no anm-control detected"
    fi

######################################################################################################################## deploy anm wallet
elif [[ "$SELECTION" == "11" ]]; then

    if [[ -f "$HOME/.local/share/anm-wallet" ]]; then
        for machine in $machines; do
            rsync -avz --update $HOME/.local/share/anm-wallet $machine:$HOME/.local/share/anm-wallet >/dev/null 2>&1 &
            disown
            rsync -avz --update $HOME/.local/share/anm-switch-wallets.sh $machine:$HOME/.local/share/anm-switch-wallets.sh >/dev/null 2>&1 &
            disown
            echo "$machine anm-wallet deploy request sent"
            sleep 2
        done &
        disown
    else
        echo "no anm-control detected"
    fi

######################################################################################################################## switch wallets
elif [[ "$SELECTION" == "12" ]]; then

    if [[ -f "$HOME/.local/share/anm-wallet" ]]; then
        for machine in $machines; do
            ssh -t $machine 'chmod u+x $HOME/.local/share/anm-switch-wallets.sh && . $HOME/.local/share/anm-switch-wallets.sh' >/dev/null 2>&1 &
            disown
            echo "$machine anm-wallet switch wallets request sent"
            sleep 2
        done &
        disown
    else
        echo "no switch wallets detected"
    fi
fi

#### old load level
#
#    LoadLevel=$(whiptail --title "System loading   " --radiolist \
#        "How much to load the system                      " 20 70 10 \
#        "1" "Low     -Default-                     " OFF \
#        "2" "Medium  -Recomended-                  " ON \
#        "3" "High    -Use Caution-                 " OFF \
#        "4" "Extreme -Extra Caution-               " OFF 3>&1 1>&2 2>&3)
#    if [[ $? -eq 255 ]]; then
#        exit 0
#    fi
#
#    if [[ "$LoadLevel" == "1" ]]; then
#        #Low
#        #max load average
#        override='sleep 120 && sed -i "s/^\\(DesiredLoadAverage=\\).*/\\1$(echo "$(nproc) "*" 1.5" | bc)/" /var/antctl/config && sed -i "s/^\\(MaxLoadAverageAllowed=\\).*/\\1$(echo "$(nproc) "*" 2.5" | bc)/" /var/antctl/config '
#        override='sleep 120 && sed -i "s/^\\(CpuLessThan=\\).*/\\CpuLessThan=70/" /var/antctl/config && sed -i "s/^\\(MemLessThan=\\).*/\\MemLessThan=70/" /var/antctl/config && sed -i "s/^\\(HDLessThan=\\).*/\\HDLessThan=70/" /var/antctl/config && sed -i "s/^\\(DelayStart=\\).*/\\DelayStart=5/" /var/antctl/config && sed -i "s/^\\(DelayUpgrade=\\).*/\\DelayUpgrade=10/" /var/antctl/config '
#    elif [[ "$LoadLevel" == "2" ]]; then
#        #Medium
#        override='sleep 120 && sed -i "s/^\\(DesiredLoadAverage=\\).*/\\1$(echo "$(nproc) "*" 2.0" | bc)/" /var/antctl/config && sed -i "s/^\\(MaxLoadAverageAllowed=\\).*/\\1$(echo "$(nproc) "*" 3.0" | bc)/" /var/antctl/config '
#        override='sleep 120 && sed -i "s/^\\(CpuLessThan=\\).*/\\CpuLessThan=80/" /var/antctl/config && sed -i "s/^\\(MemLessThan=\\).*/\\MemLessThan=80/" /var/antctl/config && sed -i "s/^\\(HDLessThan=\\).*/\\HDLessThan=80/" /var/antctl/config && sed -i "s/^\\(DelayStart=\\).*/\\DelayStart=4/" /var/antctl/config && sed -i "s/^\\(DelayUpgrade=\\).*/\\DelayUpgrade=5/" /var/antctl/config '
#    elif [[ "$LoadLevel" == "3" ]]; then
#        #high
#        override='sleep 120 && sed -i "s/^\\(DesiredLoadAverage=\\).*/\\1$(echo "$(nproc) "*" 2.5" | bc)/" /var/antctl/config && sed -i "s/^\\(MaxLoadAverageAllowed=\\).*/\\1$(echo "$(nproc) "*" 3.5" | bc)/" /var/antctl/config '
#        override='sleep 120 && sed -i "s/^\\(CpuLessThan=\\).*/\\CpuLessThan=90/" /var/antctl/config && sed -i "s/^\\(MemLessThan=\\).*/\\MemLessThan=90/" /var/antctl/config && sed -i "s/^\\(HDLessThan=\\).*/\\HDLessThan=90/" /var/antctl/config && sed -i "s/^\\(DelayStart=\\).*/\\DelayStart=3/" /var/antctl/config && sed -i "s/^\\(DelayUpgrade=\\).*/\\DelayUpgrade=4/" /var/antctl/config '
#    else
#        #Extream
#        override='sleep 120 && sed -i "s/^\\(DesiredLoadAverage=\\).*/\\1$(echo "$(nproc) "*" 3.0" | bc)/" /var/antctl/config && sed -i "s/^\\(MaxLoadAverageAllowed=\\).*/\\1$(echo "$(nproc) "*" 4.0" | bc)/" /var/antctl/config '
#        override='sleep 120 && sed -i "s/^\\(CpuLessThan=\\).*/\\CpuLessThan=95/" /var/antctl/config && sed -i "s/^\\(MemLessThan=\\).*/\\MemLessThan=95/" /var/antctl/config && sed -i "s/^\\(HDLessThan=\\).*/\\HDLessThan=95/" /var/antctl/config && sed -i "s/^\\(DelayStart=\\).*/\\DelayStart=2/" /var/antctl/config && sed -i "s/^\\(DelayUpgrade=\\).*/\\DelayUpgrade=3/" /var/antctl/config '
#    fi
#
#    for machine in $machines; do
#        # will only afect systems thats name begins with "h" !!
#        if [[ "$machine" == "h"* ]]; then
#            ssh -t $machine ''$override'' >/dev/null 2>&1 &
#           disown
#            sleep 2
#            echo
#            echo "$machine Change Load request sent"
#        fi
#
#    done &
#    disown
