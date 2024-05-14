#!/usr/bin/env bash

set -euo pipefail

lutris_version=$(curl -s "https://api.github.com/repos/lutris/lutris/tags" | jq -r '.[0].name')
lutris_version_stripped="${lutris_version:1}"
steam_url='https://cdn.cloudflare.steamstatic.com/client/installer/steam.deb'

# Build the lutris download command.
wget -O /tmp/lutris_latest.deb -q "https://github.com/lutris/lutris/releases/download/${lutris_version}/lutris_${lutris_version_stripped}_all.deb"

# Download the latest Steam deb.
echo 'Downloading Steam...'
wget -O /tmp/steam_latest.deb -q "$steam_url"

echo "Installing Steam..."
sudo dpkg -i /tmp/steam_latest.deb

echo "Installing Lutris..."
sudo dpkg -i /tmp/lutris_latest.deb
