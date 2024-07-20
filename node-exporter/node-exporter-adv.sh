#!/bin/bash
# Copyright 2024 - Jadkins-Me
#
# This Code/Software is licensed to you under GNU AFFERO GENERAL PUBLIC LICENSE (GPL), Version 3
# Unless required by applicable law or agreed to in writing, the Code/Software distributed
# under the GPL Licence is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied. Please review the Licences for the specific language governing
# permissions and limitations relating to use of the Code/Software.

# PREQ : pre-req.sh to install dependency
set -euo pipefail

# // User Modifiable Options
process_name="safenode"                     #name of node executable
node_registry="node_registry.json"          #file updated by node-launchpad and safenode-manager
service_scope="undefined"                   #user=user service under /home/username/.config, system=under /var
service_user="root"                         #username running process_name
base_dir="undefined"                        #location of binarys TODO: need to cope with user defined paths outside path

# // NOTE : Changing things below this line might break functionality

max_para="4"                                #Maximum Parallel processes
min_para="1"                                #Minimum Parallel processes
delta_para="2"                              #Delta per CPU core for Parallel processes

# // Packages needed by script, should be installed by PREQ
required_tools=("parallel" "jq" "curl" "awk" "ps" "grep" "head" "sort")

# Environment setup
export PATH=$PATH:$HOME/.local/bin

# Loop through packages and check if it is installed
for tool in "${required_tools[@]}"; do
    if ! command -v "$tool" &> /dev/null; then
        echo "Error: '$tool' is not installed. Please install it and try again."
        exit 1
    fi
done

# write our PID to file, and handle a hung process running...
pid_file="$HOME/.influx-node-adv.pid"
max_stale_seconds=3600                                          #How long we allow this process to run before force close
trap 'rm -- "$pid_file" > /dev/null 2>&1' EXIT                  #Ensure we delete our PID file on EXIT or Kill

if [ -f "$pid_file" ]; then
    pid="$(cat "$pid_file")"
    age_in_seconds="$(($(date +%s) - $(date -r "$pid_file" +%s)))"

    if ps "$pid" >/dev/null; then
        if [ "$age_in_seconds" -ge "$max_stale_seconds" ]; then
            kill "$pid"
        else
            exit 1
        fi
    fi
fi

# Save the current PID to the file
echo "$$" > "$pid_file"

# Check context in which we are running, userservice or systemservice
service_scope=$(ps aux | grep -v grep | grep "safenode" | awk '{print $2}' | sort -u | head -n 1 | while read -r pid; do ps -o user= -p "$pid"; done)
if [ "$service_scope" = "root" ]; then
    # root, and service_scope is system
    base_dir="/var/safenode-manager/services/"
    service_scope="system:root"
else
    base_dir="/home/$service_scope/.local/share/safe/node/"      #TODO: Assumption home directory is under /home
    service_scope="user:$service_scope"
fi

#Find node_registry and pass it
json_file="$base_dir""$node_registry"
if [ ! -f $json_file ]; then
    #file not found, so exit #TODO: search for file in known locations maybe ?
    exit 1
fi

# Current time for influx database entries for this script run - needed for output to group results
influx_time="$(date +%s%N | awk '{printf "%d0000000000\n", $0 / 10000000000}')"
export influx_time

# Function to process node data
process_node() {
    local i="$1"
    # Pass node data

    # Parse the JSON string into a dictionary
    json_dict=$(echo "$i" | jq -r 'to_entries | map("\(.key)=\(.value)") | .[]')

    # Initialize variables with default value
    auto_restart="false"                #Will service start automatically after reboot
    metrics_port=0                      #Metric endpoint /metrics
    owner=""                            #Rewards discord id
    node_port=0                         #Port being used by node for UDP connections
    peer_id=""                          #XOR address of node
    service_name=""                     #Service name
    status=""                           #Service Read / Running / Stopped
    upnp="false"                        #True if UPNP in use
    user_mode="false"                   #True if the service is running as user instead of root
    version=""                          #Node version
    home_network="false"                #True is node running in home_network mode i.e no port forward and relay nodes in use

    # Update variables with values from the JSON dictionary
    eval "$json_dict"

    #Process Network Type
    if [ "$upnp" = "true" ]; then
        network_type="upnp"
    else
        if [ "$home_network" = "true" ]; then
            network_type="relay"
        else
            network_type="forward"
        fi
    fi

    #If Metrics Enabled, Call extended /Metrics API
    if [ "$status" = "Running" ]; then
        if [ "$metrics_port" != "0" ]; then
            node_details="$(curl -s 127.0.0.1:$metrics_port/metrics)"
            #handle metrics endpoint down
            mcurl=$(( $? != 0 ))
            #process variables as we handle null
            peer_count=$(echo "$node_details" | grep -oP '(?<=sn_networking_connected_peers )\d+' || echo 0 )
            peer_route=$(echo "$node_details" | grep -oP '(?<=sn_networking_peers_in_routing_table )\d+' || echo 0 )
            rewards_balance=$(echo "$node_details" | grep -oP '(?<=sn_node_current_reward_wallet_balance )\d+' || echo 0 )
            rewards_forward=$(echo "$node_details" | grep -oP '(?<=sn_node_total_forwarded_rewards )\d+' || echo 0 )
            mem_used=$(echo "$node_details" | grep -oP '(?<=sn_networking_process_memory_used_mb )\d+' || echo 0 )
            cpu_usage=$(echo "$node_details" | grep -oP '(?<=sn_networking_process_cpu_usage_percentage )\d+' || echo 0 )
            records=$(echo "$node_details" | grep -oP '(?<=sn_networking_records_stored )\d+' || echo 0 )
            network_size=$(echo "$node_details" | grep -oP '(?<=sn_networking_estimated_network_size )\d+' || echo 0 )
            node_uptime=$(echo "$node_details" | grep -oP '(?<=sn_node_uptime )\d+' || echo 0 )
            store_cost=$(echo "$node_details" | grep -oP '(?<=sn_networking_store_cost )\d+' || echo 0 )
            node_put_chunk=$(echo "$node_details" | grep -oP '(?<=sn_node_put_record_ok_total{record_type="Chunk"} )\d+' || echo 0 )
            node_put_spend=$(echo "$node_details" | grep -oP '(?<=sn_node_put_record_ok_total{record_type="Spend"} )\d+' || echo 0 )
            node_put_error=$(echo "$node_details" | grep -oP '(?<=sn_node_put_record_err_total )\d+' || echo 0 )
        fi
    fi

    # Format for InfluxDB
    echo "nodes_adv,id=$service_name,peerid=$peer_id autorestart=$auto_restart,status=\"${status,,}\",owner=\"$owner\",networktype=\"$network_type\",mcurl=\"${mcurl,,}\",metrics="$metrics_port"u,nodeport="$node_port"u,usermode=$user_mode,version=\"$version\",records="$records"u,rewards="$rewards_balance"i,forward="$rewards_forward"i,cpu="$cpu_usage"u,mem="$mem_used"u,peers="$peer_count"u,networksize="$network_size"u,uptime="$node_uptime"i,storecost="$store_cost"i,peerroute="$peer_route"u,nodepc="$node_put_chunk"u,nodeps="$node_put_spend"u,nodepe="$node_put_error"u $influx_time"

}

# Export the function as we need to access from other child processes
export -f process_node

# Detect the number of CPU cores, and set thread count
cores=$(nproc)
threads=$(($cores * $delta_para))
if [ "$threads" -gt $((max_para * delta_para)) ]; then
    threads=$((max_para * delta_para))
elif [ "$threads" -lt $((min_para * delta_para)) ]; then
    threads=$((min_para * delta_para))
fi

# Run the loop in parallel
jq -c '.nodes[]' "$json_file" | parallel -j $threads process_node

##############################################################################################
# coin gecko gets upset with to many requests this atempts to get the exchange every 15 min
# https://www.coingecko.com/api/documentation
##############################################################################################
coingecko=$(curl -s -X 'GET' 'https://api.coingecko.com/api/v3/simple/price?ids=maidsafecoin&vs_currencies=gbp%2Cusd&include_market_cap=true' -H 'accept: application/json')
exchange_rate_gbp=$(awk -F'[:,]' '{print $3}' <<< $coingecko)
market_cap_gbp=$(awk -F'[:,]' '{print $5}' <<< $coingecko)
exchange_rate_usd=$(awk -F'[:,]' '{print $7}' <<< $coingecko)
market_cap_usd=$(awk -F'[:}]' '{print $6}' <<< $coingecko)

# calculate total storage of the node services folder
total_disk=$(echo "scale=0;("$(du -s "$base_dir" | cut -f1)")/1024" | bc)

# Output
echo "nodes_totals total_disk="$total_disk"i $influx_time"
echo "nodes_xchg,curency=gbp exchange_rate=$exchange_rate_gbp,marketcap=$market_cap_gbp  $influx_time"
echo "nodes_xchg,curency=usd exchange_rate=$exchange_rate_usd,marketcap=$market_cap_usd  $influx_time"