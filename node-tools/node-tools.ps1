
# Copyright 2024 - Jadkins-Me
#
# This Code/Software is licensed to you under GNU AFFERO GENERAL PUBLIC LICENSE (GPL), Version 3
# Unless required by applicable law or agreed to in writing, the Code/Software distributed
# under the GPL Licence is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied. Please review the Licences for the specific language governing
# permissions and limitations relating to use of the Code/Software.

$safe_path = "safenode-manager"               # directory path for safenode-manager used by node-launchpad
$safe_json = "node_registry.json"             # name of JSON file we will pass, created by node-launchpad

# // NOTE : Changing things below this line might break functionality

$tools_version="0.2.1-July 2024"              #Version of script

##### Functions from Here ----- /// F U N C T I O N //// --------
function Show-Exit {
    Read-Host -Prompt "Done... Press Return to Close"
    Exit
}

##### Main from here -----// M A I N /////-----------

# Get the ProgramData directory path for installs which don't use C:\
$programdata_path = [Environment]::GetFolderPath("CommonApplicationData")

# Combine the path with safe_path
$full_path = Join-Path $programdata_path $safe_path 

# Check if the script is running with elevated privileges
    #if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
      #  Write-Host -ForegroundColor Yellow "WARNING: This script is not running with elevated privileges."
      #  Write-Host -ForegroundColor Yellow "Attempting to elevate permissions..."
    
      #  Start a new PowerShell process with elevated privileges
      #  Start-Process -FilePath PowerShell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`"" -Verb RunAs
      #  exit
    #}

# If the script is running with elevated privileges, continue with the rest of the script
#Write-Host -ForegroundColor Green "Script is running with elevated privileges. Proceeding..."

# Check if nodes.json exists
if (-not (Test-Path (Join-Path $full_path $safe_json))) {
    Write-Host -ForeGroundColor Red "Error: $safe_json was not found in $full_path"
    Write-Host -ForeGroundColor Yellow "Error: Are you sure you have nodes running on this machine ? "
    Show-Exit
} 

try {
    $jsonContent = Get-Content -Raw -Path (Join-Path $full_path $safe_json)
    $jsonData = $jsonContent | ConvertFrom-Json
    $numberofnodes = $jsonData.nodes.Count
} catch {
    Write-Host -ForegroundColor red "Error: An issue occured reading the JSON file " 
    Show-Exit
}

Write-Host -ForeGroundColor yellow "Node Tools - Version $tools_version"
Write-Host "Number of Nodes : $numberofnodes "

if ( $numberofnodes -lt 1 ) {
        Write-Host -foregroundcolor Red "Error: It looks like you have no nodes running"
        Show-Exit
}

if ( $numberofnodes -gt 50 ) {
        Write-Host -Foregroundcolor green "Warning: This script is only designed to run with up to 50 nodes, Y.M.M.V"
}

#Show help context
Write-Host -ForeGroundColor White "-=Help=-"
Write-Host -ForeGroundColor Yellow -NoNewline "Status" 
Write-Host "=The status of the node service, being ready(new node not started), running or stopped"
Write-Host -ForeGroundColor Yellow -NoNewline "Uptime" 
Write-Host "=How long the service has been running Days:Hours:Minutes"
Write-Host -ForeGroundColor Yellow -NoNewline "Owner" 
Write-Host "=Discord user ID returned from /get-id used in discord Autonomi channel"
Write-Host -ForeGroundColor Yellow -NoNewline  "Mode"
Write-Host "=If user, then node is running as user service, if system it will be running as system service"
Write-Host -ForeGroundColor Yellow -NoNewline  "Net"
Write-Host "=Network mode being used by node, UPNP or Home, or port-fwd if you have setup forwarding on router"
Write-Host -ForeGroundColor Yellow -NoNewline  "Port"
Write-Host "=UDP port the node is listening for connections on, for port-fwd this port must be fowarded from router"
Write-Host -ForeGroundColor Yellow -NoNewline  "Rec"
Write-Host "=Number of RECORDS stored on node made up of data chunks, and spends"
Write-Host -ForegroundColor Yellow -NoNewline  "Peer"
Write-Host "=Number of connections to Peers over UDP"
Write-Host -ForeGroundColor Yellow -NoNewline  "SC"
Write-Host "=Storage Cost, the value a client will be charged - a value of 0 means no estimate has been asked for yet"
Write-Host -ForeGroundColor Yellow -NoNewline  "RB"
Write-Host "=Rewards Balance, this will be nano's received and stored in node wallet"
Write-Host -ForeGroundColor Yellow -NoNewline  "FB"
Write-Host "=Forward Balance, this is nano's that have been earned and forwarded as part of beta rewards"
Write-Host -ForeGroundColor Yellow -NoNewline  "Ver"
Write-Host "=Version of node Software being run"
Write-Host ""

#init object to store extracted data
$serviceInfoList = @()

# Extract servicename and homenetwork for each object under 'nodes'
foreach ($node in $jsonData.nodes) {

    $metrics_port = if ($node.metrics_port) { $node.metrics_port } else { 0 }
    $node_port = if ($node.node_port) { $node.node_port } else { 0 }
    $owner = if ($node.owner) { $node.owner } else { 0 }
    $service_name = if ($node.service_name) { $node.service_name } else { 0 }
    $status = if ($node.status) { $node.status } else { 0 }
    $version = if ($node.version) { $node.version } else { 0 }
    $upnp = if ($node.upnp) { $node.upnp } else { 0 }
    $user_mode = if ($node.user_mode) { $node.user_mode } else { 0 }
    $home_network = if ($node.home_network) { $node.home_network } else { 0 }

    # Process Network Type
    if (( $upnp -eq 'true' )) {
        $network_type='upnp'
    } else {
        if (( $home_network -eq 'true' )) {
            $network_type='home'
        } else {
            $network_type='port-fwd'
        }
    }

    if (( $user_mode -eq 'true' )) {
            $user_mode="user"
    } else {
            $user_mode="system"
    }

    if ($status -eq "running") {
        #This should work? although not sure how various virus protection will flag this..
        $metricsUrl = "http://127.0.0.1:$metrics_port/metrics"

        try {
            # Make the request to the endpoint
            $response = Invoke-RestMethod -Uri $metricsUrl

            $rewards_balance=[regex]::Match($response, 'sn_node_current_reward_wallet_balance (\d+)').Groups[1].Value
            $rewards_forward=[regex]::Match($response, 'sn_node_total_forwarded_rewards (\d+)').Groups[1].Value
            $records=[regex]::Match($response, 'sn_networking_records_stored (\d+)').Groups[1].Value
            $store_cost=[regex]::Match($response, 'sn_networking_store_cost (\d+)').Groups[1].Value
            $con_peers=[regex]::Match($response, 'sn_networking_connected_peers (\d+)').Groups[1].Value
            $uptime_seconds=[regex]::Match($response, 'sn_node_uptime (\d+)').Groups[1].Value

            $ts = [timespan]::fromseconds($uptime_seconds)
            $uptime = $ts.ToString("dd\:hh\:mm")
            
        } catch {
            Write-Host "Error occurred Calling Metrics Endpoint $metricsUrl : $($_.Exception.Message)"
        }
    }

    # Create a custom object and add it to the array
    $serviceInfo = [PSCustomObject]@{
        service_name = $service_name
        status = $status
        owner = $owner
        mode = $user_mode
        net = $network_type           
        port = $node_port
        uptime = $uptime
        rec = $records
        peer = $con_peers
        sc = $store_cost
        rb = $rewards_balance
        fb = $rewards_forward
        version = $version
    }
    
    $serviceInfoList += $serviceInfo
}


# Print the service information in a table format
$serviceInfoList | Format-Table -property service_name,status,uptime,owner,mode,net,port,rec,peer,sc,rb,fb,version -AutoSize -Wrap

#pause, as the terminal will auto close
Show-Exit