#!/usr/bin/env bash

# edit these defaults here or edit them in an interactive menu when the script is run
INFLUXDB_GRAFANA_USER="safe"
GRAFANA_PORT=3000
INFLUXDB_GRAFANA_PASSWORD="jidjedewTSuIw4EmqhoOo"
INFLUXDB_PORT=8086
INFLUXDB_TOKEN="HYdrv1bCZhsvMhYOq6_wg4NGV2OI9HZch_gh57nquSdAhbjhLMUIeYnCCAoybgJrJlLXRHUnDnz2v-xR0hDt3Q=="

# change to home directory
cd

export NEWT_COLORS='
window=,white
border=black,white
textbox=black,white
button=black,white
'

############################################## select NTracking option action

SELECTION=$(whiptail --title "NTracking Setup" --radiolist \
"NTracking Setup Actions                              " 20 70 10 \
"1" "Install Docker Engine" OFF \
"2" "Setup Influxdb2 & Grafana" OFF \
"3" "Install Telegraf" OFF \
"4" "Exit" ON \
"5" "Stop & Uninstall NTracking          " OFF 3>&1 1>&2 2>&3)

if [[ $? -eq 255 ]]; then
exit 0
fi


############################################################################################################################################## Install Docker Engine
if [[ "$SELECTION" == "1" ]]; then

curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

#test install with
#sudo docker run hello-world


#set up docker user so dont have to run all comands as roor or with sudo
sudo groupadd docker
sleep 1
sudo usermod -aG docker $USER
sleep 1
newgrp docker
sleep 1
# test without sudo

# to test install you can run 
#                                docker run hello-world

############################################################################################################################################ Setup Influxdb2 & Grafana
elif [[ "$SELECTION" == "2" ]]; then

## enter Admin username for Influx and Grafana
INFLUXDB_GRAFANA_USER=$(whiptail --title "Admin username for Influx & Grafana " --inputbox "\nAdmin username for Influx & Grafana" 8 40 $INFLUXDB_GRAFANA_USER 3>&1 1>&2 2>&3)
if [[ $? -eq 255 ]]; then
exit 0
fi

## enter Admin password for Influx and Grafana
INFLUXDB_GRAFANA_PASSWORD=$(whiptail --title "Admin password for Influx & Grafana " --inputbox "\nAdmin password for Influx & Grafana" 8 40 $INFLUXDB_GRAFANA_PASSWORD 3>&1 1>&2 2>&3)
if [[ $? -eq 255 ]]; then
exit 0
fi

# enter the token that will allow data to be writen to the influx DB
INFLUXDB_TOKEN=$(whiptail --title "Token for use in Influxdb" --inputbox "\nInflux Token" 8 40 "HYdrv1bCZhsvMhYOq6_wg4NGV2OI9HZch_gh57nquSdAhbjhLMUIeYnCCAoybgJrJlLXRHUnDnz2v-xR0hDt3Q==" 3>&1 1>&2 2>&3)
if [[ $? -eq 255 ]]; then
exit 0
fi

## Enter Enter the port Influxdb will be run on
INFLUXDB_PORT=$(whiptail --title "Enter the port InfluxDB will run on " --inputbox "\nEnter Enter the port Influxdb will be run on" 8 40 $INFLUXDB_PORT 3>&1 1>&2 2>&3)
if [[ $? -eq 255 ]]; then
exit 0
fi

## Enter Enter the port Grafana will be accesed on
GRAFANA_PORT=$(whiptail --title "Enter the port Grafana will be run on " --inputbox "\nEnter Enter the port Grafana will be run on" 8 40 $GRAFANA_PORT 3>&1 1>&2 2>&3)
if [[ $? -eq 255 ]]; then
exit 0
fi

# stop Influxdb and grafana docker if running
docker compose --project-directory $HOME/.local/share/tig-stack/ down

#remove Grafana and Influx contaners
docker remove influxdb
docker remove grafana

#remove old folders and config files if they exists
sudo rm -rf $HOME/.local/share/tig-stack

#make local directorys

mkdir -p $HOME/.local/share/tig-stack/influxdb/data \
  $HOME/.local/share/tig-stack/influxdb/config \
  $HOME/.local/share/tig-stack/grafana/data \
  $HOME/.local/share/tig-stack/grafana/config \
  $HOME/.local/share/tig-stack/grafana/log

sleep 1

##################################################################################write the influxdb.conf file leave this as it is for defaults
tee $HOME/.local/share/tig-stack/influxdb/config/config.yml 2>&1 > /dev/null <<EOF
assets-path: ""
bolt-path: /var/lib/influxdb2/influxd.bolt
e2e-testing: false
engine-path: /var/lib/influxdb2/engine
feature-flags: {}
flux-log-enabled: false
hardening-enabled: false
http-bind-address: :8086
http-idle-timeout: 3m0s
http-read-header-timeout: 10s
http-read-timeout: 0s
http-write-timeout: 0s
influxql-max-select-buckets: 0
influxql-max-select-point: 0
influxql-max-select-series: 0
instance-id: ""
key-name: ""
log-level: info
metrics-disabled: false
nats-max-payload-bytes: 0
no-tasks: false
pprof-disabled: false
query-concurrency: 1024
query-initial-memory-bytes: 0
query-max-memory-bytes: 0
query-memory-bytes: 0
query-queue-size: 1024
reporting-disabled: false
secret-store: bolt
session-length: 60
session-renew-disabled: false
sqlite-path: ""
storage-cache-max-memory-size: 1073741824
storage-cache-snapshot-memory-size: 26214400
storage-cache-snapshot-write-cold-duration: 10m0s
storage-compact-full-write-cold-duration: 4h0m0s
storage-compact-throughput-burst: 50331648
storage-max-concurrent-compactions: 0
storage-max-index-log-file-size: 1048576
storage-no-validate-field-size: false
storage-retention-check-interval: 30m0s
storage-series-file-max-concurrent-snapshot-compactions: 0
storage-series-id-set-cache-size: 0
storage-shard-precreator-advance-period: 30m0s
storage-shard-precreator-check-interval: 10m0s
storage-tsm-use-madv-willneed: false
storage-validate-keys: false
storage-wal-fsync-delay: 0s
storage-wal-max-concurrent-writes: 0
storage-wal-max-write-delay: 10m0s
storage-write-timeout: 10s
store: disk
testing-always-allow-setup: false
tls-cert: ""
tls-key: ""
tls-min-version: "1.2"
tls-strict-ciphers: false
tracing-type: ""
ui-disabled: false
vault-addr: ""
vault-cacert: ""
vault-capath: ""
vault-client-cert: ""
vault-client-key: ""
vault-client-timeout: 0s
vault-max-retries: 0
vault-skip-verify: false
vault-tls-server-name: ""
vault-token: ""
EOF

###################################################################################################################################################### write the grafana config

tee $HOME/.local/share/tig-stack/grafana/config/custom.ini 2>&1 > /dev/null <<EOF

##################### Grafana Configuration Example #####################

#################################### Paths ####################################
[paths]

#################################### Server ####################################
[server]

[server.custom_response_headers]

#################################### GRPC Server #########################
;[grpc_server]

#################################### Database ####################################
[database]

################################### Data sources #########################
[datasources]

#################################### Cache server #############################
[remote_cache]

#################################### Data proxy ###########################
[dataproxy]

#################################### Analytics ####################################
[analytics]


#################################### Security ####################################
[security]
admin_user = $INFLUXDB_GRAFANA_USER
admin_password = $INFLUXDB_GRAFANA_PASSWORD

[security.encryption]

#################################### Snapshots ###########################
[snapshots]

#################################### Dashboards History ##################
[dashboards]

#################################### Users ###############################
[users]

[secretscan]

[service_accounts]

[auth]

#################################### Anonymous Auth ######################
[auth.anonymous]

#################################### GitHub Auth ##########################
[auth.github]

#################################### GitLab Auth #########################
[auth.gitlab]

#################################### Google Auth ##########################
[auth.google]

#################################### Grafana.com Auth ####################
[auth.grafana_com]

#################################### Azure AD OAuth #######################
[auth.azuread]

#################################### Okta OAuth #######################
[auth.okta]

#################################### Generic OAuth ##########################
[auth.generic_oauth]

#################################### Basic Auth ##########################
[auth.basic]

#################################### Auth Proxy ##########################
[auth.proxy]

#################################### Auth JWT ##########################
[auth.jwt]

#################################### Auth LDAP ##########################
[auth.ldap]

#################################### AWS ###########################
[aws]

#################################### Azure ###############################
[azure]

#################################### Role-based Access Control ###########
[rbac]

#################################### SMTP / Emailing ##########################
[smtp]

[smtp.static_headers]

[emails]

#################################### Logging ##########################
[log]

[log.console]

[log.file]

[log.syslog]

[log.frontend]

#################################### Usage Quotas ########################
[quota]

#### set quotas to -1 to make unlimited. ####

#################################### Unified Alerting ####################
[unified_alerting]

[unified_alerting.reserved_labels]

[unified_alerting.state_history]

[unified_alerting.state_history.external_labels]

[unified_alerting.state_history.annotations]

max_age =

max_annotations_to_keep =

[unified_alerting.upgrade]

#################################### Annotations #########################
[annotations]

[annotations.dashboard]

[annotations.api]

#################################### Explore #############################
[explore]

#################################### Help #############################
[help]

#################################### Profile #############################
[profile]

#################################### News #############################
[news]

#################################### Query #############################
[query]

#################################### Query History #############################
[query_history]

#################################### Internal Grafana Metrics ##########################
[metrics]

[metrics.environment_info]

[metrics.graphite]

#################################### Grafana.com integration  ##########################
[grafana_com]

#################################### Distributed tracing ############
[tracing.jaeger]

[tracing.opentelemetry]

[tracing.opentelemetry.jaeger]

[tracing.opentelemetry.otlp]

#################################### External image storage ##########################
[external_image_storage]

[external_image_storage.s3]

[external_image_storage.webdav]

[external_image_storage.gcs]

[external_image_storage.azure_blob]

[external_image_storage.local]

[rendering]

[panels]

[plugins]

#################################### Grafana Live ##########################################
[live]

#################################### Grafana Image Renderer Plugin ##########################
[plugin.grafana-image-renderer]

[support_bundles]

[enterprise]

[feature_toggles]

[date_formats]

[expressions]

[geomap]

[navigation.app_sections]

[navigation.app_standalone_pages]

#################################### Secure Socks5 Datasource Proxy #####################################
[secure_socks_datasource_proxy]

################################## Feature Management ##############################################
[feature_management]

#################################### Public Dashboards #####################################
[public_dashboards]

EOF

########################################################################################################### write docker compose config file

tee $HOME/.local/share/tig-stack/docker-compose.yaml 2>&1 > /dev/null <<EOF
version: "3.8"
services:
  influxdb:
    image: influxdb:2.7.5
    container_name: influxdb
    environment:
      - DOCKER_INFLUXDB_INIT_MODE=setup
      - DOCKER_INFLUXDB_INIT_USERNAME=$INFLUXDB_GRAFANA_USER
      - DOCKER_INFLUXDB_INIT_PASSWORD=$INFLUXDB_GRAFANA_PASSWORD
      - DOCKER_INFLUXDB_INIT_ORG=safe-org
      - DOCKER_INFLUXDB_INIT_BUCKET=telegraf
      - DOCKER_INFLUXDB_INIT_ADMIN_TOKEN=$INFLUXDB_TOKEN
    volumes:
      # Make sure you create these local directories
      - $HOME/.local/share/tig-stack/influxdb/data:/var/lib/influxdb2
      - $HOME/.local/share/tig-stack/influxdb/config:/etc/influxdb2
    ports:
      - $INFLUXDB_PORT:8086
    restart: unless-stopped
    networks:
      - tig_network
    healthcheck:
      test: "curl -f http://localhost:8086/ping"
      interval: 5s
      timeout: 10s
      retries: 5

  grafana:
    image: grafana/grafana-enterprise
    container_name: grafana
    user: "1000:1000"
    ports:
      - $GRAFANA_PORT:3000
    volumes:
      # Make sure you create these local directories
      - $HOME/.local/share/tig-stack/grafana/data:/var/lib/grafana
      - $HOME/.local/share/tig-stack/grafana/config:/etc/grafana
      - $HOME/.local/share/tig-stack/grafana/log:/var/log/grafana
    restart: unless-stopped
    environment:
       - GF_PATHS_CONFIG=/etc/grafana/custom.ini

    networks:
      - tig_network

networks:
  tig_network:
    driver: bridge
EOF

#open firewall port fot data ingress
#sudo ufw allow "$INFLUXDB_PORT"/tcp comment 'influxdb2'

#start docker contaner it will start in forground so you can see any errors just close terminal when satisfied
# it will restart automaticaly on boot
docker compose --project-directory $HOME/.local/share/tig-stack/ up -d

####################################################################################################################################################################################################### Install Telegraf
elif [[ "$SELECTION" == "3" ]]; then

#######################################remove this block after all instances of telegraf in docker are removed
# stop Telegraf docker if running
docker compose --project-directory $HOME/.local/share/tig-stack/telegraf down
# remove telegraf contaner
docker remove telegraf
#remove old folders and config files if they exist 
sudo rm -rf $HOME/.local/share/tig-stack/telegraf
sudo rm -rf /tmp/influx-resources

# enter the ipaddress and port of the influx instalation
INFLUXDB_IP_PORT=$(whiptail --title "IP address & Port of InfluxDB2" --inputbox "\nIP Address & Port of Influxdb2" 8 60 127.0.0.1:$INFLUXDB_PORT 3>&1 1>&2 2>&3)
if [[ $? -eq 255 ]]; then
exit 0
fi

# enter the token that will allow data to be writen to the influx DB
INFLUXDB_TOKEN=$(whiptail --title "Token for use with Influxdb" --inputbox "\nInflux Token" 8 40 "$INFLUXDB_TOKEN" 3>&1 1>&2 2>&3)
if [[ $? -eq 255 ]]; then
exit 0
fi

#setup cron job for resources
echo "*/15 * * * * $USER /usr/bin/mkdir -p /tmp/influx-resources && /bin/bash /usr/bin/influx-resources.sh > /tmp/influx-resources/influx-resources" | sudo tee /etc/cron.d/influx_resources

#set utc time zone
sudo timedatectl set-timezone UTC

#install jq
sudo apt-get install jq -y

#install bc
sudo apt-get install bc -y

################################################################### download script to gather node resources

#remove old script if exists
sudo rm /usr/bin/influx-resources.sh*

# download latest script from git hub
sudo wget -P /usr/bin  https://raw.githubusercontent.com/safenetforum-community/NTracking/main/influx-resources.sh

#make executable
sudo chmod u+x /usr/bin/influx-resources.sh

#####################################


# install telegraf and stop it for writing config file

curl -s https://repos.influxdata.com/influxdata-archive_compat.key > influxdata-archive_compat.key
echo '393e8779c89ac8d958f81f942f9ad7fb82a25e133faddaf92e15b16e6ac9ce4c influxdata-archive_compat.key' | sha256sum -c && cat influxdata-archive_compat.key | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/influxdata-archive_compat.gpg > /dev/null
echo 'deb [signed-by=/etc/apt/trusted.gpg.d/influxdata-archive_compat.gpg] https://repos.influxdata.com/debian stable main' | sudo tee /etc/apt/sources.list.d/influxdata.list
sudo apt-get update && sudo apt-get install telegraf

sleep 1
sudo systemctl stop telegraf.service
sleep 1

############################################################################################################################################# create telegraf config file
sudo tee /etc/telegraf/telegraf.conf 2>&1 > /dev/null <<EOF
# Configuration for telegraf agent
[agent]
  interval = "30s"
  round_interval = true
  metric_batch_size = 1000
  metric_buffer_limit = 10000
  collection_jitter = "0s"
  flush_interval = "10s"
  flush_jitter = "0s"
  precision = ""
  hostname = ""
  omit_hostname = false
  
[[outputs.influxdb_v2]]
  urls = ["http://$INFLUXDB_IP_PORT"]
  token = "$INFLUXDB_TOKEN"
  organization = "safe-org"
  bucket = "telegraf"

# cpu stats
[[inputs.cpu]]
  percpu = false
  totalcpu = true
  collect_cpu_time = false
  report_active = false

# Read metrics about memory usage
[[inputs.mem]]
  # no configuration

# Read metrics about swap memory usage
[[inputs.swap]]
  # no configuration

[[inputs.diskio]]
  devices = ["xvda3", "sd?", "md?", "nvme?", "nvme?n?"]

# Read metrics about system load & uptime
[[inputs.system]]
  # no configuration

# Get the number of processes and group them by status
[[inputs.processes]]
  # no configuration

# Read metrics about disk usage by mount point
[[inputs.disk]]
  ## By default stats will be gathered for all mount points.
  ## Set mount_points will restrict the stats to only the specified mount points.
  mount_points = ["/"]
  ## Ignore mount points by filesystem type.
  # ignore_fs = ["tmpfs", "devtmpfs", "devfs", "iso9660", "overlay", "aufs", "squashfs"]

[[inputs.net]]
  interfaces = ["enp*", "eno*", "eth*", "ib*", "wl*"]

[[inputs.tail]]
  files = ["/tmp/influx-resources/influx-resources"]
  data_format = "influx"
EOF
################################################################################################################################################## End of Telegraf config
sudo systemctl unmask telegraf.service
sleep 1
sudo systemctl start telegraf.service

############################################################################################################################################## Exit
elif [[ "$SELECTION" == "4" ]]; then

exit 0

############################################################################################################################################### Stop & Uninstall TIG Stack
elif [[ "$SELECTION" == "5" ]]; then

#close firewall port for data ingress if open
#InfluxDB2
 yes y | sudo ufw delete $(sudo ufw status numbered |(grep 'influxdb2'|awk -F"[][]" '{print $2}')) && yes y | sudo ufw delete $(sudo ufw status numbered |(grep 'influxdb2'|awk -F"[][]" '{print $2}'))

# remove telegraf infux-resources script and cron job
sudo rm /etc/cron.d/infux-resources
sudo apt-get remove telegraf
sudo rm /usr/bin/infux-resources.sh

echo " stoping docker containers"
docker stop  $(docker ps -a -q)
sleep 5
echo ""
sudo rm -rf $HOME/.local/share/tig-stack/

#delete all remaining containers
docker remove telegraf
docker remove influxdb
docker remove grafana

fi
