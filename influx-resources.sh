#!/bin/bash

#1

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
declare -A node_numbers
declare -A node_details_store

# Process nodes
for dir in "$base_dir"/*; do
    if [[ -f "$dir/safenode.pid" ]]; then
        dir_name=$(basename "$dir")
        dir_pid["$dir_name"]=$(cat "$dir/safenode.pid")
        node_number=${dir_name#safenode}
        node_numbers["$dir_name"]=$node_number
        node_details=$(jq '.nodes[] | select(.service_name == "'$dir_name'")' /var/safenode-manager/node_registry.json)

        # Skip if node status is ADDED
        if [[ $(jq -r .status <<< "$node_details") == "Added" ]]; then
            continue
        fi

        # Retrieve process information
        process_info=$(ps -o rss,%cpu -p "${dir_pid[$dir_name]}" | awk 'NR>1')
        if [[ -n "$process_info" ]]; then
        total_nodes_running=$((total_nodes_running + 1))
        status="TRUE"
        mem_used=$(echo "$process_info" | awk '{print $1/1024}')
        cpu_usage=$(echo "$process_info" | awk '{print $2}')
        else
        total_nodes_killed=$((total_nodes_killed + 1))
        status="FALSE"
        mem_used=0
        cpu_usage=0
        fi

        peer_id=$(jq -r .peer_id <<< "$node_details")
        node_version=$(jq -r .version <<< "$node_details")
        rewards_balance=$(safe wallet balance --peer-id /var/safenode-manager/services/safenode$node_number | awk 'NR==3{print $7}')
        total_rewards_balance=$(echo "scale=10; $total_rewards_balance + $rewards_balance" | bc -l)

        # Format for InfluxDB
        node_details_store[$node_number]="nodes,id=$dir_name,peer_id=$peer_id status=$status,pid=${dir_pid[$dir_name]}i,version=\"$node_version\",records=$(find "$dir/record_store" -type f | wc -l)i,rewards=$rewards_balance,cpu=$cpu_usage,mem=$mem_used $influx_time"
        #sleep to slow script down to spread out cpu spike
        sleep 4
    fi
done


# Latency
latency=$(ping -c 4 8.8.8.8 | tail -1| awk '{print $4}' | cut -d '/' -f 2)


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


# calculate total storage of the node services folder
total_disk=$(echo "scale=0;("$(du -s "$base_dir" | cut -f1)")/1024" | bc)

fi

####################################################################
#### test if grafana is installed if so then calculate network size
####################################################################
if echo "$(docker ps)" | grep -q "grafana/grafana-enterprise"; then

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
    networkSize="nodes_totals network_size=0"
else
    sum=0
    for total in "${total_nodes_list[@]}"; do
        sum=$((sum + total))
    done
    average=$((sum / ${#total_nodes_list[@]}))
    networkSize="nodes_totals network_size="$average"i"
fi
fi


# sleep till all nodes have systems have finished prosessing

while (( $(("$time_min" + "5")) > $(date +"%M"))); do
sleep 10
done


# Sort
for num in $(echo "${!node_details_store[@]}" | tr ' ' '\n' | sort -n); do
    echo "${node_details_store[$num]}"
done

# Output
echo "nodes_totals rewards=$total_rewards_balance,nodes_running="$total_nodes_running"i,nodes_killed="$total_nodes_killed"i $influx_time"
echo "nodes_totals total_disk="$total_disk"i $influx_time"
echo "nodes_coingecko,curency=gbp exchange_rate=$exchange_rate_gbp,marketcap=$market_cap_gbp,earnings=$earnings_gbp  $influx_time"
echo "nodes_coingecko,curency=usd exchange_rate=$exchange_rate_usd,marketcap=$market_cap_usd,earnings=$earnings_usd  $influx_time"
echo "$networkSize"
echo "nodes latency=$latency $influx_time"
