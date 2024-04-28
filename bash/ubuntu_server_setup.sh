#!/usr/bin/env bash
#
set -euo pipefail

# Use sudo without password.
echo "$USER ALL=(ALL) NOPASSWD:ALL" | sudo tee --append /etc/sudoers.d/$USER

# time / date settings.
sudo timedatectl set-timezone America/New_York
sudo timedatectl set-local-rtc 1
sudo timedatectl set-ntp true

# disable ip6
sudo sysctl net.ipv6.conf.all.disable_ipv6=1
sudo sysctl net.ipv6.conf.default.disable_ipv6=1
echo "net.ipv6.conf.all.disable_ipv6=1" | sudo tee --append /etc/sysctl.conf
echo "net.ipv6.conf.default.disable_ipv6=1" | sudo tee --append /etc/sysctl.conf

# Install packages
sudo apt update
sudo apt install -y \
    anacron \
    apt-transport-https \
    bwm-ng \
    ca-certificates \
    curl \
    dnsutils \
    git \
    gnupg \
    htop \
    iftop \
    iotop \
    logrotate \
    lsb-release \
    make \
    nano \
    bash-completion \
    net-tools \
    sysstat \
    software-properties-common \
    vnstat \
    vim \
    tmux

# speed up boot times
# https://askubuntu.com/a/979493
# speed up booting by not letting networkd wait around for unconfigured interfaces
sudo systemctl disable systemd-networkd-wait-online.service
sudo systemctl mask systemd-networkd-wait-online.service

# remove snaps.
if [ -f /usr/bin/snap ]; then
    snaps=$(snap list | awk 'NR>1 {print $1}')
   # Need to remove all other snap packages before removing snapd.
   if [ -z "$snaps" ]; then
        for snap in $snaps; do
            if [ "$snap" != 'snapd' ]; then
                sudo snap remove "$snap"
                echo "Removed snap package $snap"
            fi
        done
        # now remove snapd.
        sudo snap remove snapd
        echo "Removed snap package snapd."
    fi
    # Blow that garbage away.
    sudo apt purge snapd -y
fi

# finally update the system.
sudo apt update && sudo apt dist-upgrade -y
