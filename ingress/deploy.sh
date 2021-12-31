#!/usr/bin/bash
set -x

: '
# by HoJeong Go

Usage:

    cat command | bash
    ./command

About:

    This script setup Nginx on your Debian-based Linux distros.
    With following features:
        - use of cloudflare/zlib#latest
        - use of openssl/openssl#v3.x
'

export DEBIAN_FRONTEND=noninteractive

_pwd="$(pwd)"
_log="$(pwd)/$(date).log"

log() {
    echo "[$(date)] $1: ${@:2}"

    [[ "$1" == "ERROR" ]] && exit 1
}

back() {
    cd "${_pwd}"
}

gh_tags() {
    echo $(
        curl -sL "https://api.github.com/repos/${1}/git/refs/tags" |\
        jq -c -r 'reverse | .[]'
    )
}

gh_archive() {
    log INFO "fetching ${1}#${2} to ${_tmp}/${3}"

    mkdir -p "${_tmp}/${3}"

    curl -sL "https://github.com/${1}/archive/${2}.tar.gz" -o "${_tmp}/${3}.tar.gz"
    tar -xf "${_tmp}/${3}.tar.gz" -C "${_tmp}/${3}" --strip-components=1
}

gh_clone() {
    log INFO "fetching ${1}#${2} to ${_tmp}/${3}"

    git clone "https://github.com/${1}.git" "${_tmp}/${3}"

    cd "${_tmp}/${3}"

    git checkout "${2}"
    git submodule update --init --recursive

    back
}

rootify() {
    if [ "$(id -u)" != "0" ]; then
        log ERROR "current account doesn't have root permission!"
    fi
}

rootify

log INFO "preparing environment"
_tmp="$(mktemp -d)"
_configure_args=""

log INFO "creating new non-root user"
adduser --disabled-password --gecos "" ingress

log INFO "installing required packages"
apt-get update && apt-get upgrade -y
apt-get install -y ca-certificates lsb-release util-linux build-essential curl jq git \
    libgd-dev libxml2-dev libpcre3-dev libxslt1-dev

# fetch openssl
_repo="openssl/openssl"
_ref="refs/tags/openssl-3.0.0"

for i in $(gh_tags $_repo); do
    _ref_test=$(echo "${i}" | jq -c -r ".ref")

    if [[ $_ref_test =~ ^refs\/tags\/openssl-[0-9]+.[0-9]+.[0-9]+$ ]]; then
        _ref="$_ref_test"

        break
    fi
done

gh_archive $_repo $_ref "openssl"
_configure_args+="--with-openssl=${_tmp}/openssl "

# fetch zlib
_repo="cloudflare/zlib"
_ref="v1.2.8"

for i in $(gh_tags $_repo); do
    _ref_test=$(echo "${i}" | jq -c -r ".ref")

    if [[ $_ref_test =~ ^refs\/tags\/v[0-9]+.[0-9]+.[0-9]+$ ]]; then
        _ref="$_ref_test"

        break
    fi
done

gh_archive $_repo $_ref "zlib"
_configure_args+="--with-zlib=${_tmp}/zlib "

#fetch ngx_brotli
_repo="google/ngx_brotli"
_ref="v1.0.0rc"

for i in $(gh_tags $_repo); do
    _ref_test=$(echo "${i}" | jq -c -r ".ref")

    if [[ $_ref_test =~ ^refs\/tags\/v[0-9]+.[0-9]+.[0-9]+(?:rc)?$ ]]; then
        _ref="$_ref_test"

        break
    fi
done

gh_clone $_repo $_ref "ngx_brotli"
_configure_args+="--add-module=${_tmp}/ngx_brotli"

# fetch nginx
_nginx_ref="nginx-1.21.4"
_nginx_ref_test="$(curl -sL 'http://nginx.org/en/download.html' | grep -Eo 'nginx-[0-9]+.[0-9]+.[0-9]+' | head -1)"

# double check version literal
[[ $_nginx_ref_test =~ ^nginx-[0-9]+.[0-9]+.[0-9]+$ ]] && _nginx_ref="$_nginx_ref_test";

mkdir -p "${_tmp}/nginx"

curl -sL "http://nginx.org/download/${_nginx_ref}.tar.gz" -o "${_tmp}/nginx.tar.gz"
tar -xf "${_tmp}/nginx.tar.gz" -C "${_tmp}/nginx" --strip-components=1

# pre-configure the environment
log INFO "configuring package"
mkdir -p /var/log/nginx

chmod 640 /var/log/nginx

# compile nginx
cd "${_tmp}/nginx"

./configure \
    --build="HoJeong Go <seia@outlook.kr>" \
    --prefix=/usr/share/nginx \
    --sbin-path=/usr/sbin/nginx \
    --conf-path=/etc/nginx/nginx.conf \
    --modules-path=/usr/lib/nginx/modules \
    --http-log-path=/var/log/nginx/access.log \
    --error-log-path=/var/log/nginx/error.log \
    --lock-path=/var/lock/nginx.lock \
    --pid-path=/var/run/nginx.pid \
    --http-client-body-temp-path=/var/lib/nginx/body \
    --http-fastcgi-temp-path=/var/lib/nginx/fastcgi \
    --http-proxy-temp-path=/var/lib/nginx/proxy \
    --http-scgi-temp-path=/var/lib/nginx/scgi \
    --http-uwsgi-temp-path=/var/lib/nginx/uwsgi \
    --with-compat \
    --with-debug \
    --with-http_mp4_module \
    --with-http_stub_status_module \
    --with-http_realip_module \
    --with-http_auth_request_module \
    --with-http_dav_module \
    --with-http_addition_module \
    --with-http_gunzip_module \
    --with-http_gzip_static_module \
    --with-http_image_filter_module=dynamic \
    --with-http_sub_module \
    --with-http_xslt_module=dynamic \
    --with-stream=dynamic \
    --with-stream_ssl_module \
    --with-mail=dynamic \
    --with-mail_ssl_module \
    --with-file-aio \
    --with-threads \
    --with-http_v2_module \
    --with-http_ssl_module \
    --with-pcre-jit \
    --with-cc-opt="-g -O2 -fstack-protector-strong -Wformat -Werror=format-security -fPIC -Wdate-time -D_FORTIFY_SOURCE=2" \
    ${_configure_args}
make
make install

back

# post configuration
mkdir -p /var/lib/nginx/{body,fastcgi,proxy,scgi,uwsgi}
mkdir -p /etc/nginx/{conf.d,snippets}

sed -i -e "/#user/s/^#.*/user ingress/" /etc/nginx/nginx.conf

# install service
tee -a /lib/systemd/system/nginx.service > /dev/null <<'EOT'
[Unit]
Description=The NGINX HTTP and reverse proxy server
After=syslog.target network-online.target remote-fs.target nss-lookup.target
Wants=network-online.target

[Service]
Type=forking
PIDFile=/run/nginx.pid
ExecStartPre=/usr/sbin/nginx -t
ExecStart=/usr/sbin/nginx
ExecReload=/usr/sbin/nginx -s reload
ExecStop=/bin/kill -s QUIT $MAINPID
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOT
systemctl daemon-reload
