#!/bin/bash

#run with bash <(curl -s https://raw.githubusercontent.com/safenetforum-community/NTracking/main/scrape.sh)

# Environment setup
export PATH=$PATH:$HOME/.local/bin
base_dir="/var/safenode-manager/services"

safe wallet create --no-replace --no-password

safe wallet address

wallet_address=$(safe wallet address | awk 'NR==3{print $1}')

echo "$wallet_address"

# Process nodes
for dir in "$base_dir"/*; do
    if [[ -f "$dir/safenode.pid" ]]; then
        dir_name=$(basename "$dir")
        node_number=${dir_name#safenode}
        rewards_balance=$(safe wallet balance --peer-id /var/safenode-manager/services/safenode$node_number | awk 'NR==3{print $7}')

                echo ""
                echo "$dir_name"
                echo "$rewards_balance"
                echo ""
                                echo ""

        if (( $(echo "$rewards_balance > 0.000000000" |bc -l) )); then
                echo "has nanos"

                                #move wallets to initiate a transfer
                                #sudo env "PATH=$PATH" safenode-manager stop --service-name "$dir_name"
                                sudo systemctl stop "$dir_name"
                                mv $HOME/.local/share/safe/client/wallet $HOME/.local/share/safe/client/wallet-backup
                                sudo mv /var/safenode-manager/services/safenode$node_number/wallet/ $HOME/.local/share/safe/client/
                                sudo chown -R "$USER":"$USER" $HOME/.local/share/safe/client/wallet

                                node_balance=$(safe wallet balance | awk 'NR==3{print $1}')
                                echo ""
                                echo " node wallet transfered balance:$node_balance"
                                echo ""

                                #send rewards from node wallet to main wallet address
                                deposit=$(safe wallet send $node_balance $wallet_address | awk 'NR==10{print $1}')
                                echo ""
                                echo "$deposit"
                                echo ""

                                #move wallets back to original location
                                sudo mv $HOME/.local/share/safe/client/wallet /var/safenode-manager/services/safenode$node_number/
                                mv $HOME/.local/share/safe/client/wallet-backup $HOME/.local/share/safe/client/wallet
                                sudo chown -R safe:safe /var/safenode-manager/services/safenode$node_number/wallet
                                #sudo env "PATH=$PATH" safenode-manager start --service-name "$dir_name"
                                sudo systemctl start "$dir_name"

                                safe wallet receive "$deposit"
                                safe wallet balance

                fi
    fi
done

client_balance=$(safe wallet balance | awk 'NR==3{print $1}')

echo ""
echo "######################################################################"
echo "#                                                                    #"
echo "#            New wallet balance $client_balance                          #"
echo "#                                                                    #"
echo "######################################################################"
echo ""

