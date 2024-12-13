# aatonnomicc node manager

Welcome to ANM  - experimental so feed back is welcome 

This script will control the number of nodes running on an ubuntu system saving time trying to guess how many nodes to start.

The script will be installed by selecting start nodes option

![image](https://github.com/user-attachments/assets/6d7da7d0-750e-46a8-aef7-8bc0d2bfcd08)


This will install the anms.sh script in /usr/bin and set the script to run on a 1 min cron schedule
On first startup it will ask for

1. Discord username
2. Logging options
3. Port range default is set at 55 which means first node will start on port 55001 and iterate up from there.
4. NodeCap - sets a hard limit of nodes so as to not overload routers.


Default load levels are set to low. No more new nodes will be added when the load average exceeds (Number of cpu's * 1.5)  and will stop nodes if the load average goes to (Number of cpu's * 2.5).
Once the script has started the first node the main script can be run again and a custom load level set if required.

![image](https://github.com/user-attachments/assets/0d4d1fac-bed4-4504-ae96-f460da688107)


since the load levels go by cpu count an example for a 4 cpu system would look like this

1. Low        Below 6 Start new nodes  Over 10 Stop nodes
2. Medium     Below 8 Start new nodes  Over 12 Stop nodes
3. High       Below 10 Start new nodes Over 14 Stop nodes
4. Extream    Below 12 Start new nodes Over 16 Stop nodes

anms.sh can stop one node each time it runs (normally every 60 ses) but can only start a new node every 3 minutes. In addition if a node is stopped for 5 hours it will delete the node.

After first run a config file is created at /var/safenode-manager/config.

![image](https://github.com/user-attachments/assets/f1203a76-24d9-4633-b045-8a88ae73eb99)

Edit any of these settings manualy to control anm if you need to change the default values.
If you wish fully automatic upgrades of nodes set 
```NodeVersion="--version 0.110.0"```
to
```NodeVersion=""``` and the upgrade will start at the upgrade hour and minnute.

# In Action

![image](https://github.com/user-attachments/assets/eac0ccd0-a706-4b8c-8a09-7c036518766d)

It can be seen here that system load started increasing at 07:00 for all machines runing anm.

![image](https://github.com/user-attachments/assets/3c50bcb5-af23-41e6-9ca6-e119dd9967e6)

and here is total node count showing the number of running nodes decreasing to keep the load in the defined range.

# prereq

1. A non-root user account must exist.

```
adduser <username>
usermod -aG sudo <username>
su <username>
cd (make sure and do the cd to change to correct home folder !!!)
```

2. User account must be able to do sudo actions without password.

```
#set up sudo access without password
sudo rm /etc/sudoers.d/*
sudo echo -e -n ''$USER' ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/10-users
```
3. Safeup must be installed.

```
#install safe up
curl -sSL https://raw.githubusercontent.com/maidsafe/safeup/main/install.sh | sudo bash
```
4. All nodeports closed in UFW firewall script will open and close ports as needed.

# to run anm

```
bash <(curl -s https://raw.githubusercontent.com/safenetforum-community/NTracking/main/anm/anm-local.sh)
```

# monitoring

1. Ntracking prefered way to monitor 
2. to manualy view the log file ```tail -f /var/safenode-manager/log```  This refreshes once per minnute when ams is running.

# scraping 

If Discord username is left blank then a scraping script will be installed at ```/usr/bin/scrape.sh```
This will run at 5 past the hour and scrape all node wallets with nanos into the client wallet in the default location.
The script can take some time to run as it sleeps between each wallet balance call so as to spread the load out as this can be cpu intensive.

reasoning for doing once an hour is that stopping the node to get the wallet and restarting is very resource hungry and if all the nodes need scraped at once it will cause a melt down.
once per hour means only a few nodes will be scraped at a time so as to keep the system happy.

before trying to move coins out from the host check the status of the script to make sure it is not running !!!

```
tail -f /var/safenode-manager/scrape.log
```

# Stopping nodes

just select stop nodes option from the script and on next run it will

1. stop all nodes
2. delete all node files
2. delete all scripts and cron jobs
3. close all fire wall ports used
4. reboot the system

# If it all goes wong

1. manualy stop and clear out everything
```
sudo rm /etc/cron.d/anm
sudo systemctl stop safenode*
sudo rm /etc/systemd/system/safenode*
sudo systemctl daemon-reload
sudo rm -rf /var/log/safenode
sudo rm -rf /var/safenode-manager
sudo rm -f /usr/bin/anms.sh
sudo rm -f /etc/cron.d/scrape
sudo rm -f /usr/bin/scrape.sh
```

2. sort firewall out if rules are left over

adjust for your ssh port if not using port 22 and keep 8086 open on machine running NTracking and also keep open for any other services running on the system.

```
sudo ufw disable
echo "y" | sudo ufw reset
sudo ufw default allow outgoing
sudo ufw default deny incoming
sudo ufw allow 22/tcp comment 'SSH'
sudo ufw allow 8086/tcp comment 'influxdb'
echo "y" | sudo ufw enable
```
then give system a reboot just for good luck also it will reset all load levels to zero

```
sudo reboot
```