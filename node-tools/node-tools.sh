#!/bin/bash
# Copyright 2024 - Jadkins-Me
#
# This Code/Software is licensed to you under GNU AFFERO GENERAL PUBLIC LICENSE (GPL), Version 3
# Unless required by applicable law or agreed to in writing, the Code/Software distributed
# under the GPL Licence is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied. Please review the Licences for the specific language governing
# permissions and limitations relating to use of the Code/Software.

# // User Modifiable Options
process_name="safenode"                     #name of node executable
node_registry="node_registry.json"          #file updated by node-launchpad and safenode-manager
service_scope="undefined"                   #user=user service under /home/username/.config, system=under /var
base_dir="undefined"                        #location of binarys TODO: need to cope with user defined paths outside path

# // NOTE : Changing things below this line might break functionality

tools_version="0.1.1-July 2024"             #Version of script

bold=$(tput bold)
normal=$(tput sgr0)

# // Packages needed by script
required_tools=("jq" "curl" "awk" "ps" "grep" "head" "sort" )

# Environment setup
export PATH=$PATH:$HOME/.local/bin

# Loop through packages and check if it is installed
for tool in "${required_tools[@]}"; do
    if ! command -v "$tool" &> /dev/null; then
        echo "Error: '$tool' is not installed. Please install it and try again."
        echo "You can install all the required utilities, with command."
        echo "sudo apt install $tool"
        exit 1
    fi
done

# write our PID to file, and handle a hung process running...
pid_file="$HOME/.node-tools.pid"
max_stale_seconds=3600                                          #How long we allow this process to run before force close
trap 'rm -- "$pid_file" > /dev/null 2>&1' EXIT                  #Ensure we delete our PID file on EXIT or Kill

if [ -f "$pid_file" ]; then
    pid="$(cat "$pid_file")"
    age_in_seconds="$(($(date +%s) - $(date -r "$pid_file" +%s)))"

    if ps "$pid" >/dev/null; then
        if [ "$age_in_seconds" -ge "$max_stale_seconds" ]; then
            kill "$pid"
        else
            echo "Error: An instance of the script is currently running !"
            echo "please wait up to 60 minutes for that to complete."
            exit 1
        fi
    fi
fi

# Save the current PID to the file
echo "$$" > "$pid_file"

# Check context in which we are running, userservice or systemservice
service_scope=$(ps aux | grep -v grep | grep $process_name | awk '{print $2}' | sort -u | head -n 1 | while read -r pid; do ps -o user= -p "$pid"; done)
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
    echo "Error: Unable to locate node_registry, are you sure you have nodes running on this machine ? "
    exit 1
fi

# count of nodes
numberofnodes=$(jq -r ".nodes | length" $json_file)

echo "${bold}Node Tools - Version $tools_version ${normal}"
echo "Number of Nodes : $numberofnodes"

if [ "$numberofnodes" -lt 1 ]; then
        echo "Error: It looks like you have no nodes running"
        exit 1
fi

if [ "$numberofnodes" -gt 50 ]; then
        echo "Warning: This script is only designed to run with up to 50 nodes, Y.M.M.V"
fi

echo "${bold}-=Help=-${normal}"
echo "${bold}Status=${normal}The status of the node service, being ready(new node not started), running or stopped"
echo "${bold}Owner=${normal}Discord user ID returned from /get-id used in discord Autonomi channel"
echo "${bold}Mode=${normal}If user, then node is running as user service, if system it will be running as system service"
echo "${bold}Net=${normal}Network mode being used by node, UPNP or Home, or port-fwd if you have setup forwarding on router"
echo "${bold}Port=${normal}UDP port the node is listening for connections on, for port-fwd this port must be fowarded from router"
echo "${bold}Rec=${normal}Number of RECORDS stored on node made up of data chunks, and spends"
echo "${bold}SC=${normal}Storage Cost, the value a client will be charged - a value of 0 means no estimate has been asked for yet"
echo "${bold}RB=${normal}Rewards Balance, this will be nano's received and stored in node wallet"
echo "${bold}FB=${normal}Forward Balance, this is nano's that have been earned and forwarded as part of beta rewards - they should appear in /rank"
echo "${bold}Ver=${normal}Version of node Software being run"
echo ""

for i in $(jq -c '.nodes[]' $json_file ); do
    # Pass node data

    # Parse the JSON string into a dictionary
    json_dict=$(echo "$i" | jq -r 'to_entries | map("\(.key)=\(.value)") | .[]')

    # Initialize variables with default value
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
            network_type="home"
        else
            network_type="port-fwd"
        fi
    fi

    #If Metrics Enabled, Call extended /Metrics API
    if [ "$status" = "Running" ]; then
        if [ "$metrics_port" != "0" ]; then
            node_details="$(curl -s 127.0.0.1:$metrics_port/metrics)"
            #handle metrics endpoint down
            mcurl=$(( $? != 0 ))
            #process variables as we handle null
            rewards_balance=$(echo "$node_details" | grep -oP '(?<=sn_node_current_reward_wallet_balance )\d+' || echo 0 )
            rewards_forward=$(echo "$node_details" | grep -oP '(?<=sn_node_total_forwarded_rewards )\d+' || echo 0 )
            records=$(echo "$node_details" | grep -oP '(?<=sn_networking_records_stored )\d+' || echo 0 )
            store_cost=$(echo "$node_details" | grep -oP '(?<=sn_networking_store_cost )\d+' || echo 0 )
        fi
    fi

    # Check if the length of the string is greater than 10
    if [ ${#owner} -gt 20 ]; then
       # Truncate the string to 10 characters
       owner="${owner:0:20}"
    fi

    if [ "$user_mode" = "true" ]; then
            user_mode="user"
    else
            user_mode="system"
    fi

    if [ "$mcurl" = "0" ]; then
       input_string="$service_name:$status:$owner:$user_mode:$network_type:$node_port:$records:$store_cost:$rewards_balance:$rewards_forward:$version"

       # Print formatted output using AWK
       echo "$input_string" | awk -F: '{ printf "%-11s | Status: %-7s | Owner: %-20s | Mode: %-6s | Net: %-8s | Port: %-5s | Rec: %-4s | SC: %-4s | RB: %-4s | FB: %-4s | Ver: %-10s\n", $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12}'
    else
       input_string="$service_name:$status:$owner:$user_mode:$network_type:$node_port:$version"

       echo "$input_string" | awk -F: '{ printf "%-11s | Status: %-7s | Owner: %-20s | Mode: %-6s | Net: %-8s | Port: %-5s | Ver: %-10s\n", $1, $2, $3, $4, $5, $6, $7}'
    fi

done
