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

and paste in the custome config file contents here is an exmple.

```
# set machines in cluster ssh nick name
machines="cantabo dell p1 s00 s01 s02 s03 h00 h01 h02 p1"

# customise setings for each system on start up
CustomSetings() {

    if [[ "$machine" == "s00" ]]; then
        # set override for max 20 nodes on the master s00
        override='&& echo "NodeCap=20" >/var/safenode-manager/override'
    elif [[ "$machine" == "cantabo" ]]; then
        # set override for max 20 nodes, increase start nodes interval to 10 minutes and increase upgrade interval to 20 minutes on machine cantabo
        override='&& echo "NodeCap=20" >/var/safenode-manager/override && echo "DelayStart=10" >>/var/safenode-manager/override && echo "DelayUpgrade=20" >>/var/safenode-manager/override'
    elif [[ "$machine" == "dell" ]]; then
        # set override for max 10 nodes, increase start nodes interval to 10 minutes and increase upgrade interval to 20 minutes on machine dell
        override='&& echo "NodeCap=10" >/var/safenode-manager/override && echo "DelayStart=10" >>/var/safenode-manager/override && echo "DelayUpgrade=20" >>/var/safenode-manager/override'
    elif [[ "$machine" == "p1" ]]; then
        # set custome discord username on machine p1
        override='&& echo "DiscordUsername=\"--owner yourdiscordID\"" >/var/safenode-manager/override'
    elif [[ "$machine" == "h00" ]]; then
        # set no discord username and enable scraping script on machine h00
        override='&& echo "DiscordUsername=\"\"" >/var/safenode-manager/override && sudo rm -f /usr/bin/scrape.sh"*" && sudo wget -P /usr/bin http://safe-logs.ddns.net/scrip/scripts/scrape.sh && sudo chmod u+x /usr/bin/scrape.sh && echo "5 "*" "*" "*" "*" $USER /bin/bash /usr/bin/scrape.sh > /var/safenode-manager/scrape.log" | sudo tee /etc/cron.d/scrape'
    elif [[ "$machine" == "s01" ]]; then
        # set custome discord username on machine s01
        override='&& echo "DiscordUsername=\"--owner yourdiscordID\"" >/var/safenode-manager/override'
    elif [[ "$machine" == "s02" ]]; then
        # set custome discord username on machine s02
        override='&& echo "DiscordUsername=\"--owner yourdiscordID\"" >/var/safenode-manager/override'
    elif [[ "$machine" == "s03" ]]; then
        # set custome discord username on machine s03
        override='&& echo "DiscordUsername=\"--owner yourdiscordID\"" >/var/safenode-manager/override'
    fi

    # set custom machine load
    if [[ "$machine" == "s"* ]]; then
        override=''$override' && echo "DelayStart=5" >>/var/safenode-manager/override  && echo "DelayUpgrade=20" >>/var/safenode-manager/override'
    elif [[ "$machine" == "h"* ]]; then
        override=''$override' && sleep 120 && sed -i "s/^\\(DesiredLoadAverage=\\).*/\\1$(echo "$(nproc) "*" 2.0" | bc)/" /var/safenode-manager/config && sed -i "s/^\\(MaxLoadAverageAllowed=\\).*/\\1$(echo "$(nproc) "*" 3.0" | bc)/" /var/safenode-manager/config'
    elif [[ "$machine" == "p1" ]]; then
        override=''$override' && sleep 120 && sed -i "s/^\\(DesiredLoadAverage=\\).*/\\1$(echo "$(nproc) "*" 2.0" | bc)/" /var/safenode-manager/config && sed -i "s/^\\(MaxLoadAverageAllowed=\\).*/\\1$(echo "$(nproc) "*" 3.0" | bc)/" /var/safenode-manager/config'
    fi
}

```