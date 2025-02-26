# NTracking Dashboard

![Grafana](https://github.com/user-attachments/assets/6127bc55-51e3-4c73-bd84-f35b53d33161)


# usage
nodes must be started with safe node manager and have open-metrics enabled with metrics port set from 13001 for safe node 1 iterating up in line with safe node number

ie an example for 50 nodes --node-port can be customised or -- home network may be used.
update the --owner flag for your discord id or remove the --owner flag and timbobjohnes if you are not in a wave
```
sudo env "PATH=$PATH" antctl add --node-port 12001-12050  --count 50 --rewards-address <EtheriumAddress> --enable-metrics-server --metrics-port 13001-13050 evm-arbitrum-sepolia
sudo env "PATH=$PATH" antctl start --interval 301000
```

whiptail script to set up NTracking 

# Prereq

Do not run as root user if you need to create a normal user with sudo rights and switch to that user.

```
adduser <username>
usermod -aG sudo <username>
su <username>
cd (make sure and do the cd to change to correct home folder !!!)
```

# to Run

```bash <(curl -s https://raw.githubusercontent.com/safenetforum-community/NTracking/main/NTracking.sh)```

this script will run a whip tail menu script giving you the options to :

1. install Docker engine.
2. setup a dockerised install of Influxdb2 and Grafana to visualise data.
3. setup an install of Telegraf which will send data to influxDB.
4. uninstall telegraf influx and grafana.

Docker Engine only needs to be installed on the machine hosting influxDB and Grafana

Telegraf must be installed on all machines that are to send data to influx including the one which hosts Influx and Grafana if it is running nodes.


# Defaults for Influx and Grafana
username: ```safe```

password: ```jidjedewTSuIw4EmqhoOo```

Influxdb default Token ```HYdrv1bCZhsvMhYOq6_wg4NGV2OI9HZch_gh57nquSdAhbjhLMUIeYnCCAoybgJrJlLXRHUnDnz2v-xR0hDt3Q==```

These can be changed during the install via interactive prompt along with the TOKEN for data ingress to Influx2 Database

# How to access

Influx can be accesed on ```<IP Address>:8086```

Grafana can be accesed on ```<IP Address>:3000```

# Connecting Grafana to influx

1. Log into Grafana
2. Select add new data source
3. Search for InfluxDB
4. Enter details as below using the ip or hostname and port of the fluxdb install you are connecting to
5. click safe and test and if it goes green InfluxDB and Grafana are now connected.
![image](https://github.com/safenetforum-community/NTracking/assets/25412853/99c5c77b-7261-43ba-9a6f-11e0d4596425)



# Import Grafana dashboard

after connecting Grafana and InfluxDB select the option to import Dashboard

1. copy the Dashboard json from 
https://github.com/safenetforum-community/NTracking/blob/main/NTracking%20Dashboard
3. paste it into the import via dashboard JSON window and save
4. refresh Grafana and load the dashboard

# after NTracking is set up start some nodes and track their progress in Grafana.

# NTracking upgrades

If you have NTracking set up and working to upgrade to latest version
update the script and the cron job with

for resource gathering script
```
sudo rm -f /usr/bin/influx-resources.sh* && sudo wget -P /usr/bin  https://raw.githubusercontent.com/safenetforum-community/NTracking/main/influx-resources.sh && sudo chmod u+x /usr/bin/influx-resources.sh
```

for cron job
```
echo "*/20 * * * * $USER /usr/bin/mkdir -p /tmp/influx-resources && /bin/bash /usr/bin/influx-resources.sh > /tmp/influx-resources/influx-resources" | sudo tee /etc/cron.d/influx_resources
```

then delete the current dashboard in grafana and re add the one from the git hub if the script changes the dashboard will change with it.

# If updateing NTracking and it dosenot show the node metrics Clear the Influx database
log into influx and delete the bucket called telegraf to clear out old data incase there is breaking changes 
after deleting telegraf create a new bucket called telegraf for the new data to be stored in.
