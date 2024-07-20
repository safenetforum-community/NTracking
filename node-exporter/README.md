# node-exporter-adv.sh

This script is based on the original `influx-resources.sh`, but changes the functionality to be decoupled - You will need to be running a working influxDB and Grafana System, along with telegraf agent installed on the node machine.

1) No longer linked to safenode-manager or node-launchpad to query nodes.
2) Able to dynamically work out Autonomi node ports by query node JSON file.
3) If Metrics are enabled, will use those to enhance stat being reported.
4) Works along side the original script, using a new instance called `nodes_adv`
5) Has it's own Grafana Dashboard, that works allong side `influx-resources.sh`
6) Where available on the host, makes use of parallel processing, to allow in-excess of 1000 nodes to be queried in under 5 minutes (subject to CPU load and type)

## Pre-Requisits

Sorry, this currently only works on Linux, a working Powershell script is in development.

The code makes use of a few standard BASH shell utilities, that need to be installed via `sudo` or `root`.  A script is provided called `pre-req.sh` which will attempty to install all the required packages.

## Install

There are 4 parts to getting the script working;

### 1) download the script to `/usr/local/bin` and make executable
        
        ```
        sudo su -
        curl -o /usr/local/bin/node-exporter-adv.sh https://raw.githubusercontent.com/jadkins-me/NTracking/main/node-exporter/node-exporter-adv.sh
        chmod +x /usr/local/bin/node-exporter-adv.sh
        ```
        
### 2) update the cron job to include the new script

        `sudo nano /etc/cron.d/influx_resources`

    add the line to the file, ensure the username (admin) is set correctly to either the user account you login with, or to root. */10 tells the script to be run every 10 minutes, you should not drop that below */5 (every 5 minutes), but you may increase to */30 (every 30 minutes) depending on power of your host.

        `*/10 * * * * admin /usr/bin/mkdir -p /tmp/influx-resources && /bin/bash /usr/local/bin/node-exporter-adv.sh > /tmp/influx-resources/influx-node-adv`

    Save and Exit - Ctrl+X, then Y to save

### 3) update telegraf configuration to scrape the output of the script

        'sudo nano /etc/telegraf/telegraf.conf`

    ensure the following is at the bottom of the configuration.

        ```
        [[inputs.tail]]
          files = ["/tmp/influx-resources/influx-resources","/tmp/influx-resources/influx-node-adv"]
          data_format = "influx"
          from_beginning = true
          watch_method = "poll"
        ```
        
    Save and Exit - Ctrl+X, then Y to save

    Then restart Telegraf to read the new configuration
        
        'sudo systemctl restart telegraf`

### 4) install the new grafana dashboard

    Connect to the Grafan Dashboard

    Select Import Dashboard, and copy and paste the raw source from;

        `https://raw.githubusercontent.com/jadkins-me/NTracking/main/node-exporter/01-grafana-dashboard-nodes_adv`

    When prompted for a Datasource, select the existing instance of InfluxDB
