#!/usr/bin/bash
: '
# by HoJeong Go

Usage:
    command $interface $permanent

    $interface {string} The name of interface
    $permanent {string} The string starts with y (or Y) if you need to install action as a service

About:

    This script patches system to connect between LXD containers easily.
    After patching the system, you can query with container name between each container.

    -- Test --
    $ ping test2

    (ping result to test2)

    -- Test2 --
    $ ping test

    (ping result to test)

    * To keep the patched state even after reboot of LXD service or host computer, you need to install this action as a service to patch system on interface start.
    * This command automates the following document: https://linuxcontainers.org/lxd/docs/master/networks#integration-with-systemd-resolved
'

log() {
    echo "[$(date)] $1: ${@:2}"

    [[ "$1" == "ERROR" ]] && exit 1
}

exec() {
    echo "> $@"

    "$@"
}

interface="${1}"
temporal="${2}"

address=$(lxc network get ${interface} ipv4.address | grep -Eo '[0-9]+.[0-9]+.[0-9]+.[0-9]+')

[[ -z $interface || -z $address ]] && log ERROR "interface not found";

exec sudo resolvectl dns "${interface}" "${address}"
exec sudo resolvectl domain "${interface}" "~${interface}"

# exit here if temporal patch mode set
[[ ! $temporal =~ ^[yY].*$ ]] && exit 0;

log INFO "installing service to /etc/systemd/system/lxd-dns-${interface}.service"

sudo tee -a "/etc/systemd/system/lxd-dns-${interface}.service" > /dev/null <<EOT
[Unit]
Description=LXD per-link DNS configuration for ${interface}
BindsTo=sys-subsystem-net-devices-${interface}.device
After=sys-subsystem-net-devices-${interface}.device

[Service]
Type=oneshot
ExecStart=/usr/bin/resolvectl dns ${interface} ${address}
ExecStart=/usr/bin/resolvectl domain ${interface} '~${interface}'

[Install]
WantedBy=sys-subsystem-net-devices-${interface}.device
EOT

log INFO "starting service"

exec sudo systemctl daemon-reload
exec sudo systemctl enable --now "lxd-dns-${interface}"
