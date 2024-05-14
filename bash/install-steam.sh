#!/usr/bin/env bash

set -euo pipefail

lutris_version=$(curl -s "https://api.github.com/repos/lutris/lutris/tags" | jq -r '.[0].name')
lutris_version_stripped="${lutris_version:1}"
steam_url='https://cdn.cloudflare.steamstatic.com/client/installer/steam.deb'
download_dir='/tmp/steam'

if ! (grep -q "Ubuntu" /etc/os-release || grep -q "Debian" /etc/os-release); then
    echo "Not running Ubuntu or Debian, exiting..." 
    exit 1
fi

mkdir -p "$download_dir"

# Download the latest lutris deb.
echo "Downloading Lutris..."
curl -L -o "$download_dir/lutris_latest.deb" -q "https://github.com/lutris/lutris/releases/download/${lutris_version}/lutris_${lutris_version_stripped}_all.deb"

# Download the latest Steam deb.
echo 'Downloading Steam...'
curl -L -o "$download_dir/steam_latest.deb" -q "$steam_url"

echo "Installing dependencies..."
sudo apt update && sudo apt install -y python3-lxml python3-setproctitle python3-magic cabextract p7zip fluid-soundfont-gs mesa-utils vulkan-tools

echo "Installing Steam..."
sudo dpkg -i "$download_dir/steam_latest.deb"

echo "Installing Lutris..."
sudo dpkg -i "$download_dir/lutris_latest.deb"
