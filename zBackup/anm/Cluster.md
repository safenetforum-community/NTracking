# aatonnomicc cluster controler 

![image](https://github.com/user-attachments/assets/d8efc3ec-7983-4c43-814a-da5b20ddd836)


if you have used anm node manager and would now like to control all your machines simultaneously then cluster controler is for you.


cluster controler is exactley the same scripts but running accross multiple machines via ssh to do the steps.

to set up select one machine as the master which you will run the script on in this example that will be  ```s00```

first thing is first you will need to be able to log into each machine via ssh from the master machine via short config file ie ```ssh s01```

some info on that is available here https://www.cyberciti.biz/faq/create-ssh-config-file-on-linux-unix/
once you are able to ssh into all machines via an ssh nic name including the master itself if it is to run nodes thats pretty much all there is to it.

but you will need to create a custom config file on the master machine to contol any specifics settings like node caps or discord usernames.

create the custom file with

```nano $HOME/.local/share/anm-cluster```

and paste in the custom config file contents here is an exmple which will need edited to your own machine names and specifications.

```
# machines in cluster accessable by ssh
machines="cantabo dell p1 s00 s01 s02 s03 h00 h01 h02 p1"

# your discord ID
YourDiscordID="DiscordID"

# customise setings for each system on start up

CustomSetings() {

    # set global discord username override
    override='&& echo "DiscordUsername=\"--owner '$YourDiscordID'\"" >/var/safenode-manager/override '

    # set custom overrides for machines
    if [[ "$machine" == "s00" ]]; then
        # set override for max 20 nodes on the master s00
        override=''$override'&& echo "NodeCap=20" >>/var/safenode-manager/override '
    elif [[ "$machine" == "cantabo" ]]; then
        # set override for max 20 nodes, increase start nodes interval to 10 minutes and increase upgrade interval to 20 minutes on machine cantabo
        override=''$override'&& echo "NodeCap=20" >>/var/safenode-manager/override && echo "DelayStart=10" >>/var/safenode-manager/override && echo "DelayUpgrade=20" >>/var/safenode-manager/override '
    elif [[ "$machine" == "dell" ]]; then
        # set override for max 10 nodes, increase start nodes interval to 10 minutes and increase upgrade interval to 20 minutes on machine dell
        override=''$override'&& echo "NodeCap=10" >>/var/safenode-manager/override && echo "DelayStart=10" >>/var/safenode-manager/override && echo "DelayUpgrade=20" >>/var/safenode-manager/override '
    elif [[ "$machine" == "p1" ]]; then
        # set a different discord username on machine p1
        override=''$override'&& echo "DiscordUsername=\"--owner AnotherDiscordID\"" >>/var/safenode-manager/override '
    elif [[ "$machine" == "h00" ]]; then
        # set no discord username and enable scraping script on machine h00
        override=''$override'&& echo "DiscordUsername=\"\"" >>/var/safenode-manager/override && sudo rm -f /usr/bin/scrape.sh"*" && sudo wget -P /usr/bin '$Location'anm/scripts/scrape.sh && sudo chmod u+x /usr/bin/scrape.sh && echo "5 "*" "*" "*" "*" $USER /bin/bash /usr/bin/scrape.sh > /var/safenode-manager/scrape.log" | sudo tee /etc/cron.d/scrape '
    fi

    # set custom machine load
    if [[ "$machine" == "s"* ]]; then
        # set all machines that have names that begin with s to have a 5 minute node start interval and 20 minute upgrade interval
        override=''$override' && echo "DelayStart=5" >>/var/safenode-manager/override  && echo "DelayUpgrade=20" >>/var/safenode-manager/override '
    elif [[ "$machine" == "h"* ]]; then
        # set all machines that have names that begin with h to start on load level medium
        override=''$override' && sleep 120 && sed -i "s/^\\(DesiredLoadAverage=\\).*/\\1$(echo "$(nproc) "*" 2.0" | bc)/" /var/safenode-manager/config && sed -i "s/^\\(MaxLoadAverageAllowed=\\).*/\\1$(echo "$(nproc) "*" 3.0" | bc)/" /var/safenode-manager/config '
    fi
}
```

# to run it all
thats it done you can now control your cluster. 

```
bash <(curl -s https://raw.githubusercontent.com/safenetforum-community/NTracking/main/anm/anm-cluster.sh)
```