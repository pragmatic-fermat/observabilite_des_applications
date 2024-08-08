#Objectifs

- Ajout d'Open Telemetry dans le code d’une application containerisée
- Analyse dans un backend Jaeger ou Grafana Tempo



Sur clt

mkdir ~/microservices-marchcd ~/microservices-march
git clone https://github.com/microservices-march/messenger --branch mm23-metrics-start
git clone https://github.com/microservices-march/notifier --branch mm23-metrics-start
git clone https://github.com/microservices-march/platform --branch mm23-metrics-start


cd platform
docker compose up -d --build


## installons Node en v19
cd /root
git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.14.0


Ajouter en fin de /root/.bashrc
. "$HOME/.asdf/asdf.sh"
. "$HOME/.asdf/completions/asdf.bash"

Relancez le shell :
bash

## install plugin

cd root/messenger/app
apt-get install -y dirmngr gpg curl gawk
asdf plugin add nodejs https://github.com/asdf-vm/asdf-nodejs.git
asdf install
npm install

## init db
npm run refresh-db

Notre appli écoute tcp/5000, comme un des agents de datadog.
Modifions ce dernier

Dans  /etc/datadog-agent/datadog.yaml , modifier la variable expvar de 5000 à 5999 (par exe) et relancer datadog
systemctl restart datadog-agent

## Notififer & Messanger

cd /root/notifier/app
npm install

Dans ** une première fenetre ** lancer le notifier (qui écoute sur tcp/5000) :

cd /root/notifier/app
node index.mjs 

Dans une seconde fenetre, le messenger  (qui écoute sur tcp/5000) 
cd /root/messenger/app
node index.mjs 


Dans une troisieme fenetre, lancer une requete de message

créeons une conversation :
curl -X POST     -H "Content-Type: application/json"     -d '{"participant_ids": [1, 2]}'     'http://localhost:4000/conversations'

envoyons un message

curl -X POST \
    -H "User-Id: 1" \
    -H "Content-Type: application/json" \
    -d '{"content": "This is the first message"}' \
    'http://localhost:8085/conversations/1/messages'


Il apparait dans le notifier
(qui plante lors de l'accès à PG NODE_ENV DEV)