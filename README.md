# NTracking Dashboard

![image](https://github.com/safenetforum-community/NTracking/assets/25412853/3eb93d09-a2aa-431a-a442-247b41acba33)



whiptail script to set up NTracking 

# Prereq

Do not run as root user if you need to create a normal user with sudo rights and switch to that user.

```
adduser <username>
usermod -aG sudo <username>
su - u <username>
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
3. paste it into the import dashboard window and save
4. refresh Grafana and load the dashboard

# after NTracking is set up start some nodes with safe node manager and track there progress in Grafana.
