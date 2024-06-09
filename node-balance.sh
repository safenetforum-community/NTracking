#!/bin/bash

# Environment setup
export PATH=$PATH:$HOME/.local/bin
base_dir="/var/safenode-manager/services"

#exit if script is already running
if test -f /tmp/influx-resources/nodemanager_output.lock; then
  exit 0
fi


total_nodes_running=0
total_nodes_Added=0
total_nodes_Stopped=0

TargetLoadAverage=13
MaxLoadAverage=20

LoadAverage1=$(uptime | awk '{print $(NF-2)}' | awk '{print $(NF-1)}' FS=,)
LoadAverage5=$(uptime | awk '{print $(NF-1)}'  | awk '{print $(NF-1)}' FS=,)
LoadAverage15=$(uptime | awk '{print $(NF-0)}' | awk '{print $(NF-1)}' FS=,)

echo "LoadAverage1  $LoadAverage1"
echo "LoadAverage5  $LoadAverage5"
echo "LoadAverage15  $LoadAverage15"

#compare load averages to determin if load system load is in an upward trend
if (($(echo "$LoadAverage1 < $LoadAverage5" | bc ))) && (($(echo "$LoadAverage5 < $LoadAverage15" | bc ))); then
echo "System system load droping"
LoadTrend=0
else
echo "System system load rising"
LoadTrend=1
fi

# Process nodes
for dir in "$base_dir"/*; do
    if [[ -f "$dir/safenode.pid" ]]; then
        dir_name=$(basename "$dir")
        node_number=${dir_name#safenode}
        node_details=$(jq '.nodes[] | select(.service_name == "'$dir_name'")' /var/safenode-manager/node_registry.json)

        # Skip if node status is ADDED
        if [[ $(jq -r .status <<< "$node_details") == "Added" ]]; then
            total_nodes_Added=$((total_nodes_Added + 1))
        elif [[ $(jq -r .status <<< "$node_details") == "Running" ]]; then
			total_nodes_running=$((total_nodes_running + 1))
        elif [[ $(jq -r .status <<< "$node_details") == "Stopped" ]]; then
			total_nodes_Stopped=$((total_nodes_Stopped + 1))       
		fi
    fi
sleep 4
done

echo
echo "nodes Added $total_nodes_Added"
echo "node Running $total_nodes_running"
echo "total nodes Stopped $total_nodes_Stopped"
echo

#echo $TargetLoadAverage
#echo $LoadAverage15
#echo
#echo $(echo "$LoadAverage15 < $TargetLoadAverage" | bc)
#echo $(echo "$total_nodes_Stopped == 0" | bc)

#exit if load average is bellow target valaue and all nodes are running
if (($(echo "$LoadAverage15 < $TargetLoadAverage" | bc))) && (($(echo "$total_nodes_Stopped == 0" | bc))); then
echo "exit if load average is bellow target valaue and all nodes are running"


#if load is lower than target value and there are stoped nodes start a node
elif (($(echo "$LoadAverage15 < $TargetLoadAverage" | bc))) && (($(echo "$total_nodes_Stopped > 0" | bc))); then
NodeToStart=$((total_nodes_running + 1))
echo "load is lower than target value and there are stoped nodes start safenode$NodeToStart"
sudo env "PATH=$PATH" safenode-manager start --service-name safenode$NodeToStart


#if load is higher than Max Load Average and all nodes have already been started stop all nodes a and restart one by one
elif (($(echo "$LoadAverage15 > $MaxLoadAverage" | bc))) && (($(echo "$total_nodes_Added == 0" | bc))) && (($(echo "$LoadTrend == 1" | bc))); then
touch /tmp/influx-resources/nodemanager_output.lock

       sudo pkill -e safe
       sudo systemctl stop safenode*

echo
sleep 180
echo "System cool down completed starting $total_nodes_running nodes"
echo

TotalNodes=$total_nodes_running
NumberToStart=$total_nodes_running
for (( i = 0; i < $NumberToStart; i))
do
       NodesToStart=$(echo "$TotalNodes - $NumberToStart + 1" | bc)
       echo Starting safenode$NodesToStart
       sudo systemctl start safenode$NodesToStart
       NumberToStart=$(echo "$NumberToStart - 1" | bc)
       sleep 180
done

sudo env "PATH=$PATH" safenode-manager status
rm /tmp/influx-resources/nodemanager_output.lock
sleep 1800

#if load is higher than target value and all nodes have already been started stop a node
elif (($(echo "$LoadAverage15 > $TargetLoadAverage" | bc))) && (($(echo "$total_nodes_Added == 0" | bc))); then
NodeToStop=$total_nodes_running
echo "load is higher than target value and all nodes have already been started stop safenode$total_nodes_running"
sudo env "PATH=$PATH" safenode-manager stop --service-name safenode$NodeToStop

fi
