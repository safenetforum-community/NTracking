#!/bin/bash
# Copyright 2024 - Jadkins-Me
#
# This Code/Software is licensed to you under GNU AFFERO GENERAL PUBLIC LICENSE (GPL), Version 3
# Unless required by applicable law or agreed to in writing, the Code/Software distributed
# under the GPL Licence is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied. Please review the Licences for the specific language governing
# permissions and limitations relating to use of the Code/Software.

# TODO : Need to detect Linux version better to work out what packages need to be installed.

# Check for root privileges

[ "${USER:-}" = "root" ] || exec sudo "$0" "$@"

echo "=== $BASH_SOURCE on $(hostname -f) at $(date)" >&2

# Define packages
packages=("jq" "awk" "grep" "sort" "head""mktemp" "curl" "unzip" "wget" "head" "sort")

# Install packages based on package manager
if command -v apt-get &>/dev/null; then
    apt-get update && apt-get install -y "${packages[@]}"
elif command -v yum &>/dev/null; then
    yum install -y "${packages[@]}"
elif command -v zypper &>/dev/null; then
    zypper install -y "${packages[@]}"
else
    echo "Unsupported Linux distribution." && exit 1
fi

echo "All required packages are installed, or not required by your linux Distribution - Errors above are OK"