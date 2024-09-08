#!/usr/bin/env bash

# Environment setup
export PATH=$PATH:$HOME/.local/bin
source ~/.config/safe/env
base_dir="/var/safenode-manager/services"

# sudo rm -f /usr/bin/scrape.sh* && sudo wget -P /usr/bin  https://raw.githubusercontent.com/safenetforum-community/NTracking/main/anm/scripts/scrape.sh && sudo chmod u+x /usr/bin/scrape.sh
# echo "5 * * * * $USER /bin/bash /usr/bin/scrape.sh > /var/safenode-manager/scrape.log" | sudo tee /etc/cron.d/scrape

# block script from running while its already running
sudo mv /etc/cron.d/scrape $HOME/scrape

declare -A node_details_store

safe wallet create --no-replace --no-password

safe wallet address
wallet_address=$(safe wallet address | awk 'NR==3{print $1}')
echo "$wallet_address"

# count node foldrs
NumberOfNodes=$(ls $base_dir | wc -l)

for ((i = 1; i <= $NumberOfNodes; i++)); do
    node_number=$(seq -f "%03g" $i $i)
    node_name=safenode$node_number
    . /var/safenode-manager/NodeDetails >/dev/null 2>&1
    nodestatus=$(echo "${node_details_store[$node_number]}" | awk -F',' '{print $4}')

    rewards_balance=$(safe wallet balance --peer-id /var/safenode-manager/services/safenode$i | awk 'NR==3{print $7}')
    echo
    echo "$node_name"
    echo "$rewards_balance"
    echo "$nodestatus"

    if (($(echo "$rewards_balance > 0.000000000" | bc -l))); then
        echo
        echo "has nanos"

        #move wallets to initiate a transfer
        if [[ "$nodestatus" = "RUNNING" ]]; then
            sudo systemctl stop "$node_name"
            echo "$node_name stopped"
        fi
        mv $HOME/.local/share/safe/client/wallet $HOME/.local/share/safe/client/wallet-backup
        echo "moved client wallet to backup location"
        sudo mv /var/safenode-manager/services/safenode$i/wallet/ $HOME/.local/share/safe/client/
        echo "moved $node_name wallet to client location"
        sudo chown -R "$(whoami)":"$(whoami)" $HOME/.local/share/safe/client/wallet
        echo "ownership of $node_name changed to user:"$(whoami)""

        node_balance=$rewards_balance
        echo "node wallet balance to transfer $node_balance"

        #send rewards from node wallet to main wallet address
        deposit=$(safe wallet send $node_balance $wallet_address | awk 'NR==10{print $1}')
        echo "safe wallet send $node_balance $wallet_address"

        echo ""
        echo "$deposit"
        echo ""

        #move wallets back to original location
        sudo mv $HOME/.local/share/safe/client/wallet /var/safenode-manager/services/safenode$i/
        echo "moved $node_name wallet to service location"
        mv $HOME/.local/share/safe/client/wallet-backup $HOME/.local/share/safe/client/wallet
        echo "moved client wallet to correct location"
        sudo chown -R safe:safe /var/safenode-manager/services/safenode$i/wallet
        echo "ownership of $node_name changed to user: safe"
        #move wallets to initiate a transfer
        if [[ "$nodestatus" = "RUNNING" ]]; then
            sudo systemctl start "$node_name"
            echo "$node_name started"
        fi
        echo

        safe wallet receive "$deposit"
        echo
        safe wallet balance
        echo
    fi
    sleep 2
done

client_balance=$(safe wallet balance | awk 'NR==3{print $1}')

if (($(echo "$client_balance > 0.000000000" | bc -l))); then
# send balance to self to avoid complex transactions.
deposit=$(safe wallet send $client_balance $wallet_address | awk 'NR==10{print $1}')
safe wallet receive "$deposit"
client_balance=$(safe wallet balance | awk 'NR==3{print $1}')
fi

echo
echo
echo "$(date '+%d/%m/%Y  %H:%M')"
echo ""
echo "######################################################################"
echo "#                                                                    #"
echo "#            New wallet balance $client_balance                          #"
echo "#                                                                    #"
echo "######################################################################"
echo ""
echo ""
echo ""
# re add cron job
sudo mv $HOME/scrape /etc/cron.d/scrape
