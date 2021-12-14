#!/usr/bin/bash
: '
# by HoJeong Go

Usage:

    command $size $name $location

    $size {string} The size of zpool to create
    $name {string} The name of zpool and storage pool
    $location {string} The location of storage pool binary file to create

About:

    The LXD daemon, itself does not allow creating internally managed zpool storage pool.
    Instead, this script allows you to create zpool with binary file easily.

'

log() {
    echo "[$(date)] $1: ${@:2}"

    [[ "$1" == "ERROR" ]] && exit 1
}

exec() {
    echo "> $@"

    "$@"
}

size="${1}"
name="${2}"
location="${3}"

[[ ! -z "$(lxc storage list --format csv | grep -Eo ${name},)" ]] && log ERROR "stroage pool already exists";

log INFO "creating new binary file with truncate on ${location}"
exec sudo truncate "-s ${size}" "${location}"

log INFO "creating new zpool called ${name}"
exec sudo zpool create "${name}" "${location}"

log INFO "registering storage pool to lxc"
exec lxc storage create "${name}" zfs "source=${name}"
