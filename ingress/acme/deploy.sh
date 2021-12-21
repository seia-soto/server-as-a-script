#!/usr/bin/bash
set -x

: '
# by HoJeong Go

Usage:

    cat command | bash
    ./command

About:

    This script sets up acme.sh to easily get HTTPS certificates.

'

export DEBIAN_FRONTEND=noninteractive

log() {
    echo "[$(date)] $1: ${@:2}"

    [[ "$1" == "ERROR" ]] && exit 1
}

rootify() {
    if [ "$(id -u)" != "0" ]; then
        log ERROR "current account doesn't have root permission!"
    fi
}

rootify

log INFO "installing required packages"
apt-get update && apt-get upgrade -y
apt-get install -y ca-certificates util-linux curl openssl git \
    jq publicsuffix dnsutils

log INFO "creating new non-root user"
adduser --disabled-password --gecos "" ingress

log INFO "installing dehydrated"
# clone and reset
git clone https://github.com/lukas2511/dehydrated.git /opt/dehydrated
( cd /opt/dehydrated && git reset --hard $(git describe --tags --abbrev=0) )

# configure
mkdir -p /etc/dehydrated

cp /opt/dehydrated/docs/examples/{config,domains.txt} /etc/dehydrated
ln -s /opt/dehydrated/dehydrated /usr/local/sbin/dehydrated

CONFIG="/etc/dehydrated/config"

sed -i -e '/CHALLENGETYPE=/s/^#.*=.*/CHALLENGETYPE="dns-01"/' "$CONFIG"
sed -i -e '/DOMAINS_TXT=/s/^#.*=.*/DOMAINS_TXT="\/etc\/dehydrated\/domains.txt"/' "$CONFIG"
sed -i -e '/HOOK=/s/^#.*=.*/HOOK="\/etc\/dehydrated\/hooks\/entrypoint.sh"/' "$CONFIG"

# install utils
log INFO "installing additional hooks for challenges"
mkdir -p /etc/dehydrated/hooks

git clone https://github.com/socram8888/dehydrated-hook-cloudflare /etc/dehydrated/hooks/cloudflare

tee /etc/dehydrated/hooks/entrypoint.sh > /dev/null <<'EOT'
#!/usr/bin/env bash
ROOT="/etc/dehydrated/hooks"

# Put additional config for hooks here:
export CF_TOKEN=""

# Simple script which allows the use of multiple hooks
# Put hooks in the order you wish them to be called here:
# (Be sure to keep in mind the working directory *this* hook will be called from when specifying other hook paths.)
"${ROOT}/cloudflare/cf-hook.sh" "$@"
EOT

# make them executable
chmod +x /etc/dehydrated/hooks/entrypoint.sh
chmod +x /etc/dehydrated/hooks/cloudflare/cf-hook.sh

# postinstall
log INFO "finalizing"
chown -R ingress:ingress /etc/dehydrated

dehydrated --register --accept-terms
