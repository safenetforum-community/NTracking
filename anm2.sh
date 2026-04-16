#!/usr/bin/env bash
set -euo pipefail

# --- Configuration ---
NODE_COUNT=10
STAGGER_DELAY=30
REWARDS_ADDRESS=""
NODE_PORT_START=12000
DATA_BASE_DIR="$HOME/.ant-node"
LOG_LEVEL="info"
LOG_MAX_FILES=7
RAM_LOG_DIR="$HOME/.ant-node/logs-ram"
RAM_LOG_SIZE="512M"
SERVICE_PREFIX="ant-node"
BINARY_NAME="ant-node"
GITHUB_REPO="WithAutonomi/ant-node"

# --- Helpers ---
msg_box() { whiptail --title "Ant Node Manager" --msgbox "$1" 12 70; }
yes_no()  { whiptail --title "Ant Node Manager" --yesno "$1" 12 70; }

check_deps() {
    if ! command -v whiptail &>/dev/null; then
        echo "ERROR: whiptail is required. Install: sudo apt install whiptail"
        exit 1
    fi
    if ! command -v curl &>/dev/null; then
        echo "ERROR: curl is required. Install: sudo apt install curl"
        exit 1
    fi
    if [[ $EUID -eq 0 ]]; then
        echo "ERROR: Do not run as root. Services use systemd --user."
        exit 1
    fi
}

detect_arch() {
    case "$(uname -m)" in
        x86_64)  echo "x64" ;;
        aarch64) echo "arm64" ;;
        *) msg_box "Unsupported architecture: $(uname -m)"; return 1 ;;
    esac
}

get_latest_tag() {
    curl -sL -o /dev/null -w '%{url_effective}' \
        "https://github.com/${GITHUB_REPO}/releases/latest" \
        | grep -oP '[^/]+$'
}

# --- Download & Install ---
download_and_extract() {
    local tag="$1"
    local arch
    arch=$(detect_arch) || return 1

    local filename="ant-node-cli-linux-${arch}.tar.gz"
    local url="https://github.com/${GITHUB_REPO}/releases/download/${tag}/${filename}"
    local tmp_dir
    tmp_dir=$(mktemp -d)

    if ! curl -sL "$url" -o "${tmp_dir}/${filename}"; then
        rm -rf "$tmp_dir"
        msg_box "Download failed.\nURL: ${url}"
        return 1
    fi

    if ! tar -xzf "${tmp_dir}/${filename}" -C "$tmp_dir"; then
        rm -rf "$tmp_dir"
        msg_box "Failed to extract archive."
        return 1
    fi

    # Find the binary (named ant-node in the tarball)
    local binary
    binary=$(find "$tmp_dir" -type f -name "ant-node" | head -1)
    if [[ -z "$binary" ]]; then
        binary=$(find "$tmp_dir" -type f -executable ! -name "*.tar.gz" | head -1)
    fi
    if [[ -z "$binary" ]]; then
        rm -rf "$tmp_dir"
        msg_box "Could not find binary in archive."
        return 1
    fi

    # Store master copy in base dir
    mkdir -p "$DATA_BASE_DIR"
    cp "$binary" "${DATA_BASE_DIR}/${BINARY_NAME}"
    chmod +x "${DATA_BASE_DIR}/${BINARY_NAME}"

    # Copy bootstrap_peers.toml if present
    local peers_file
    peers_file=$(find "$tmp_dir" -name "bootstrap_peers.toml" | head -1)
    if [[ -n "$peers_file" ]]; then
        cp "$peers_file" "${DATA_BASE_DIR}/bootstrap_peers.toml"
    fi

    rm -rf "$tmp_dir"
}

install_binary() {
    if [[ -x "${DATA_BASE_DIR}/${BINARY_NAME}" ]]; then
        return 0
    fi

    if ! yes_no "ant-node binary not found.\n\nDownload the latest release from GitHub?"; then
        msg_box "ant-node is required. Exiting."
        return 1
    fi

    local tag
    tag=$(get_latest_tag) || { msg_box "Failed to fetch latest release tag."; return 1; }

    {
        echo "10"; echo "Downloading ant-node ${tag}..."
        download_and_extract "$tag" 2>&1
        echo "100"; echo "Done."
    } | whiptail --title "Installing ant-node" --gauge "Downloading..." 8 60 0

    if [[ ! -x "${DATA_BASE_DIR}/${BINARY_NAME}" ]]; then
        msg_box "Installation failed. Binary not found."
        return 1
    fi

    local version
    version=$("${DATA_BASE_DIR}/${BINARY_NAME}" --version 2>/dev/null | head -1)
    msg_box "ant-node installed successfully.\n\nVersion: ${version}\nTag: ${tag}"
}

# --- RAM Logging (tmpfs) ---
setup_ram_logs() {
    mkdir -p "$RAM_LOG_DIR"

    # Check if already mounted
    if mountpoint -q "$RAM_LOG_DIR" 2>/dev/null; then
        return 0
    fi

    # Mount tmpfs (needs sudo)
    if ! sudo mount -t tmpfs -o size="${RAM_LOG_SIZE}",uid="$(id -u)",gid="$(id -g)",mode=0755 tmpfs "$RAM_LOG_DIR"; then
        msg_box "Failed to mount tmpfs at ${RAM_LOG_DIR}.\nLogs will use disk instead."
        return 1
    fi

    # Add fstab entry if not present so it persists across reboots
    local fstab_line="tmpfs ${RAM_LOG_DIR} tmpfs size=${RAM_LOG_SIZE},uid=$(id -u),gid=$(id -g),mode=0755,noatime 0 0"
    if ! grep -qF "$RAM_LOG_DIR" /etc/fstab 2>/dev/null; then
        echo "$fstab_line" | sudo tee -a /etc/fstab >/dev/null
    fi

    return 0
}

unmount_ram_logs() {
    if mountpoint -q "$RAM_LOG_DIR" 2>/dev/null; then
        sudo umount "$RAM_LOG_DIR" 2>/dev/null || true
    fi
    # Remove fstab entry
    if grep -qF "$RAM_LOG_DIR" /etc/fstab 2>/dev/null; then
        sudo sed -i "\|${RAM_LOG_DIR}|d" /etc/fstab
    fi
}

# --- Systemd Service ---
create_service() {
    local index="$1"
    local port="$2"
    local node_dir="$3"
    local service_name="${SERVICE_PREFIX}-${index}"
    local service_dir="$HOME/.config/systemd/user"
    local bin_path="${node_dir}/${BINARY_NAME}"
    local log_dir="${RAM_LOG_DIR}/node-${index}"

    mkdir -p "$service_dir" "$log_dir"

    cat > "${service_dir}/${service_name}.service" <<UNIT
[Unit]
Description=Ant Node ${index}
After=network-online.target

[Service]
Type=simple
ExecStart=${bin_path} \\
    --root-dir ${node_dir} \\
    --port ${port} \\
    --rewards-address ${REWARDS_ADDRESS} \\
    --upgrade-channel stable \\
    --stop-on-upgrade \\
    --enable-logging \\
    --log-level ${LOG_LEVEL} \\
    --log-dir ${log_dir} \\
    --log-max-files ${LOG_MAX_FILES}
Restart=on-failure
RestartSec=10s

[Install]
WantedBy=default.target
UNIT
}

# --- Setup Nodes ---
setup_nodes() {
    # Prompt for rewards address
    local addr
    addr=$(whiptail --title "Rewards Address" \
        --inputbox "Enter your EVM wallet address (0x...):" 10 70 "$REWARDS_ADDRESS" \
        3>&1 1>&2 2>&3) || return
    if [[ ! "$addr" =~ ^0x[0-9a-fA-F]{40}$ ]]; then
        msg_box "Invalid EVM address.\nMust be 0x followed by 40 hex characters."
        return
    fi
    REWARDS_ADDRESS="$addr"

    # Prompt for node count
    local count
    count=$(whiptail --title "Node Count" \
        --inputbox "How many nodes to run?" 10 40 "$NODE_COUNT" \
        3>&1 1>&2 2>&3) || return
    if [[ ! "$count" =~ ^[1-9][0-9]*$ ]] || (( count > 50 )); then
        msg_box "Enter a number between 1 and 50."
        return
    fi
    NODE_COUNT="$count"

    # Confirm
    local summary=""
    summary+="Nodes:          ${NODE_COUNT}\n"
    summary+="Rewards:        ${REWARDS_ADDRESS}\n"
    summary+="Ports:          ${NODE_PORT_START}-$((NODE_PORT_START + NODE_COUNT - 1))\n"
    summary+="Data dir:       ${DATA_BASE_DIR}/node-N/\n"
    summary+="Logs:           ${RAM_LOG_DIR}/node-N/ (tmpfs/RAM)\n"
    summary+="RAM log size:   ${RAM_LOG_SIZE} total\n"
    summary+="Log level:      ${LOG_LEVEL}\n"
    summary+="Channel:        stable (auto-upgrade)\n"
    summary+="Start delay:    ${STAGGER_DELAY}s between nodes"

    if ! yes_no "Deploy with these settings?\n\n${summary}"; then
        return
    fi

    # Stop any existing nodes first
    stop_all_quiet

    # Set up RAM-based logging
    setup_ram_logs

    {
        echo "5"; echo "Preparing node directories..."

        systemctl --user daemon-reload 2>/dev/null || true

        local i port node_dir
        for (( i=1; i<=NODE_COUNT; i++ )); do
            port=$((NODE_PORT_START + i - 1))
            node_dir="${DATA_BASE_DIR}/node-${i}"
            mkdir -p "$node_dir"

            # Copy binary and bootstrap peers into node dir
            cp "${DATA_BASE_DIR}/${BINARY_NAME}" "${node_dir}/${BINARY_NAME}"
            chmod +x "${node_dir}/${BINARY_NAME}"
            if [[ -f "${DATA_BASE_DIR}/bootstrap_peers.toml" ]]; then
                cp "${DATA_BASE_DIR}/bootstrap_peers.toml" "${node_dir}/bootstrap_peers.toml"
            fi

            create_service "$i" "$port" "$node_dir"

            local pct=$(( 5 + (i * 30 / NODE_COUNT) ))
            echo "$pct"; echo "Prepared node ${i}..."
        done

        echo "35"; echo "Reloading systemd..."
        systemctl --user daemon-reload

        echo "40"; echo "Starting ${NODE_COUNT} nodes (${STAGGER_DELAY}s between each)..."

        for (( i=1; i<=NODE_COUNT; i++ )); do
            systemctl --user enable --now "${SERVICE_PREFIX}-${i}.service" 2>&1
            local pct=$(( 40 + (i * 55 / NODE_COUNT) ))
            echo "$pct"; echo "Started node ${i}..."
            if (( i < NODE_COUNT )); then
                sleep "$STAGGER_DELAY"
            fi
        done

        echo "98"; echo "Settling..."
        sleep 3
        echo "100"; echo "Done."
    } | whiptail --title "Setting Up Nodes" --gauge "Deploying ant-nodes..." 8 70 0

    show_status
}

# --- Status ---
show_status() {
    local status="" i svc active_count=0 total=0

    # Detect how many nodes are configured
    for (( i=1; i<=50; i++ )); do
        svc="${SERVICE_PREFIX}-${i}.service"
        if systemctl --user is-enabled --quiet "$svc" 2>/dev/null; then
            total=$i
        fi
    done

    if (( total == 0 )); then
        msg_box "No nodes are configured."
        return
    fi

    # Get version from master binary
    local version="unknown"
    if [[ -x "${DATA_BASE_DIR}/${BINARY_NAME}" ]]; then
        version=$("${DATA_BASE_DIR}/${BINARY_NAME}" --version 2>/dev/null | head -1)
    fi

    status="Installed version: ${version}\n"
    status+="Configured nodes: ${total}\n"
    status+="─────────────────────────────────\n"

    for (( i=1; i<=total; i++ )); do
        svc="${SERVICE_PREFIX}-${i}.service"
        local state
        if systemctl --user is-active --quiet "$svc" 2>/dev/null; then
            state="RUNNING"
            (( active_count++ ))
        else
            local svc_state
            svc_state=$(systemctl --user show -p ActiveState --value "$svc" 2>/dev/null || echo "unknown")
            if [[ "$svc_state" == "failed" ]]; then
                state="FAILED"
            else
                state="STOPPED"
            fi
        fi
        status+="  Node ${i}: ${state}\n"
    done

    status+="─────────────────────────────────\n"
    status+="Active: ${active_count}/${total}"

    whiptail --title "Node Status" --scrolltext --msgbox "$status" 24 50
}

# --- Stop & Cleanup ---
stop_all_quiet() {
    for (( i=1; i<=50; i++ )); do
        local svc="${SERVICE_PREFIX}-${i}.service"
        if systemctl --user is-enabled --quiet "$svc" 2>/dev/null; then
            systemctl --user stop "$svc" 2>/dev/null || true
            systemctl --user disable "$svc" 2>/dev/null || true
        fi
    done
}

stop_nodes() {
    if ! yes_no "Stop all running ant-node services?"; then
        return
    fi
    stop_all_quiet
    systemctl --user daemon-reload 2>/dev/null || true
    msg_box "All nodes stopped and disabled."
}

cleanup_all() {
    local warning="This will PERMANENTLY:\n\n"
    warning+="  - Export logs to ~/ant-node-logs-*.tar.gz\n"
    warning+="  - Stop all ant-node services\n"
    warning+="  - Remove all systemd service files\n"
    warning+="  - Unmount RAM log tmpfs and remove fstab entry\n"
    warning+="  - Delete ALL data in ${DATA_BASE_DIR}\n"
    warning+="    (binaries, logs, node data, keys)\n\n"
    warning+="This cannot be undone."

    if ! yes_no "$warning"; then
        return
    fi
    if ! yes_no "Are you absolutely sure?\n\nAll node data will be permanently deleted."; then
        return
    fi

    # Export logs before cleanup (outside the pipe so we keep the path)
    local archive=""
    if [[ -d "$RAM_LOG_DIR" ]] && [[ -n "$(ls -A "$RAM_LOG_DIR" 2>/dev/null)" ]]; then
        archive=$(do_export_logs)
    fi

    {
        echo "20"; echo "Stopping all nodes..."
        stop_all_quiet

        echo "50"; echo "Removing service files..."
        rm -f "$HOME/.config/systemd/user/${SERVICE_PREFIX}"-*.service
        systemctl --user daemon-reload 2>/dev/null || true

        echo "70"; echo "Unmounting RAM logs..."
        unmount_ram_logs

        echo "85"; echo "Deleting ${DATA_BASE_DIR}..."
        rm -rf "$DATA_BASE_DIR"

        echo "100"; echo "Done."
    } | whiptail --title "Full Cleanup" --gauge "Removing everything..." 8 60 0

    local result="All nodes, services, and data have been removed."
    if [[ -n "$archive" ]]; then
        local size
        size=$(du -h "$archive" 2>/dev/null | cut -f1)
        result+="\n\nLogs exported to:\n${archive}\nSize: ${size}"
    fi
    msg_box "$result"
}

# --- Export Logs ---
# Core export logic, returns archive path via stdout
do_export_logs() {
    local export_dir="$HOME"
    local timestamp
    timestamp=$(date +%Y%m%d-%H%M%S)
    local archive_name="ant-node-logs-${timestamp}.tar.gz"
    local tmp_dir
    tmp_dir=$(mktemp -d)

    local i node_log_dir combined
    for node_log_dir in "$RAM_LOG_DIR"/node-*/; do
        [[ -d "$node_log_dir" ]] || continue
        i=$(basename "$node_log_dir")
        combined="${tmp_dir}/${i}.log"
        find "$node_log_dir" -type f -name "*.log*" -print0 \
            | xargs -0 ls -1t 2>/dev/null \
            | tac \
            | xargs cat > "$combined" 2>/dev/null || true
    done

    tar -czf "${export_dir}/${archive_name}" -C "$tmp_dir" . 2>/dev/null
    rm -rf "$tmp_dir"
    echo "${export_dir}/${archive_name}"
}

export_logs() {
    if [[ ! -d "$RAM_LOG_DIR" ]] || [[ -z "$(ls -A "$RAM_LOG_DIR" 2>/dev/null)" ]]; then
        msg_box "No logs found at ${RAM_LOG_DIR}."
        return
    fi

    local archive
    {
        echo "10"; echo "Combining log files per node..."
    } | whiptail --title "Export Logs" --gauge "Exporting logs..." 8 60 0

    archive=$(do_export_logs)

    local size
    size=$(du -h "$archive" 2>/dev/null | cut -f1)
    msg_box "Logs exported to:\n\n${archive}\n\nSize: ${size}"
}

# --- Main Menu ---
main_menu() {
    while true; do
        local choice
        choice=$(whiptail --title "Ant Node Manager" \
            --menu "Manage your Autonomi ant-nodes" 18 60 6 \
            "1" "Setup & Start Nodes" \
            "2" "Node Status & Version" \
            "3" "Export Logs" \
            "4" "Stop All Nodes" \
            "5" "Stop & Remove Everything" \
            "6" "Exit" \
            3>&1 1>&2 2>&3) || break

        case "$choice" in
            1) setup_nodes ;;
            2) show_status ;;
            3) export_logs ;;
            4) stop_nodes ;;
            5) cleanup_all ;;
            6) break ;;
        esac
    done
}

# --- Entry ---
check_deps
install_binary || exit 1
main_menu
