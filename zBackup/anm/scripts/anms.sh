#!/usr/bin/env bash

vtrack="1.4"

#Data path: /var/antctl/services/antnode1
#Log path: /var/log/antnode/antnode1
#Bin path: /var/antctl/services/antnode1/antnode

# sudo rm -f /usr/bin/anms.sh* && sudo wget -P /usr/bin https://raw.githubusercontent.com/safenetforum-community/NTracking/main/anm/scripts/anms.sh && sudo chmod u+x /usr/bin/anms.sh

time_min=$(date +"%M")
time_hour=$(date +"%H")

# node port range start in thosand
ntpr=55

#print date and time
clear
echo $(date '+%d/%m/%Y  %H:%M')
echo

export PATH=$PATH:$HOME/.local/bin
source ~/.config/safe/env

NodePath=$(which safenode)
LatestNodeVer=$($NodePath --version | awk 'NR==1 {print $3}' | cut -c2-)

# declare or load array from file
declare -A node_details_store
. /var/safenode-manager/NodeDetails >/dev/null 2>&1

CheckSetUp() {
    if [[ -f "/var/safenode-manager/system" ]]; then
        # block script from running if previous iteration is still running
        if [[ -f "/var/safenode-manager/block" ]]; then
            echo "script already running exiting !!" && echo
            echo ""$time_hour":"$time_min" script already running exiting !!" >>/var/safenode-manager/simplelog
            exit 0
        else
            # create blocking file
            touch /var/safenode-manager/block
        fi
        echo "existing install found loading info" && echo
        . /var/safenode-manager/system
        . /var/safenode-manager/counters
        rm /var/safenode-manager/counters
        . /var/safenode-manager/config
    else
        echo "first install creating folders and info" && echo
        sudo useradd -m -p ed5wsejw6S4ifjlwjfSlwj safe
        sudo mkdir -p /var/safenode-manager
        sudo chown -R $USER:$USER /var/safenode-manager
        sudo mkdir -p /var/safenode-manager/services /var/log/safenode
        sudo chown -R safe:safe /var/safenode-manager/services /var/log/safenode
        echo "CpuCount=$(echo "$(nproc) / 1" | bc)" >>/var/safenode-manager/system
        . /var/safenode-manager/system
        echo "CounterStart=0" >>/var/safenode-manager/counters
        echo "CounterUpgrade=0" >>/var/safenode-manager/counters
        . /var/safenode-manager/counters
        rm /var/safenode-manager/counters
        echo "# edit this file to confrol behavior of the script" >>/var/safenode-manager/config
        echo >>/var/safenode-manager/config
        echo 'DiscordUsername="--owner DiscordUserName"' >>/var/safenode-manager/config
        echo 'RewardsAddress="--rewards-address EtheriumAddress"' >>/var/safenode-manager/config
        echo >>/var/safenode-manager/config
        echo >>/var/safenode-manager/config
        echo "MaxLoadAverageAllowed=$(echo "$(nproc) * 1.0" | bc)" >>/var/safenode-manager/config
        echo "DesiredLoadAverage=$(echo "$(nproc) * 0.6" | bc)" >>/var/safenode-manager/config
        echo >>/var/safenode-manager/config
        echo "CpuLessThan=50" >>/var/safenode-manager/config
        echo "MemLessThan=70" >>/var/safenode-manager/config
        echo "HDLessThan=70" >>/var/safenode-manager/config
        echo "CpuRemove=45" >>/var/safenode-manager/config
        echo "MemRemove=90" >>/var/safenode-manager/config
        echo "HDRemove=90" >>/var/safenode-manager/config
        echo >>/var/safenode-manager/config
        echo "# counters start at this number and upon action happening" >>/var/safenode-manager/config
        echo "# increment down once every time script runs when zero action is allowed again" >>/var/safenode-manager/config
        echo "# for systems 24 and over cores there is a seperate value calculate " >>/var/safenode-manager/config
        echo >>/var/safenode-manager/config
        echo "DelayStart=5" >>/var/safenode-manager/config
        echo "DelayReStart=5" >>/var/safenode-manager/config
        echo "DelayUpgrade=5" >>/var/safenode-manager/config
        echo "DelayRemove=10" >>/var/safenode-manager/config
        echo >>/var/safenode-manager/config
        echo "NodeCap=20" >>/var/safenode-manager/config
        echo >>/var/safenode-manager/config
        echo "UpgradeHour=$(shuf -i 0-23 -n 1)" >>/var/safenode-manager/config
        echo "UpgradeMin=$(shuf -i 0-59 -n 1)" >>/var/safenode-manager/config
        echo >>/var/safenode-manager/config
        echo 'NodeVersion="--version '$LatestNodeVer'"' >>/var/safenode-manager/config
        . /var/safenode-manager/config
    fi
}

StartNode() {
    if (($(echo "$CounterStart != 0" | bc))); then
        echo "node start canceled due to timer" && echo
        return 0
    fi
    if (($(echo "$Remove != 0" | bc))); then
        echo "node starting not allowed during Removal" && echo
        return 0
    fi
    if (($(echo "$Upgrade != 0" | bc))); then
        echo "node starting not allowed during upgrade" && echo
        return 0
    fi

    if [[ -f "/var/safenode-manager/MaxShunnedNode" ]]; then
        echo "Shuun gun" && echo
        ShunnGun
        return 0
    fi

    if (($(echo "$RunningNodes == $NodeCap" | bc))); then
        echo "node starting not allowed due to node cap" && echo
        # where shunn gun used to be
        return 0
    fi

    if (($(echo "$StoppedNodes == 0" | bc))); then
        AddNode
    fi

    node_number=$(seq -f "%03g" $NextNodeToSorA $NextNodeToSorA)
    node_name=safenode$node_number
    echo ""$time_hour":"$time_min" Start $node_name" >>/var/safenode-manager/simplelog
    echo "Starting $node_name"
    sudo ufw allow $ntpr$node_number/udp comment "$node_name"
    echo "Opened firewall port $ntpr$node_number/udp"
    sudo systemctl start $node_name
    echo "systemctl start $node_name"
    sleep 45
    # status="$(sudo systemctl status $node_name.service --no-page)"
    # PeerId=$(echo "$status" | grep "id=" | cut -f2 -d= | cut -d '`' -f 1)
    node_metadata="$(curl -s 127.0.0.1:13$node_number/metadata)"
    PeerId="$(echo "$node_metadata" | grep sn_networking_peer_id | awk 'NR==3 {print $1}' | cut -d'"' -f 2)"
    node_details_store[$node_number]="$node_name,$PeerId,$(/var/safenode-manager/services/$node_name/safenode --version | awk 'NR==1 {print $3}' | cut -c2-),RUNNING"
    echo "$node_name Started"
    sed -i 's/CounterStart=.*/CounterStart='$DelayStart'/g' /var/safenode-manager/counters
    echo "reset node start timer" && echo
}

AddNode() {
    node_number=$(seq -f "%03g" $NextNodeToSorA $NextNodeToSorA)
    node_name=safenode$node_number
    echo ""$time_hour":"$time_min" Add $node_name" >>/var/safenode-manager/simplelog
    echo "Adding $node_name"
    sudo mkdir -p /var/safenode-manager/services/$node_name /var/log/safenode/$node_name
    echo "mkdir -p /var/safenode-manager/services/$node_name"
    sudo cp $NodePath /var/safenode-manager/services/$node_name
    echo "cp $NodePath /var/safenode-manager/services/$node_name"
    sudo chown -R safe:safe /var/safenode-manager/services/$node_name /var/log/safenode/$node_name /var/safenode-manager/services/$node_name/safenode
    echo "ownership changed to user safe"
    sudo tee /etc/systemd/system/"$node_name".service 2>&1 >/dev/null <<EOF
[Unit]
Description=$node_name
[Service]
User=safe
ExecStart=/var/safenode-manager/services/$node_name/safenode --root-dir /var/safenode-manager/services/$node_name --port $ntpr$node_number --enable-metrics-server --metrics-server-port 13$node_number $RewardsAddress --log-output-dest /var/log/safenode/$node_name --max-log-files 1 --max-archived-log-files 1 evm-arbitrum-sepolia
Restart=always
RestartSec=300
EOF

    echo "service file created at /etc/systemd/system/"$node_name".service"
    sudo systemctl daemon-reload
    echo "systemctl daemon-reload" && echo
}

TearDown() {
    echo "Nuke sequence initiated !!" && echo
    sudo rm /etc/cron.d/anm
    echo "rm /etc/cron.d/anm"
    sudo systemctl stop safenode*
    echo "systemctl stop safenode*"
    sudo rm /etc/systemd/system/safenode*
    echo "rm /etc/systemd/system/safenode*"
    sudo systemctl daemon-reload
    echo "systemctl daemon-reload"
    sudo rm -rf /var/log/safenode
    echo "rm -rf /var/log/safenode" && echo
    unset 'node_details_store[*]'
    echo "cleared array"
    for ((i = 1; i <= $RunningNodes; i++)); do
        PortToClose=$(("$ntpr"000 + $i))
        echo "deleting firewall rule $PortToClose"
        sudo ufw delete allow $PortToClose/udp
    done
    sudo rm -f /etc/cron.d/scrape
    sudo rm -f /usr/bin/scrape.sh
    sudo rm -f $HOME/scrape
    sudo rm -rf /var/safenode-manager
    sudo rm -rf /home/safe/.local/share/safe/node
    sleep 5
    sudo rm -rf /var/safenode-manager
    sudo rm -rf /home/safe/.local/share/safe/node
    # save all wallets for later scraping
    cp -r /var/safenode-manager/wallets $HOME/.local/share/wallets
    sleep 5
    echo "rm -rf /var/safenode-manager"
    sudo rm -f /usr/bin/anms.sh
    echo
    sudo reboot
}

RemoveNode() {
    node_number=$(seq -f "%03g" $1 $1)
    node_name=safenode$node_number
    echo ""$time_hour":"$time_min" Remove $node_name" >>/var/safenode-manager/simplelog
    echo "Removing $node_name" && echo
    sudo systemctl stop --now $node_name
    echo "Stopping $node_name"
    sudo rm -rf /var/safenode-manager/services/$node_name /var/log/safenode/$node_name
    echo "rm -rf /var/safenode-manager/services/$node_name /var/log/safenode/$node_name"
    sudo rm /etc/systemd/system/$node_name.service
    echo "rm /etc/systemd/system/$node_name.service"
    sudo systemctl daemon-reload
    echo "systemctl daemon-reload"
    sudo ufw delete allow $ntpr$node_number/udp
    echo "closed firewall port $ntpr$node_number/udp"
    unset 'node_details_store[$node_number]'
    echo "deleted array entery" && echo

}

StopNode() {
    if (($(echo "$NextNodeSorR == 0" | bc))); then
        echo "no nodes to stop" && echo
        return 0
    fi
    node_number=$(seq -f "%03g" $NextNodeSorR $NextNodeSorR)
    node_name=safenode$node_number
    echo ""$time_hour":"$time_min" Stop $node_name" >>/var/safenode-manager/simplelog
    echo "Stopping $node_name"
    PIS=$(echo "${node_details_store[$node_number]}" | awk -F',' '{print $2}')
    NVS=$(echo "${node_details_store[$node_number]}" | awk -F',' '{print $3}')
    node_details_store[$node_number]="$node_name,$PIS,$NVS,STOPPED"
    echo "updated array $node_name"
    sudo systemctl stop $node_name
    echo "systemctl stop $node_name"
    sudo ufw delete allow $ntpr$node_number/udp
    echo "closed firewall port $ntpr$node_number/udp"
    echo "$node_name Stopped" && echo
    echo "RemoveCounter$NextNodeSorR=$DelayRemove" >>/var/safenode-manager/counters
    sed -i 's/CounterStart=.*/CounterStart='$DelayReStart'/g' /var/safenode-manager/counters
    echo "reset node start timer" && echo
}

UpgradeNode() {
    if (($(echo "$CounterUpgrade != 0" | bc))); then
        echo "node upgrade canceled due to timer" && echo
        return 0
    fi
    if (($(echo "$Remove != 0" | bc))); then
        echo "upgrade not allowed during Removal" && echo
        return 0
    fi
    node_number=$(seq -f "%03g" $1 $1)
    node_name=safenode$node_number
    echo ""$time_hour":"$time_min" Upgrade $node_name running" >>/var/safenode-manager/simplelog
    echo "upgradeing $node_name"
    sudo systemctl stop $node_name
    echo "systemctl stop $node_name"
    # remove old node data on upgrade
    sudo rm -rf /var/safenode-manager/services/$node_name/*
    echo "rm -rf /var/safenode-manager/services/$node_name/*"
    sudo cp $NodePath /var/safenode-manager/services/$node_name
    echo "cp $NodePath /var/safenode-manager/services/$node_name"
    sudo systemctl start $node_name
    echo "systemctl start $node_name"
    sleep 45
    # status="$(sudo systemctl status $node_name.service --no-page)"
    # PeerId=$(echo "$status" | grep "id=" | cut -f2 -d= | cut -d '`' -f 1)
    node_metadata="$(curl -s 127.0.0.1:13$node_number/metadata)"
    PeerId="$(echo "$node_metadata" | grep sn_networking_peer_id | awk 'NR==3 {print $1}' | cut -d'"' -f 2)"
    node_details_store[$node_number]="$node_name,$PeerId,$(/var/safenode-manager/services/$node_name/safenode --version | awk 'NR==1 {print $3}' | cut -c2-),RUNNING"
    echo "updated array"
    sed -i 's/CounterUpgrade=.*/CounterUpgrade='$DelayUpgrade'/g' /var/safenode-manager/counters
    echo "reset node upgrade timer" && echo
}

StoppedUpgrade() {
    node_number=$(seq -f "%03g" $1 $1)
    node_name=safenode$node_number
    echo ""$time_hour":"$time_min" Upgrade $node_name stopped" >>/var/safenode-manager/simplelog
    echo "upgradeing $node_name"
    # remove old node data on upgrade
    sudo rm -rf /var/safenode-manager/services/$node_name/*
    echo "rm -rf /var/safenode-manager/services/$node_name/*"
    sudo cp $NodePath /var/safenode-manager/services/$node_name
    echo "cp $NodePath /var/safenode-manager/services/$node_name"
    PIS=$(echo "${node_details_store[$node_number]}" | awk -F',' '{print $2}')
    node_details_store[$node_number]="$node_name,$PIS,$(/var/safenode-manager/services/$node_name/safenode --version | awk 'NR==1 {print $3}' | cut -c2-),STOPPED"
    echo "updated array" && echo
}

CalculateValues() {
    ArrayAsString=$(for num in $(echo "${!node_details_store[@]}" | tr ' ' '\n' | sort -n); do
        echo "${node_details_store[$num]}"
    done)

    TotalNodes=$(ls /var/safenode-manager/services | wc -l)
    RunningNodes=$(echo "$ArrayAsString" | grep -c "RUNNING")
    StoppedNodes=$(echo "$ArrayAsString" | grep -c "STOPPED")
    if (($(echo "$StoppedNodes > 0" | bc))); then
        AddNewNode=0
    else
        AddNewNode=1
    fi
    NextNodeToSorA=$(echo "$RunningNodes + 1" | bc)
    NextNodeSorR=$RunningNodes
    NodesLatestV=$(echo "$ArrayAsString" | grep -c $LatestNodeVer)
    NodesToUpgrade=$(($TotalNodes - $NodesLatestV))
    NextToUpgrade=$(($TotalNodes - $NodesToUpgrade + 1))
    Upgrade=$(echo "$NodesToUpgrade >= 1" | bc) && echo
    # downgrade blocker
    if (($(echo "$Upgrade == 1" | bc))); then
        Node1Version="$(echo "${node_details_store[001]}" | awk -F',' '{print $3}')"
        LNV=$(echo "$LatestNodeVer" | tr -d .)
        N1V=$(echo "$Node1Version" | tr -d .)
        if (($(echo "$LNV < $N1V" | bc -l))); then
            Upgrade=0
            safeup node --version $Node1Version && echo
            echo "node upgrade canceled due to lower version" && echo
        fi
    fi
    Remove=0
    LastNode="RemoveCounter$TotalNodes"
    LastNode="${!LastNode}"
    if (($(echo " $StoppedNodes > 0" | bc))) && (($(echo " $LastNode == 0" | bc))); then Remove=1; fi
    LoadAverage1=$(uptime | awk '{print $(NF-2)}' | awk '{print $(NF-1)}' FS=,)
    LoadAverage5=$(uptime | awk '{print $(NF-1)}' | awk '{print $(NF-1)}' FS=,)
    LoadAverage15=$(uptime | awk '{print $(NF-0)}' | awk '{print $(NF-1)}' FS=,)
    # load allow calc
    if (($(echo "$LoadAverage1 < $DesiredLoadAverage" | bc))) && (($(echo "$LoadAverage5 < $DesiredLoadAverage" | bc))) && (($(echo "$LoadAverage15 < $DesiredLoadAverage" | bc))); then LoadAllow=1; else LoadAllow=0; fi
    if (($(echo "$LoadAverage1 > $MaxLoadAverageAllowed" | bc))) && (($(echo "$LoadAverage5 > $MaxLoadAverageAllowed" | bc))); then LoadNotAllow=1; else LoadNotAllow=0; fi
    #stop nodes being stoped if in down trend
    # if (($(echo "$LoadNotAllow == 1 " | bc))) && (($(echo "$LoadAverage1 < $MaxLoadAverageAllowed" | bc))); then LoadNotAllow=0; fi
    UsedCpuPercent=$(vmstat 1 2 | awk 'END { print 100 - $15 }')
    FreeMemPercent=$(free | grep Mem | awk '{ printf("%.4f\n", $7/$2 * 100.0) }')
    UsedMemPercent=$(echo "100 - $FreeMemPercent" | bc)
    UsedHdPercent=$(df -hP /var | awk '{print $5}' | tail -1 | sed 's/%$//g')
    AllowCpu=$(echo "$UsedCpuPercent < $CpuLessThan" | bc)
    AllowMem=$(echo "$UsedMemPercent < $MemLessThan" | bc)
    AllowHD=$(echo "$UsedHdPercent < $HDLessThan" | bc)
    RemCpu=$(echo "$UsedCpuPercent > $CpuRemove " | bc)
    RemMem=$(echo "$UsedMemPercent > $MemRemove " | bc)
    RemHD=$(echo "$UsedHdPercent > $HDRemove " | bc)
    AllowNodeCap=$(echo "$RunningNodes <= $NodeCap" | bc)

    #variable delay start test
    if (($(echo "$CpuCount >= 24 " | bc))); then
        DelayStart=$(echo "scale=0; $RunningNodes / 25" | bc)
        DelayStart=5
        DelayUpgrade=$DelayStart
    fi

}

PrintDetails() {
    echo "Version $vtrack DiscordUsername $DiscordUsername RewardsAddress $RewardsAddress" && echo
    echo "Used CPU percent $UsedCpuPercent% Used MEM $UsedMemPercent% Used HD percent $UsedHdPercent%" && echo
    echo "LoadAverage1 $LoadAverage1 LoadAverage5 $LoadAverage5 LoadAverage15 $LoadAverage15" && echo
    echo "TotalNodes $TotalNodes RunningNodes $RunningNodes StoppedNodes $StoppedNodes" && echo
    echo "AddNewNode $AddNewNode NextNodeToStartOrAdd $NextNodeToSorA NextNodeStopOrRemove $NextNodeSorR" && echo
    echo "CpuCount $CpuCount MaxLoadAverageAllowed $MaxLoadAverageAllowed DesiredLoadAverage $DesiredLoadAverage NodeCap $NodeCap" && echo
    echo "Latest Ver $LatestNodeVer NodesLatestVersion $NodesLatestV NodesToUpgrade $NodesToUpgrade NextToUpgrade  $NextToUpgrade"
    echo "Upgrade $Upgrade Remove $Remove" && echo
    echo "AllowCpu $AllowCpu AllowMem $AllowMem AllowHD $AllowHD RemCpu $RemCpu RemMem $RemMem RemHD $RemHD"
    echo "LoadAllow $LoadAllow LoadNotAllow $LoadNotAllow AllowNodeCap $AllowNodeCap"
    echo "DelayStart $DelayStart DelayReStart $DelayReStart DelayUpgrade $DelayUpgrade DelayRemove $DelayRemove"
    echo "CounterStart $CounterStart CounterUpgrade $CounterUpgrade" && echo
    echo "$(</var/safenode-manager/counters)" && echo
}

UpGrade() {

    if (($(echo "$Upgrade == 1" | bc))); then
        # block upgrade if system under heavy load
        if (($(echo "$LoadNotAllow == 1" | bc))); then
            echo ""$time_hour":"$time_min" Upgrade safenode"$NextToUpgrade" blocked heavy load" >>/var/safenode-manager/simplelog
            return 0
        fi
        if (($(echo "$NextToUpgrade <= $RunningNodes" | bc))); then
            echo "upgrade running safenode$NextToUpgrade" && echo
            UpgradeNode $NextToUpgrade
        else
            echo "upgrade stopped nodes" && echo
            for ((i = 1; i <= $NodesToUpgrade; i++)); do
                nfu=$(echo "$NodesLatestV + $i" | bc) && echo
                StoppedUpgrade $nfu
                echo "upgrade stopped node$nfu" && echo
                sleep 5
            done

        fi
    else
        echo "no upgrade requiered" && echo
    fi
}

Removal() {
    if (($(echo "$Remove == 1" | bc))); then
        RemoveNode $TotalNodes
        CalculateValues
    else
        echo "no removal requiered" && echo
    fi
}

IncrementCounters() {
    if (($(echo "$CounterStart > 0 " | bc))); then
        CounterStart=$(echo "$CounterStart - 1" | bc)
    fi
    if (($(echo "$CounterUpgrade > 0 " | bc))); then
        CounterUpgrade=$(echo "$CounterUpgrade - 1" | bc)
    fi
    echo "CounterStart=$CounterStart" >>/var/safenode-manager/counters
    echo "CounterUpgrade=$CounterUpgrade" >>/var/safenode-manager/counters
    for ((i = 1; i <= $StoppedNodes; i++)); do
        nfr=$(echo "$RunningNodes + $i" | bc)
        nfrcn="RemoveCounter$nfr"
        nfrc="${!nfrcn}"
        if (($(echo "$nfrc > 0 " | bc))); then
            nfrc=$(echo "$nfrc - 1" | bc)
            echo "$nfrcn=$nfrc" >>/var/safenode-manager/counters
        fi
    done
}

ShunnGun() {
    if [[ -f "/var/safenode-manager/MaxShunnedNode" ]]; then
        if (($(echo "$Upgrade != 0" | bc))); then
            echo "Shunngun not allowed during upgrade" && echo
            return 0
        fi
        # load veraiable from ntracking for max shunned node
        . /var/safenode-manager/MaxShunnedNode >/dev/null 2>&1
        node_number=$(seq -f "%03g" $MaxShunnedNode $MaxShunnedNode)
        node_name=safenode$node_number
        echo ""$time_hour":"$time_min" Shunn gun $node_name Shunn's $ShunnedValue" >>/var/safenode-manager/simplelog
        echo && echo "Shunngun $node_name" && echo
        #stop max shunned node
        echo "Stopping $node_name"
        PIS=$(echo "${node_details_store[$node_number]}" | awk -F',' '{print $2}')
        NVS=$(echo "${node_details_store[$node_number]}" | awk -F',' '{print $3}')
        node_details_store[$node_number]="$node_name,$PIS,$NVS,STOPPED"
        echo "updated array $node_name"
        sudo systemctl stop $node_name
        echo "systemctl stop $node_name"
        # copy wallet to folder for later scraping
        WalletDir=""$(date +%s)"-"$node_name"-Shunn"
        mkdir -p $HOME/.local/share/wallets/$WalletDir/wallet
        cp -r /var/safenode-manager/services/$node_name/wallet/* $HOME/.local/share/wallets/$WalletDir/wallet
        sudo rm -rf /var/safenode-manager/services/$node_name/*
        sleep 5
        sudo cp $NodePath /var/safenode-manager/services/$node_name
        echo "cp $NodePath /var/safenode-manager/services/$node_name"
        sleep 5
        #restart node
        echo "Starting $node_name"
        sudo systemctl start $node_name
        echo "systemctl start $node_name"
        sleep 30
        status="$(sudo systemctl status $node_name.service --no-page)"
        PeerId=$(echo "$status" | grep "id=" | cut -f2 -d= | cut -d '`' -f 1)
        node_details_store[$node_number]="$node_name,$PeerId,$(/var/safenode-manager/services/$node_name/safenode --version | awk 'NR==1 {print $3}' | cut -c2-),RUNNING"
        echo "$node_name Started"
        sed -i 's/CounterStart=.*/CounterStart='$DelayStart'/g' /var/safenode-manager/counters
        echo "reset node start timer" && echo
        # remove veraiable from ntracking for max shunned node
        rm /var/safenode-manager/MaxShunnedNode >/dev/null 2>&1
    fi
}

CheckSetUp
# overrides
. /var/safenode-manager/override
CalculateValues
IncrementCounters
. $HOME/.local/share/anm-wallet
PrintDetails
UpGrade
Removal

####################################################################################### logic for starting and stoping nodes
if [[ ! -f "/var/safenode-manager/config" ]] || [[ "$Action" == "4" ]]; then
    echo "Initiate Nuke" && echo
    TearDown
elif (($(echo $AllowCpu))) && (($(echo $AllowMem))) && (($(echo $AllowHD))) && (($(echo $LoadAllow))) && (($(echo $AllowNodeCap))) || [[ "$Action" == "1" ]]; then
    echo "start node" && echo
    StartNode
elif (($(echo "$RemCpu == 1" | bc))) || (($(echo "$RemMem == 1" | bc))) || (($(echo "$RemHD == 1" | bc))) || (($(echo "$LoadNotAllow == 1" | bc))) || [[ "$Action" == "2" ]] || (($(echo "$AllowNodeCap == 0" | bc))); then
    if (($(echo "$RemHD == 1" | bc))); then
        StopNode
        RemoveNode $TotalNodes
        echo "Node $TotalNodes Removed due to hard drive space" && echo
    elif (($(echo "$AllowNodeCap == 0" | bc))); then
        if (($(echo " $StoppedNodes == 0" | bc))); then StopNode; fi
        RemoveNode $TotalNodes
        echo "Node $TotalNodes Removed node cap" && echo
    else
        echo "stop node" && echo
        StopNode
    fi
else

    ShunnGun
    echo "Node count Ok" && echo
fi
#############################################################################################################################

for num in $(echo "${!node_details_store[@]}" | tr ' ' '\n' | sort -n); do
    echo "${node_details_store[$num]}"
done

echo

#save node details aray
declare -p node_details_store >/var/safenode-manager/NodeDetails

if (($(echo "$time_hour == $UpgradeHour" | bc))) && (($(echo "$time_min == $UpgradeMin" | bc))) && (($(echo "$Upgrade == 0" | bc))); then
    rm /var/safenode-manager/log
    rm /var/safenode-manager/simplelog

    if [[ -f "$HOME/.local/share/anm-control.sh" ]]; then
        #echo "anm control detected" && echo
        #. $HOME/.local/share/anm-control
        #safeup node $NodeVersion && echo
        #echo "upgradeing safe node binary with safeup node $NodeVersion" && echo
        sleep 1
    else
        safeup node $NodeVersion && echo
        echo "upgradeing safe node binary with safeup node $NodeVersion" && echo
    fi
fi

echo
echo
echo #########################################################################################################################

# remove block file
rm /var/safenode-manager/block
