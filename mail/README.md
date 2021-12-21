* This configuration is independent to other prefrences to run.
* The configuration is based on Poste.io.

# Mail

Before we start, **install docker and docker-compose**.
It isn't the problem whether you install from distro repository as it's just for running containers.

* Note that all compose files are set to version `'3'`.

## Certificates

We need two certificate:
- for reverse proxy
- for secured outboung mailing

### acme.sh

Visit [acme.sh](https://acme.sh) to get latest installation script, otherwise it's ok to use following command:

```sh
curl https://get.acme.sh | sh -s email=my@example.com
```

**DNS**

Append your DNS API information to `~/.acme.sh/account.conf` and run following command:

```sh
acme.sh --issue --domain domain.tld --dns dns_provider
```

* [How to use DNS API](https://github.com/acmesh-official/acme.sh/wiki/dnsapi)

### Nginx

After you get the certificate, replace all strings in `ingress/conf.d/domain.tld.conf` with your own domain.

* It's recommended to change filename too.

## Provisioning

**Poste.io**

Edit `poste/docker-compose.yml` and configure your own environment variables.
Note that rspamd and clamav might make high memory usage.

**Make services up**

Run following command to provision all things in current folder which README exists.

```sh
for d in ./*/ ; do (cd "$d" && docker-compose up -d); done
```
