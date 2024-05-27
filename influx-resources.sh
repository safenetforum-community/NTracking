#!/bin/bash

#16/05/2024 19:12

# if cpu over 90% exit monitoring script
cpu=$(awk '{u=$2+$4; t=$2+$4+$5; if (NR==1){u1=u; t1=t;} else print ($2+$4-u1) * 100 / (t-t1) ; }' \
<(grep 'cpu ' /proc/stat) <(sleep 1;grep 'cpu ' /proc/stat))
if [ 1 -eq "$(echo "$cpu > 95.0" | bc)" ]; then exit 0; fi

# Environment setup
export PATH=$PATH:$HOME/.local/bin
base_dir="/var/safenode-manager/services"

# Current time for influx database entries
influx_time="$(date +%s%N | awk '{printf "%d0000000000\n", $0 / 10000000000}')"
time_min=$(date +"%M")

# Counters
total_rewards_balance=0
total_nodes_running=0
total_nodes_killed=0

# Arrays
declare -A dir_pid
declare -A dir_peer_ids
declare -A node_numbers
declare -A node_details_store

# Fetch node overview from node-manager
sudo env "PATH=$PATH" safenode-manager status --details > /tmp/influx-resources/nodes_overview
if [ $? -ne 0 ]; then
    echo "Failed to get node overview from safenode-manager."
    exit 1
fi

# Process nodes
for dir in "$base_dir"/*; do
    if [[ -f "$dir/safenode.pid" ]]; then
        dir_name=$(basename "$dir")
        dir_pid["$dir_name"]=$(cat "$dir/safenode.pid")
        node_number=${dir_name#safenode}
        node_numbers["$dir_name"]=$node_number
        node_details=$(grep -A 12 "$dir_name - " /tmp/influx-resources/nodes_overview)

        # Skip if node status is ADDED
        if [[ $node_details == *"- ADDED"* ]]; then
            continue
        fi

        if [[ $node_details == *"- RUNNING"* ]]; then
            total_nodes_running=$((total_nodes_running + 1))
            status=TRUE
        else
            total_nodes_killed=$((total_nodes_killed + 1))
            status=FALSE
        fi

        peer_id=$(echo "$node_details" | grep "Peer ID:" | awk '{print $3}')
        dir_peer_ids["$dir_name"]="$peer_id"
        node_version=$(echo "$node_details" | grep "Version:" | awk '{print $2}')
        rewards_balance=$(echo "$node_details" | grep "Reward balance:" | awk '{print $3}')
        total_rewards_balance=$(echo "scale=10; $total_rewards_balance + $rewards_balance" | bc -l)

        # Format for InfluxDB
        node_details_store[$node_number]="nodes,id=$dir_name,peer_id=$peer_id status=$status,pid=${dir_pid[$dir_name]}i,version=\"$node_version\",records=$(find "$dir/record_store" -type f | wc -l)i,rewards=$rewards_balance $influx_time"
    fi
done

# Sort
for num in $(echo "${!node_details_store[@]}" | tr ' ' '\n' | sort -n); do
    echo "${node_details_store[$num]}"
done

# Output
echo "nodes_totals rewards=$total_rewards_balance,nodes_running="$total_nodes_running"i,nodes_killed="$total_nodes_killed"i $influx_time"


# Latency
latency=$(ping -c 4 8.8.8.8 | tail -1| awk '{print $4}' | cut -d '/' -f 2)
echo "nodes latency=$latency $influx_time"

######### error logging
# (?-is)^.*IncomingConnectionError.*ConnectionClose.*\R?  #note to self for sercing for strings

#grep a errors from all node logs from last 5 min to a combined file
grep "$(date "+%Y-%m-%dT%H:%M" -d '5 min ago')" /var/log/safenode/safenode*/safenode.log | grep "error" > /tmp/influx-resources/combined_logs

#grep for errors wit two sting patterns
OutgoingConnectionError_HandshakeTimedOut=$(grep -E 'OutgoingConnectionError|HandshakeTimedOut' /tmp/influx-resources/combined_logs  | wc -l)
OutgoingConnectionError_ResourceLimitExceeded=$(grep -E 'OutgoingConnectionError|ResourceLimitExceeded' /tmp/influx-resources/combined_logs  | wc -l)
OutgoingConnectionError_NoReservation=$(grep -E 'OutgoingConnectionError|NoReservation' /tmp/influx-resources/combined_logs  | wc -l)
IncomingConnectionError_HandshakeTimedOut=$(grep -E 'IncomingConnectionError|HandshakeTimedOut' /tmp/influx-resources/combined_logs  | wc -l)
IncomingConnectionError_ConnectionClose=$(grep -E 'IncomingConnectionError|ConnectionClose' /tmp/influx-resources/combined_logs  | wc -l)
OutgoingTransport_Canceled=$(grep -E 'OutgoingTransport|Canceled' /tmp/influx-resources/combined_logs  | wc -l)
OutgoingTransport_NoReservation=$(grep -E 'OutgoingTransport|NoReservation' /tmp/influx-resources/combined_logs  | wc -l)
OutgoingTransport_ResourceLimitExceeded=$(grep -E 'OutgoingTransport|ResourceLimitExceeded' /tmp/influx-resources/combined_logs  | wc -l)
OutgoingTransport_HandshakeTimedOut=$(grep -E 'OutgoingTransport|HandshakeTimedOut' /tmp/influx-resources/combined_logs  | wc -l)
Problematic_HandshakeTimedOut=$(grep -E 'Problematic|HandshakeTimedOut' /tmp/influx-resources/combined_logs  | wc -l)

Total_Errors=$(($OutgoingConnectionError_HandshakeTimedOut + $OutgoingConnectionError_ResourceLimitExceeded + $OutgoingConnectionError_NoReservation + $IncomingConnectionError_HandshakeTimedOut + $IncomingConnectionError_ConnectionClose + $OutgoingTransport_Canceled + $OutgoingTransport_NoReservation + $OutgoingTransport_ResourceLimitExceeded + $OutgoingTransport_HandshakeTimedOut + $Problematic_HandshakeTimedOut))
Average_Errors=$(($Total_Errors / $total_nodes_running))

#print to influx
echo "nodes_errors \
OutgoingConnectionError_HandshakeTimedOut="$OutgoingConnectionError_HandshakeTimedOut"i,\
OutgoingConnectionError_ResourceLimitExceeded="$OutgoingConnectionError_ResourceLimitExceeded"i,\
OutgoingConnectionError_NoReservation="$OutgoingConnectionError_NoReservation"i,\
IncomingConnectionError_HandshakeTimedOut="$IncomingConnectionError_HandshakeTimedOut"i,\
IncomingConnectionError_ConnectionClose="$IncomingConnectionError_ConnectionClose"i,\
OutgoingTransport_Canceled="$OutgoingTransport_Canceled"i,\
OutgoingTransport_NoReservation="$OutgoingTransport_NoReservation"i,\
OutgoingTransport_ResourceLimitExceeded="$OutgoingTransport_ResourceLimitExceeded"i,\
OutgoingTransport_HandshakeTimedOut="$OutgoingTransport_HandshakeTimedOut"i,\
Problematic_HandshakeTimedOut="$Problematic_HandshakeTimedOut"i,\
Average_Errors=$Average_Errors \
$influx_time"

##############################################################################################
# coin gecko gets upset with to many requests this atempts to get the exchange every 15 min
# https://www.coingecko.com/api/documentation
##############################################################################################
if (( $time_min == 0 )) || (( $time_min == 15 )) || (( $time_min == 30 )) || (( $time_min == 45 ))
then
coingecko=$(curl -s -X 'GET' 'https://api.coingecko.com/api/v3/simple/price?ids=maidsafecoin&vs_currencies=gbp%2Cusd&include_market_cap=true' -H 'accept: application/json')
exchange_rate_gbp=$(awk -F'[:,]' '{print $3}' <<< $coingecko)
market_cap_gbp=$(awk -F'[:,]' '{print $5}' <<< $coingecko)
exchange_rate_usd=$(awk -F'[:,]' '{print $7}' <<< $coingecko)
market_cap_usd=$(awk -F'[:}]' '{print $6}' <<< $coingecko)

# calculate earnings in usd & gbp
earnings_gbp=`echo $total_rewards_balance*$exchange_rate_gbp | bc`
earnings_usd=`echo $total_rewards_balance*$exchange_rate_usd | bc`


echo "nodes_coingecko,curency=gbp exchange_rate=$exchange_rate_gbp,marketcap=$market_cap_gbp,earnings=$earnings_gbp  $influx_time"
echo "nodes_coingecko,curency=usd exchange_rate=$exchange_rate_usd,marketcap=$market_cap_usd,earnings=$earnings_usd  $influx_time"

# calculate total storage of the node services folder
total_disk=$(echo "scale=0;("$(du -s "$base_dir" | cut -f1)")/1024" | bc)
echo "nodes_totals total_disk="$total_disk"i $influx_time"
fi

####################################################################
#### test if grafana is installed if so then calculate network size
####################################################################
if echo "$(docker ps)" | grep -q "grafana/grafana-enterprise"; then
#!/bin/bash

# Define the base path where the node directories are located
node_base_path="/var/log/safenode/"

# Check if the node base path exists
if [[ ! -d "$node_base_path" ]]; then
    echo "Node base path does not exist: $node_base_path"
    exit 1
fi

# Function to calculate total nodes from kBucket data
calculate_total_nodes() {
    kbucket_data="$1"
    # Remove all non-numeric characters except commas and numbers to simplify processing
    cleaned_data=$(echo "$kbucket_data" | tr -d '[]() ' | tr ',' ' ')

    # Initialize counters
    nodes_in_non_full_buckets=0
    num_of_full_buckets=0

    # Parse and process each bucket entry
    IFS=' ' read -ra data <<< "$cleaned_data"
    for (( i=0; i<${#data[@]}; i+=3 )); do
        depth="${data[i]}"
        nodes="${data[i+1]}"
        capacity="${data[i+2]}"

        # Check if the bucket has exactly 20 nodes to be considered as full
        if (( nodes == 20 )); then
            (( num_of_full_buckets++ ))
        else
            (( nodes_in_non_full_buckets += nodes ))
        fi
    done

    # Calculate total nodes
    total_nodes=$(( (nodes_in_non_full_buckets + 1) * (2 ** num_of_full_buckets) ))
    echo "$total_nodes"
}

# Array to store total nodes from each node directory
total_nodes_list=()

# Iterate through each node directory within the base path
for node_dir in "$node_base_path"/*; do
    if [[ -d "$node_dir" ]]; then
        #echo "Processing node directory: $node_dir"

        # Define the path to the safenode.log file
        log_path="$node_dir/safenode.log"

        # Check if the log file exists
        if [[ -f "$log_path" ]]; then
            # Extract the latest kBucket data from the log file
            latest_kbucket=$(grep "kBucketTable" "$log_path" | tail -1 | sed -E 's/.*kBucketTable.*\[(.*)\].*/\1/')

            # Check if kBucket data was found
            if [[ -n "$latest_kbucket" ]]; then
                #echo "Latest kBucket for $node_dir: $latest_kbucket"
                # Calculate the total nodes based on the latest kBucket data
                total_nodes=$(calculate_total_nodes "$latest_kbucket")
                #echo "Total nodes calculated for $node_dir: $total_nodes"
                # Append total nodes to list
                total_nodes_list+=("$total_nodes")
            else
                echo "No kBucket data found in $log_path"
            fi
        else
            echo "Log file not found in $node_dir"
        fi
    fi
done

# Calculate the average of total nodes across all safenodes
if [ ${#total_nodes_list[@]} -eq 0 ]; then
    echo "nodes_totals network_size=0"
else
    sum=0
    for total in "${total_nodes_list[@]}"; do
        sum=$((sum + total))
    done
    average=$((sum / ${#total_nodes_list[@]}))
    echo "nodes_totals network_size="$average"i"
fi
fi
