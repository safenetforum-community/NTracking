#!/usr/bin/env bash

# uncoment out Action variable for manual control of script
# 1 startnodes 2 stopnodes 3 no node change 4 teardown
#Action=1

#sudo rm -f /usr/bin/anm.sh* && sudo wget -P /usr/bin  https://raw.githubusercontent.com/safenetforum-community/NTracking/main/anm.sh && sudo chmod u+x /usr/bin/anm.sh
#echo "* * * * * $USER /usr/bin/mkdir -p /var/safenode-manager && /bin/bash /usr/bin/anm.sh > /var/safenode-manager/log" | sudo tee /etc/cron.d/anm


#print date and time
clear && echo $(date '+%d/%m/%Y  %H:%M') && echo

DiscordUsername=timbobjohnes

export PATH=$PATH:$HOME/.local/bin

# put if for what time to check for new version
#safeup node

NodePath=$(which safenode)
LatestNodeVer=$($NodePath -V | awk '{print $3}')

# declare or load array from file
declare -A node_details_store
. /var/safenode-manager/NodeDetails >/dev/null 2>&1

CheckSetUp() {
        if [[ -f "/var/safenode-manager/system" ]]; then
                echo "existing install found loading info" && echo
                . /var/safenode-manager/system
                . /var/safenode-manager/counters
                rm /var/safenode-manager/counters
                . /var/safenode-manager/config
        else
                echo "first install creating folders and info" && echo
                sudo mkdir -p /var/safenode-manager
                sudo chown -R $USER:$USER /var/safenode-manager
                sudo mkdir -p /var/safenode-manager/services /var/log/safenode
                sudo chown -R safe:safe /var/safenode-manager/services /var/log/safenode
                echo "CpuCount=$(echo "$(nproc --all) / 1" | bc)" >>/var/safenode-manager/system
                echo "BatchSize=$(echo "$(nproc --all) / 2" | bc)" >>/var/safenode-manager/system
                . /var/safenode-manager/system
                echo "CounterStart=0" >>/var/safenode-manager/counters
                echo "CounterUpgrade=0" >>/var/safenode-manager/counters
                . /var/safenode-manager/counters
                rm /var/safenode-manager/counters
                echo "# edit this file to confrol behavior of the script" >>/var/safenode-manager/config
                echo >>/var/safenode-manager/config
                echo "MaxLoadAverageAllowed=$(echo "$(nproc --all) * 2" | bc)" >>/var/safenode-manager/config
                echo "DesiredLoadAverage=$(echo "$(nproc --all) * 1" | bc)" >>/var/safenode-manager/config
                echo >>/var/safenode-manager/config
                echo "CpuLessThan=90" >>/var/safenode-manager/config
                echo "MemLessThan=90" >>/var/safenode-manager/config
                echo "HDLessThan=90" >>/var/safenode-manager/config
                echo >>/var/safenode-manager/config
                echo "# counters start at this number and upon action happening" >>/var/safenode-manager/config
                echo "# increment down once every time script runs when zero action is allowed again" >>/var/safenode-manager/config
                echo "DelayStart=2" >>/var/safenode-manager/config
                echo "DelayUpgrade=5" >>/var/safenode-manager/config
                echo "DelayRemove=60" >>/var/safenode-manager/config
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
        if (($(echo "$StoppedNodes == 0" | bc))); then
                AddNode
        fi
        node_number=$(seq -f "%03g" $NextNodeToSorA $NextNodeToSorA)
        node_name=safenode$node_number
        echo "Starting $node_name"
        sudo ufw allow 12$node_number/udp
        echo "Opened firewall port 12$node_number/udp"
        sudo systemctl start $node_name
        echo "systemctl start $node_name"
        sleep 5
        status="$(sudo systemctl status $node_name.service --no-page)"
        PeerId=$(echo "$status" | grep "id=" | cut -f2 -d= | cut -d '`' -f 1)
        node_details_store[$node_number]="$node_name,$PeerId,$(/var/safenode-manager/services/$node_name/safenode -V | awk '{print $3}'),RUNNING"
        echo "$node_name Started"
        sed -i 's/CounterStart=.*/CounterStart='$DelayStart'/g' /var/safenode-manager/counters
        echo "reset node start timer" && echo
}

AddNode() {
        node_number=$(seq -f "%03g" $NextNodeToSorA $NextNodeToSorA)
        node_name=safenode$node_number
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
ExecStart=/var/safenode-manager/services/$node_name/safenode --root-dir /var/safenode-manager/services/$node_name --log-output-dest /var/log/safenode/$node_name --port 12$node_number --enable-metrics-server --metrics-server-port 13$node_number --owner $DiscordUsername --max_log_files 5 --max_archived_log_files 5
Restart=on-failure
EOF
        echo "servce file created at /etc/systemd/system/$node_name.service"
        sudo systemctl daemon-reload
        echo "systemctl daemon-reload" && echo
}

TearDown() {
        echo "Nuke sequence initiated !!" && echo
        sudo systemctl stop safenode*
        echo "systemctl stop safenode*"
        sudo rm /etc/systemd/system/safenode*
        echo "rm /etc/systemd/system/safenode*"
        sudo systemctl daemon-reload
        echo "systemctl daemon-reload"
        sudo rm -rf /var/safenode-manager
        echo "rm -rf /var/safenode-manager"
        sudo rm -rf /var/log/safenode
        echo "rm -rf /var/log/safenode" && echo
        unset 'node_details_store[*]'
        echo "cleared array"
        for ((i = 1; i <= $RunningNodes; i++)); do
                PortToClose=$((12000 + $i))
                echo "deleting firewall rule $PortToClose"
                sudo ufw delete allow $PortToClose/udp
        done
        echo
}

RemoveNode() {
        node_number=$(seq -f "%03g" $1 $1)
        node_name=safenode$node_number
        echo "Removing $node_name" && echo
        sudo systemctl stop --now $node_name
        echo "Stopping $node_name"
        sudo rm -rf /var/safenode-manager/services/$node_name /var/log/safenode/$node_name
        echo "rm -rf /var/safenode-manager/services/$node_name /var/log/safenode/$node_name"
        sudo rm /etc/systemd/system/$node_name.service
        echo "rm /etc/systemd/system/$node_name.service"
        sudo systemctl daemon-reload
        echo "systemctl daemon-reload"
        sudo ufw delete allow 12$node_number/udp
        echo "closed firewall port 12$node_number/udp"
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
        echo "Stopping $node_name"
        node_details_store[$node_number]="$node_name,,$(/var/safenode-manager/services/$node_name/safenode -V | awk '{print $3}'),STOPPED"
        echo "updated array $node_name"
        sudo systemctl stop $node_name
        echo "systemctl stop $node_name"
        sudo ufw delete allow 12$node_number/udp
        echo "closed firewall port 12$node_number/udp"
        echo "$node_name Stopped" && echo
        echo "RemoveCounter$NextNodeSorR=$DelayRemove" >>/var/safenode-manager/counters
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
        echo "upgradeing $node_name"
        sudo systemctl stop $node_name
        echo "systemctl stop $node_name"
        sudo cp $NodePath /var/safenode-manager/services/$node_name
        echo "cp $NodePath /var/safenode-manager/services/$node_name"
        sudo systemctl start $node_name
        echo "systemctl start $node_name"
        sleep 5
        status="$(sudo systemctl status $node_name.service --no-page)"
        PeerId=$(echo "$status" | grep "id=" | cut -f2 -d= | cut -d '`' -f 1)
        node_details_store[$node_number]="$node_name,$PeerId,$(/var/safenode-manager/services/$node_name/safenode -V | awk '{print $3}'),RUNNING"
        echo "updated array"
        sed -i 's/CounterUpgrade=.*/CounterUpgrade='$DelayUpgrade'/g' /var/safenode-manager/counters
        echo "reset node upgrade timer" && echo
}

StoppedUpgrade() {
        node_number=$(seq -f "%03g" $1 $1)
        node_name=safenode$node_number
        echo "upgradeing $node_name"
        sudo cp $NodePath /var/safenode-manager/services/$node_name
        echo "cp $NodePath /var/safenode-manager/services/$node_name"
        node_details_store[$node_number]="$node_name,,$(/var/safenode-manager/services/$node_name/safenode -V | awk '{print $3}'),STOPPED"
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
        Remove=0
        LastNode="RemoveCounter$TotalNodes"
        LastNode="${!LastNode}"
        if (($(echo " $StoppedNodes > 0" | bc))) && (($(echo " $LastNode == 0" | bc))); then Remove=1; fi
        LoadAverage1=$(uptime | awk '{print $(NF-2)}' | awk '{print $(NF-1)}' FS=,)
        LoadAverage5=$(uptime | awk '{print $(NF-1)}' | awk '{print $(NF-1)}' FS=,)
        LoadAverage15=$(uptime | awk '{print $(NF-0)}' | awk '{print $(NF-1)}' FS=,)
        # load allow calc
        if (($(echo "$LoadAverage1 < $DesiredLoadAverage" | bc))) && (($(echo "$LoadAverage5 < $DesiredLoadAverage" | bc))) && (($(echo "$LoadAverage15 < $DesiredLoadAverage" | bc))); then LoadAllow=1; else LoadAllow=1; fi
        if (($(echo "$LoadAverage1 > $MaxLoadAverageAllowed" | bc))) && (($(echo "$LoadAverage5 > $MaxLoadAverageAllowed" | bc))) && (($(echo "$LoadAverage15 > $MaxLoadAverageAllowed" | bc))); then LoadNotAllow=1; else LoadNotAllow=1; fi
        UsedCpuPercent=$(vmstat 1 2 | awk 'END { print 100 - $15 }')
        FreeMemPercent=$(free | grep Mem | awk '{ printf("%.4f\n", $7/$2 * 100.0) }')
        FreeMemPercent=$(echo "100 - $FreeMemPercent" | bc)
        UsedHdPercent=$(df -hP /var | awk '{print $5}' | tail -1 | sed 's/%$//g')

        AllowCpu=$(echo "$UsedCpuPercent < $CpuLessThan" | bc)
        AllowMem=$(echo "$FreeMemPercent < $MemLessThan" | bc)
        AllowHD=$(echo "$UsedHdPercent < $HDLessThan" | bc)

}

PrintDetails() {
        echo "Used CPU percent $UsedCpuPercent%"
        echo "Used MEM percent $FreeMemPercent%"
        echo "Used HD percent $UsedHdPercent%" && echo

        echo "LoadAverage 1 $LoadAverage1"
        echo "LoadAverage 5 $LoadAverage5"
        echo "LoadAverage 15 $LoadAverage15" && echo

        echo "TotalNodes $TotalNodes"
        echo "RunningNodes $RunningNodes"
        echo "StoppedNodes $StoppedNodes" && echo

        echo "AddNewNode $AddNewNode"
        echo "NextNodeToStartOrAdd $NextNodeToSorA"
        echo "NextNodeStopOrRemove $NextNodeSorR" && echo

        echo "CpuCount $CpuCount"
        echo "BatchSize $BatchSize"
        echo "MaxLoadAverageAllowed $MaxLoadAverageAllowed"
        echo "DesiredLoadAverage $DesiredLoadAverage" && echo

        echo "Latest Ver $LatestNodeVer"
        echo "NodesLatestVersion $NodesLatestV"
        echo "NodesToUpgrade $NodesToUpgrade"
        echo "NextToUpgrade  $NextToUpgrade"
        echo "Upgrade $Upgrade Remove $Remove" && echo

        echo "Cpu $AllowCpu Mem $AllowMem HD $AllowHD LoadAllow $LoadAllow LoadNotAllow $LoadNotAllow"
        echo "DelayStart $DelayStart DelayUpgrade $DelayUpgrade DelayRemove $DelayRemove"
        echo "CounterStart $CounterStart CounterUpgrade $CounterUpgrade" && echo
        echo "$(</var/safenode-manager/counters)" && echo
}

UpGrade() {
        if (($(echo "$Upgrade == 1" | bc))); then
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

CheckSetUp
CalculateValues
IncrementCounters
PrintDetails
UpGrade
Removal

####################################################################################### logic for starting and stoping nodes
if [[ ! -f "/var/safenode-manager/config" ]] || [[ "$Action" == "4" ]]; then
        echo "Initiate Nuke" && echo
        TearDown
elif (($(echo $AllowCpu))) && (($(echo $AllowMem))) && (($(echo $AllowHD))) && (($(echo $LoadAllow))) || [[ "$Action" == "1" ]]; then
        echo "start node" && echo
        StartNode
elif (($(echo "$AllowCpu == 0" | bc))) || (($(echo "$AllowMem == 0" | bc))) || (($(echo "$AllowHD == 0" | bc))) || (($(echo "$LoadNotAllow == 0" | bc))) || [[ "$Action" == "2" ]]; then
        if (($(echo "$AllowHD == 0" | bc))); then
                RemoveNode $TotalNodes
                echo "Node $TotalNodes Removed due to hard drive space" && echo
        else
                echo "stop node" && echo
                StopNode
        fi
else
        echo "Node count Ok" && echo
fi
#############################################################################################################################

for num in $(echo "${!node_details_store[@]}" | tr ' ' '\n' | sort -n); do
        echo "${node_details_store[$num]}"
done

#save node details aray
declare -p node_details_store >/var/safenode-manager/NodeDetails
echo
