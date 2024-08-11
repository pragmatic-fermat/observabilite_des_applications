

## Installation de consul server

Commencons à installer le binaire du serveur Consul sur notre serveur principal (IP_srv)
```
apt-get update -y
apt-get install unzip gnupg2 curl wget -y
wget https://releases.hashicorp.com/consul/1.8.4/consul_1.8.4_linux_amd64.zip
unzip consul_1.8.4_linux_amd64.zip
mv consul /usr/local/bin/
```

Vérifions :
```
consul --version
```

Continuons :

```
groupadd --system consul
useradd -s /sbin/nologin --system -g consul consul
mkdir -p /var/lib/consul
mkdir /etc/consul.d
chown -R consul:consul /var/lib/consul
chmod -R 775 /var/lib/consul
chown -R consul:consul /etc/consul.d
```

Notez l'IP publique de votre serveur :
```
ip a  show eth0
```

Creer le fichier '/etc/systemd/system/consul.service' :
```
[Unit]
Description=Consul Service Discovery Agent
After=network-online.target
Wants=network-online.target
[Service]
Type=simple
User=consul
Group=consul
ExecStart=/usr/local/bin/consul agent -config-dir=/etc/consul.d
ExecReload=/bin/kill -HUP $MAINPID
KillSignal=SIGINT
TimeoutStopSec=5
Restart=on-failure
SyslogIdentifier=consul
[Install]
WantedBy=multi-user.target
```

Inscrivons le service :
```
systemctl daemon-reload
```

Creeons la clé d'authentification (key_srv)
```
consul keygen
```

C'était pour l'exemple, pour simplifier on utilisera la clé plus bas.

Puis le fichier '/etc/consul.d/config.json'
```
{
"bootstrap": true,
"server": true,
"log_level": "DEBUG",
"enable_syslog": true,
"datacenter": "formation",
"addresses" : {
"http": "0.0.0.0"
},
"bind_addr": "@IP_srv",
"node_name": "srv",
"data_dir": "/var/lib/consul",
"disable_keyring_file": true,
"encrypt": "tAOrr1x52gC4K1SPKixkbFk1EkbbRN1mBjSA8UJnv2g="
}
```

Lançons le service
```
systemctl start consul
systemctl enable consul
systemctl status consul
```

Vérifions que la socket est bien ouverte :
```
ss -plunt | grep 8500
```

N'oublions pas eventuellement le firewall local [doc](https://developer.hashicorp.com/consul/docs/install/ports) :
```
ufw allow 8500/tcp
ufw allow 8300:8302
ufw allow 8600
```

Visitons http://IP_srv:8500

## Installation de HAProxy 

Toujours sur IP_srv, install HAProxy :

```
add-apt-repository -y ppa:vbernat/haproxy-2.4
apt update
DEBIAN_FRONTEND=noninteractive apt install -y haproxy
```

Installons le dataplane :
```
wget https://github.com/haproxytech/dataplaneapi/releases/download/v2.3.0/dataplaneapi_2.3.0_Linux_x86_64.tar.gz
tar -zxvf dataplaneapi_2.3.0_Linux_x86_64.tar.gz
cp build/dataplaneapi /usr/local/bin/
chmod +x /usr/local/bin/dataplaneapi
```

Creeons le fichier /etc/haproxy/dataplaneapi.yaml ** (attention à IP_srv) ** 

```
config_version: 2
name: haproxy1
dataplaneapi:
  host: <IP_srv>
  port: 5555
  user:
  - name: dataplaneapi
    password: mypassword
    insecure: true
```

Ajouter à la fin du fichier /etc/haproxy/haproxy.cfg ** ( attention à l'indentation/tabulation) **:
```
[..]
program api
    command /usr/local/bin/dataplaneapi -f /etc/haproxy/dataplaneapi.yaml
    no option start-on-reload
```

Relançons HAProxy :
```
uwf allow 5555/tcp
systemctl restart haproxy
```

## Activer Service Discovery dans HA Proxy

Toujours sur IP_srv, lancer :
```
curl -u dataplaneapi:mypassword \
       -H 'Content-Type: application/json' \
       -d '{
             "address": "<IP_srv>",
             "port": 8500,
             "enabled": true,
             "retry_timeout": 10
           }' http://127.0.0.1:5555/v2/service_discovery/consul
```
Le retour ressemble à ceci :
```
{"address":"IP_srv","enabled":true,"id":"7c557cf1-e58a-47a5-a94e-ed9bc8568d96","port":8500,"retry_timeout":10,"server_slots_base":10,"server_slots_growth_increment":10,"server_slots_growth_type":"linear","service-blacklist":null,"service-whitelist":null,"service_allowlist":null,"service_denylist":null}
```


### Installation Consul Client

Sur le Client clt, réaliser la même installation de consul avec le fichier /etc/consul.d/consul.json :
```
{
  "bind_addr": "@IP_clt",
  "data_dir": "/var/lib/consul",
  "datacenter": "formation",
  "disable_update_check": true,
  "log_level": "INFO",
  "retry_join": [
    "IP_srv"
  ],
  "server": false,
  "disable_keyring_file" :false, 
  "encrypt": "tAOrr1x52gC4K1SPKixkbFk1EkbbRN1mBjSA8UJnv2g="
}
```
PS : on pourrait utiliser '"bind_addr": "{{ GetInterfaceIP \"eth0\" }}"' mais les adresses IP multiples ne sont pas supportées...

et le nouveau fichier /etc/consul.d/web.json :
```
{
  "service": {
    "name": "web",
    "port": 80
  }
}
```
Lancons le service consul 
```
systemctl reload consul.service
```

Consultez les logs (/var/log/syslog) et l'interface web
Si le firewll pose problème vous pouvez lancer sur le 'srv' : 'ufw allow from IP_clt' et vice-versa

On obtient enfin l'affichage du noeud

![consul1](/img/consul1.png)

et le service 'web'

![consul2](/img/consul2.png)
