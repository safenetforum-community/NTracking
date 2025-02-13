#!/bin/bash

# edit this to your public wallet address only requiered on one system running nodes
WalletAddress=YourWalletAddress

#  sudo rm -f /usr/bin/influx-resources.sh* && sudo wget -P /usr/bin https://raw.githubusercontent.com/safenetforum-community/NTracking/main/influx-resources.sh && sudo chmod u+x /usr/bin/influx-resources.sh

MetricsPortFirst=13001

# Environment  setup
export PATH=$PATH:$HOME/.local/bin:$HOME/.cargo/bin/cargo
base_dir="/var/antctl/services"

#. $HOME/.local/share/anm-wallet

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
. /var/antctl/NodeDetails >/dev/null 2>&1

# count node foldrs
NumberOfNodes=$(ls $base_dir | wc -l)

# drop node first port by 1 as i had to be 1 in the for loop for correct node names
MetricsPortFirst=$(($MetricsPortFirst - 1))

#Aceptable Shunn value
ShunnedValue=15

# Process nodes
for ((i = 1; i <= $NumberOfNodes; i++)); do
    node_number=$(seq -f "%03g" $i $i)
    node_name=antnode$node_number
    node_details="$(curl -s 127.0.0.1:$(($MetricsPortFirst + $i))/metrics)"
    node_metadata="$(curl -s 127.0.0.1:$(($MetricsPortFirst + $i))/metadata)"

    if [[ -n "$node_details" ]]; then
        total_nodes_running=$(($total_nodes_running + 1))
        status="\"Running\""
        gets=$(echo "$node_details" | grep libp2p_kad_query_result_get_record_ok_total | awk '{print $2}')
        puts=$(echo "$node_details" | grep ant_node_put_record_ok_total | awk '{print $2}' | paste -sd+ | bc)
        up_time=$(echo "$node_details" | grep ant_node_uptime | awk 'NR==3 {print $2}')
        rewards_balance=$(echo "$node_details" | grep ant_node_current_reward_wallet_balance | awk 'NR==3 {print $2}')
        # convert rewars to ANT from attos
        rewards_balance=$(echo "scale=18; $rewards_balance / 1000000000000000000" | bc)
        records=$(echo "$node_details" | grep ant_networking_records_stored | awk 'NR==3 {print $2}')
        connected_peers=$(echo "$node_details" | grep ant_networking_connected_peers | awk 'NR==3 {print $2}')
        network_size=$(echo "$node_details" | grep ant_networking_estimated_network_size | awk 'NR==3 {print $2}')
        open_connections=$(echo "$node_details" | grep ant_networking_open_connections | awk 'NR==3 {print $2}')
        total_peers=$(echo "$node_details" | grep ant_networking_peers_in_routing_table | awk 'NR==3 {print $2}')
        shunned_count=$(echo "$node_details" | grep ant_networking_shunned_count_total | awk 'NR==1 {print $2}')
        bad_peers=$(echo "$node_details" | grep ant_networking_bad_peers_count_total | awk 'NR==1 {print $2}')
        mem_used=$(echo "$node_details" | grep ant_networking_process_memory_used_mb | awk 'NR==3 {print $2}')
        cpu_usage=$(echo "$node_details" | grep ant_networking_process_cpu_usage_percentage | awk 'NR==3 {print $2}')
        rel_records=$(echo "$node_details" | grep ant_networking_relevant_records | awk 'NR==3 {print $2}')
        max_records=$(echo "$node_details" | grep ant_networking_max_records | awk 'NR==3 {print $2}')
        payment_count=$(echo "$node_details" | grep ant_networking_received_payment_count | awk 'NR==3 {print $2}')
        live_time=$(echo "$node_details" | grep ant_networking_live_time | awk 'NR==3 {print $2}')
        shunned_closedgroup=$(echo "$node_details" | grep ant_networking_shunned_by_close_group | awk 'NR==3 {print $2}')
        shunned_oldclosedgroup=$(echo "$node_details" | grep ant_networking_shunned_by_old_close_group | awk 'NR==3 {print $2}')

        if [[ -z "$puts" ]]; then
            puts=0
        fi

        # from metadata
        PeerId="\"$(echo "$node_metadata" | grep ant_networking_peer_id | awk 'NR==3 {print $1}' | cut -d'"' -f 2)\""
        NodeVersion="\"$(echo "$node_metadata" | grep ant_node_antnode_version | awk 'NR==3 {print $1}' | cut -d'"' -f 2)\""

        if [[ -f "/var/antctl/NodeDetails" ]]; then

            # shunn gun
            if (($(echo "$shunned_count > $ShunnedValue" | bc))); then
                Shunngun=1
                ShunnedNode=$i
                ShunnedValue=$shunned_count
            else
            Shunngun=0
            fi
        fi

    else
        total_nodes_killed=$(($total_nodes_killed + 1))
        status="\"Stopped\""
        gets=0
        puts=0
        up_time=0
        rewards_balance=0
        records=0
        connected_peers=0
        network_size=0
        open_connections=0
        total_peers=0
        shunned_count=0
        bad_peers=0
        mem_used=0
        cpu_usage=0
        rel_records=0
        max_records=0
        payment_count=0
        live_time=0
        shunned_closedgroup=0
        shunned_oldclosedgroup=0

        if [[ -f "/var/antctl/NodeDetails" ]]; then
            # for anm
            PeerId="\"$(echo "${node_details_store[$node_number]}" | awk -F',' '{print $2}')\""
            NodeVersion="\"$(echo "${node_details_store[$node_number]}" | awk -F',' '{print $3}')\""
        else
            # for antctl node manager service
            PeerId="\"NotReachableStoppedNode\""
            NodeVersion="\"$(${base_dir}/antnode$i/antnode -V | awk '{print $3}')\""
        fi
    fi

    # save Shunngun target
    if (($(echo "$Shunngun == 1" | bc))); then
        echo "MaxShunnedNode=$ShunnedNode" >/var/antctl/MaxShunnedNode
        echo "ShunnedValue=$ShunnedValue" >>/var/antctl/MaxShunnedNode
    fi

    # Format for InfluxDB
    node_details_str[$i]="nodes,id=$node_number PeerId=$PeerId,status=$status,version=$NodeVersion,gets="$gets"i,puts="$puts"i,up_time="$up_time"i,rewards="$rewards_balance",records="$records"i,connected_peers="$connected_peers"i,networ_size="$network_size"i,open_connections="$open_connections"i,total_peers="$total_peers"i,shunned_count="$shunned_count"i,bad_peers="$bad_peers"i,mem="$mem_used",cpu="$cpu_usage",rel_records="$rel_records"i,max_records="$max_records"i,payment_count="$payment_count"i,live_time="$live_time"i,shunned_closedgroup="$shunned_closedgroup"i,shunned_oldclosedgroup="$shunned_oldclosedgroup"i $influx_time"
    #sleep to slow script down to spread out cpu spike
    #rewards_balance=$(echo "scale=10; $rewards_balance / 1000000000" | bc)
    #total_rewards_balance=$(echo "scale=10; $total_rewards_balance + $rewards_balance" | bc -l)
    total_rewards_balance=$(echo "scale=18; $total_rewards_balance + $rewards_balance" | bc -l)
    total_network_size=$(($total_network_size + $network_size))

    sleep 1

done

network_size=$(echo "$total_network_size / $total_nodes_running" | bc)

# Latency
latency=$(ping -c 4 8.8.8.8 | tail -1 | awk '{print $4}' | cut -d '/' -f 2)

if [[ $time_min == 00 ]] || [[ $time_min == 20 ]] || [[ $time_min == 40 ]]; then
    geko_time=1
    ##############################################################################################
    # coin gecko gets upset with to many requests this atempts to get the exchange every 15 min
    # https://www.coingecko.com/api/documentation
    ##############################################################################################
    coingecko=$(curl -s -X 'GET' 'https://api.coingecko.com/api/v3/simple/price?ids=maidsafecoin&vs_currencies=gbp,eur%2Cusd&include_market_cap=true' -H 'accept: application/json')
    exchange_rate_gbp=$(awk -F'[:,]' '{print $3}' <<<$coingecko)
    market_cap_gbp=$(awk -F'[:,]' '{print $5}' <<<$coingecko)
    exchange_rate_eur=$(awk -F'[:,]' '{print $7}' <<<$coingecko)
    market_cap_eur=$(awk -F'[:,}]' '{print $9}' <<<$coingecko)
    exchange_rate_usd=$(awk -F'[:,]' '{print $11}' <<<$coingecko)
    market_cap_usd=$(awk -F'[:,}]' '{print $13}' <<<$coingecko)

    # calculate earnings in usd & gbp
    earnings_gbp=$(echo "scale=20; $total_rewards_balance*$exchange_rate_gbp" | bc)
    earnings_eur=$(echo "scale=20; $total_rewards_balance*$exchange_rate_eur" | bc)
    earnings_usd=$(echo "scale=20; $total_rewards_balance*$exchange_rate_usd" | bc)
fi

# get wallet balacnes direct from arbitrum wallet
attos=$(wget -qO- https://arbiscan.io/token/0xa78d8321B20c4Ef90eCd72f2588AA985A4BDb684?a=$WalletAddress 2>&1 | grep -oP "[0-9]+.[0-9]+ (ANT)" | awk '{print $1}')
#sepolia testnet
# attos=$(wget -qO- curl https://arbiscan.io/token/0xa78d8321B20c4Ef90eCd72f2588AA985A4BDb684?a=$WalletAddress 2>&1 | grep -oP "[0-9]+.[0-9]+ (ANT)" | awk '{print $1}')
if [[ -n "$attos" ]]; then
    walletbalance="nodes_totals total_attos="$attos" $influx_time"
fi

# calculate total storage of the node services folder
total_disk=$(echo "scale=0;("$(du -s "$base_dir" | cut -f1)")/1024" | bc)
UsedHdPercent=$(df -hP ${base_dir} | awk '{print $5}' | tail -1 | sed 's/%$//g')

# sleep till all nodes have systems have finished prosessing

while (($(("$time_min" + "10")) > $(date +"%M"))); do
    #5
    sleep 10
done

# Output

# Sort
for num in $(echo "${!node_details_str[@]}" | tr ' ' '\n' | sort -n); do
    echo "${node_details_str[$num]}"
done

echo "nodes_totals rewards=$total_rewards_balance,nodes_running="$total_nodes_running"i,nodes_killed="$total_nodes_killed"i $influx_time"
echo "nodes_totals total_disk="$total_disk"i,Disk_percent="$UsedHdPercent"i $influx_time"
echo "nodes_network size="$network_size"i $influx_time"
echo "nodes latency=$latency $influx_time"
echo "$walletbalance"
if [[ $geko_time == 1 ]]; then
    echo "nodes_coingecko,curency=gbp exchange_rate=$exchange_rate_gbp,marketcap=$market_cap_gbp,earnings=$earnings_gbp  $influx_time"
    echo "nodes_coingecko,curency=eur exchange_rate=$exchange_rate_eur,marketcap=$market_cap_eur,earnings=$earnings_eur  $influx_time"
    echo "nodes_coingecko,curency=usd exchange_rate=$exchange_rate_usd,marketcap=$market_cap_usd,earnings=$earnings_usd  $influx_time"
fi
