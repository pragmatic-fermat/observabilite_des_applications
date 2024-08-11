

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

Creer le fichier '/etc/systemd/system/consul.service' (** Attention à IP_srv**):
```
[Unit]
Description=Consul Service Discovery Agent
After=network-online.target
Wants=network-online.target
[Service]
Type=simple
User=consul
Group=consul
ExecStart=/usr/local/bin/consul agent -server -ui \
            -advertise=<IP_srv> \
            -bind=<IP_srv> \
            -data-dir=/var/lib/consul \
            -node=consul-01 \
            -config-dir=/etc/consul.d
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

Crerons la clé d'authentification (key_srv)
```
consul keygen
```

Puis le fichier '/etc/consul.d/config.json' (** remplacez bien IP_srv et key_srv**)
```
{
"bootstrap": true,
"server": true,
"log_level": "DEBUG",
"enable_syslog": true,
"datacenter": "server1",
"addresses" : {
"http": "0.0.0.0"
},
"bind_addr": "<IP_srv>",
"node_name": "srv",
"data_dir": "/var/lib/consul",
"acl_datacenter": "server1",
"acl_default_policy": "allow",
"encrypt": "<key_srv>"
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

n'oublions pas eventuellement le firewall local :
```
ufw allow 8500/tcp
```

Visitons http://IP_srv:8500