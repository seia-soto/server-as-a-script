#!/usr/bin/bash
: '
# by HoJeong Go

Usage:
    command $interface $permanent

    $interface {string} The name of interface

About:

    This script removes the patched service from current system easily.
    As you remove the patch, you are not allowed to communicate between container with DNS anymore after reboot.
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
service="lxd-dns-${interface}"

[[ -z $interface ]] && log ERROR "interface not found";

log INFO "disabling ${service}"

exec sudo systemctl stop "$service"
exec sudo systemctl disable "$service"

log INFO "removing /etc/systemd/system/${service}.service"

exec sudo rm "/etc/systemd/system/${service}.service"
exec sudo systemctl daemon-reload
