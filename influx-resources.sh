#!/bin/bash

# sudo rm -f /usr/bin/influx-resources.sh* && sudo wget -P /usr/bin https://raw.githubusercontent.com/safenetforum-community/NTracking/main/influx-resources.sh && sudo chmod u+x /usr/bin/influx-resources.sh


MetricsPortFirst=13001

# Environment  setup
export PATH=$PATH:$HOME/.local/bin
base_dir="/var/safenode-manager/services"

# Current time for influx database entries
influx_time="$(date +%s%N | awk '{printf "%d0000000000\n", $0 / 10000000000}')"
time_min=$(date +"%M")

# Counter's
total_rewards_balance=0
total_nodes_running=0
total_nodes_killed=0
total_network_size=0

# Arrays
declare -A dir_pid
declare -A node_numbers
declare -A node_details_str

declare -A node_details_store
. /var/safenode-manager/NodeDetails >/dev/null 2>&1

# count node foldrs
NumberOfNodes=$(ls $base_dir | wc -l)

# drop node first port by 1 as i had to be 1 in the for loop for correct node names
MetricsPortFirst=$(($MetricsPortFirst - 1))

#Aceptable Shunn value
ShunnedValue=25

# Process nodes
for ((i = 1; i <= $NumberOfNodes; i++)); do
    node_number=$(seq -f "%03g" $i $i)
    node_name=safenode$node_number
    node_details="$(curl -s 127.0.0.1:$(($MetricsPortFirst + $i))/metrics)"

    if [[ -n "$node_details" ]]; then
        total_nodes_running=$(($total_nodes_running + 1))
        status="TRUE"
        mem_used=$(echo "$node_details" | grep sn_networking_process_memory_used_mb | awk 'NR==3 {print $2}')
        cpu_usage=$(echo "$node_details" | grep sn_networking_process_cpu_usage_percentage | awk 'NR==3 {print $2}')
        records=$(echo "$node_details" | grep sn_networking_records_stored | awk 'NR==3 {print $2}')
        network_size=$(echo "$node_details" | grep sn_networking_estimated_network_size | awk 'NR==3 {print $2}')
        shunned_count=$(echo "$node_details" | grep sn_networking_shunned_count_total | awk 'NR==1 {print $2}')
        rewards_balance=$(echo "$node_details" | grep sn_node_total_forwarded_rewards | awk 'NR==3 {print $2}')
        connected_peers=$(echo "$node_details" | grep sn_networking_peers_in_routing_table | awk 'NR==3 {print $2}')
        store_cost=$(echo "$node_details" | grep sn_networking_store_cost | awk 'NR==3 {print $2}')
        gets=$(echo "$node_details" | grep libp2p_kad_query_result_get_record_ok_total | awk '{print $2}')
        puts=$(echo "$node_details" | grep sn_node_put_record_ok_total | awk '{print $2}' | paste -sd+ | bc)

        if [[ -f "/var/safenode-manager/NodeDetails" ]]; then
            # for anm
            PeerId="\"$(echo "${node_details_store[$node_number]}" | awk -F',' '{print $2}')\""
            NodeVersion="\"$(echo "${node_details_store[$node_number]}" | awk -F',' '{print $3}')\""

            # shunn gun
            if (($(echo "$shunned_count > $ShunnedValue" | bc))); then
                Shunngun=1
                ShunnedNode=$i
                ShunnedValue=$shunned_count
            fi

        else
            # for safe node manager service
            node_metadata="$(curl -s 127.0.0.1:$(($MetricsPortFirst + $i))/metadata)"
            PeerId="\"$(echo "$node_metadata" | grep sn_networking_peer_id | awk 'NR==3 {print $1}' | cut -d'"' -f 2)\""
            NodeVersion="\"$(echo "$node_metadata" | grep sn_node_safenode_version | awk 'NR==3 {print $1}' | cut -d'"' -f 2)\""
        fi

    else
        total_nodes_killed=$(($total_nodes_killed + 1))
        status="FALSE"
        mem_used=0
        cpu_usage=0
        records=0
        network_size=0
        shunned_count=0
        rewards_balance=0
        connected_peers=0
        store_cost=0
        gets=0
        puts=0

        if [[ -f "/var/safenode-manager/NodeDetails" ]]; then
            # for anm
            PeerId="\"$(echo "${node_details_store[$node_number]}" | awk -F',' '{print $2}')\""
            NodeVersion="\"$(echo "${node_details_store[$node_number]}" | awk -F',' '{print $3}')\""
        else
            # for safe node manager service
            PeerId="\"NotReachableStoppedNode\""
            NodeVersion="\"$(/var/safenode-manager/services/safenode$i/safenode -V | awk '{print $3}')\""
        fi
    fi

    # save Shunngun target
    if (($(echo "$Shunngun == 1" | bc))); then
        echo "MaxShunnedNode=$ShunnedNode" >/var/safenode-manager/MaxShunnedNode
        echo "ShunnedValue=$ShunnedValue" >>/var/safenode-manager/MaxShunnedNode
    fi

    # Format for InfluxDB
    node_details_str[$i]="nodes,id=$node_name PeerId=$PeerId,status=$status,records="$records"i,connected_peers="$connected_peers"i,rewards=$rewards_balance,store_cost="$store_cost"i,cpu="$cpu_usage"i,mem="$mem_used"i,puts="$puts"i,gets="$gets"i,version=$NodeVersion,networ_size="$network_size"i,shunned_count="$shunned_count"i $influx_time"
    #sleep to slow script down to spread out cpu spike

    rewards_balance=$(echo "scale=10; $rewards_balance / 1000000000" | bc)
    total_rewards_balance=$(echo "scale=10; $total_rewards_balance + $rewards_balance" | bc -l)
    total_network_size=$(($total_network_size + $network_size))

done

network_size=$(echo "$total_network_size / $total_nodes_running" | bc)

# Latency
latency=$(ping -c 4 8.8.8.8 | tail -1 | awk '{print $4}' | cut -d '/' -f 2)

##############################################################################################
# coin gecko gets upset with to many requests this atempts to get the exchange every 15 min
# https://www.coingecko.com/api/documentation
##############################################################################################
coingecko=$(curl -s -X 'GET' 'https://api.coingecko.com/api/v3/simple/price?ids=maidsafecoin&vs_currencies=gbp%2Cusd&include_market_cap=true' -H 'accept: application/json')
exchange_rate_gbp=$(awk -F'[:,]' '{print $3}' <<<$coingecko)
market_cap_gbp=$(awk -F'[:,]' '{print $5}' <<<$coingecko)
exchange_rate_usd=$(awk -F'[:,]' '{print $7}' <<<$coingecko)
market_cap_usd=$(awk -F'[:}]' '{print $6}' <<<$coingecko)

# calculate earnings in usd & gbp
earnings_gbp=$(echo $total_rewards_balance*$exchange_rate_gbp | bc)
earnings_usd=$(echo $total_rewards_balance*$exchange_rate_usd | bc)

# calculate total storage of the node services folder
total_disk=$(echo "scale=0;("$(du -s "$base_dir" | cut -f1)")/1024" | bc)

# sleep till all nodes have systems have finished prosessing

while (($(("$time_min" + "5")) > $(date +"%M"))); do
    sleep 10
done

# Output

# Sort
for num in $(echo "${!node_details_str[@]}" | tr ' ' '\n' | sort -n); do
    echo "${node_details_str[$num]}"
done

echo "nodes_totals rewards=$total_rewards_balance,nodes_running="$total_nodes_running"i,nodes_killed="$total_nodes_killed"i $influx_time"
echo "nodes_totals total_disk="$total_disk"i $influx_time"
echo "nodes_coingecko,curency=gbp exchange_rate=$exchange_rate_gbp,marketcap=$market_cap_gbp,earnings=$earnings_gbp  $influx_time"
echo "nodes_coingecko,curency=usd exchange_rate=$exchange_rate_usd,marketcap=$market_cap_usd,earnings=$earnings_usd  $influx_time"
echo "nodes_network size="$network_size"i $influx_time"
echo "nodes latency=$latency $influx_time"
