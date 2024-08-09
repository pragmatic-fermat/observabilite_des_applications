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

Dans /root/messenger/app :
npm run refresh-db
Dans /root/notifier/app :
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
    'http://localhost:4000/conversations/1/messages'


Il apparait dans le notifier
(qui plante lors de l'accès à PG NODE_ENV DEV)

# UI

cd /root/
git clone https://github.com/microservices-march/messenger-ui
npm install


PS : Ce Lab est librement inspiré de https://www.f5.com/company/blog/nginx/nginx-tutorial-opentelemetry-tracing-understand-microservices

## Auto-instrumentation



Commençons par auto-instrumenter:

Interrompez (Ctrl-C) le service node messenger

Puis 

cd /root/messenger/app
npm install @opentelemetry/sdk-node@0.36.0 \
            @opentelemetry/auto-instrumentations-node@0.36.4


Créer un fichier tracing.mjs qui contient :
//1
import opentelemetry from "@opentelemetry/sdk-node";
import { getNodeAutoInstrumentations } from "@opentelemetry/auto-instrumentations-node";

//2
const sdk = new opentelemetry.NodeSDK({
  traceExporter: new opentelemetry.tracing.ConsoleSpanExporter(),
  instrumentations: [getNodeAutoInstrumentations()],
});

//3
sdk.start();

Relanceons le service instrumenté 

node --import ./tracing.mjs index.mjs

Des spans apparaissent à la console , notamment lors des POST :

{
  traceId: 'e2ffb8e2ab000f2aa33ca5d58d7f9d0a',
  parentId: undefined,
  traceState: undefined,
  name: 'POST /conversations/:conversationId/messages',
  id: '4f24e9b5dcb34b06',
  kind: 1,
  timestamp: 1723206247396000,
  duration: 103316,
  attributes: {
    'http.url': 'http://localhost:4000/conversations/1/messages',
    'http.host': 'localhost:4000',
    'net.host.name': 'localhost',
    'http.method': 'POST',
    'http.scheme': 'http',
    'http.target': '/conversations/1/messages',
    'http.user_agent': 'curl/7.81.0',
    'http.request_content_length_uncompressed': 40,
    'http.flavor': '1.1',
    'net.transport': 'ip_tcp',
    'net.host.ip': '::ffff:127.0.0.1',
    'net.host.port': 4000,
    'net.peer.ip': '::ffff:127.0.0.1',
    'net.peer.port': 48906,
    'http.status_code': 201,
    'http.status_text': 'CREATED',
    'http.route': '/conversations/:conversationId/messages'
  },
  status: { code: 0 },
  events: [],
  links: []
}


## Jaeger

http://IP_clt:16686/search

Tout est vide. : rien n'est envoyé.

Toujours au niveau de /root/messenger/app :
npm install @opentelemetry/exporter-trace-otlp-http@0.36.0

Modifier ainsi tracing.mjs pour incllure la libraire et l'export :
//1
import { OTLPTraceExporter } from "@opentelemetry/exporter-trace-otlp-http";
import opentelemetry from "@opentelemetry/sdk-node";
import { getNodeAutoInstrumentations } from "@opentelemetry/auto-instrumentations-node";

//2
const sdk = new opentelemetry.NodeSDK({
        traceExporter: new OTLPTraceExporter({ headers: {} }),
  instrumentations: [getNodeAutoInstrumentations()],
});

//3
sdk.start();

NB : cela suppose que le collecteur de traces se trouve pa r défaut sur : http://localhost:4318/v1/traces.

Relancer :
node --import ./tracing.mjs index.mjs

Dans Jaeger vous devoir voir ceci 

![jaeger1](/img/tutorial-OTel-tracing-microservices_ch2-unknown-service.png)

Lancer une requete vers http://localhost:4000/health et retrouvez-là :

![jaeger2](/img/health.png)

Pour donner un meilleur nom à notre application dans le tracing :

Interromper messenher (Ctr-c)
Puis
npm install @opentelemetry/semantic-conventions@1.10.0 \
            @opentelemetry/resources@1.10.0

Modifier tracing.js ainsi :

//1
//new
import { Resource } from "@opentelemetry/resources";import { SemanticResourceAttributes } from "@opentelemetry/semantic-conventions";
import { OTLPTraceExporter } from "@opentelemetry/exporter-trace-otlp-http";
//
import opentelemetry from "@opentelemetry/sdk-node";
import { getNodeAutoInstrumentations } from "@opentelemetry/auto-instrumentations-node";

//new
const resource = new Resource({  [SemanticResourceAttributes.SERVICE_NAME]: "messenger",
});
//
//2
const sdk = new opentelemetry.NodeSDK({
        //new
        resource,
        //
        traceExporter: new OTLPTraceExporter({ headers: {} }),
  instrumentations: [getNodeAutoInstrumentations()],
});

//3
sdk.start();

Puis relancer

node --import ./tracing.mjs index.mjs

On obtient alors ceci dans Jaeger

![jaeger3](/img/tutorial-OTel-tracing-microservices_ch2-traces.png)

Faisons de même pour le notifier 

Dans /root/notifier/app :

npm install @opentelemetry/auto-instrumentations-node@0.36.4 \
  @opentelemetry/exporter-trace-otlp-http@0.36.0 \
  @opentelemetry/resources@1.10.0 \
  @opentelemetry/sdk-node@0.36.0 \
  @opentelemetry/semantic-conventions@1.10.0

Créeons un fichier tracing.mjs :

import opentelemetry from "@opentelemetry/sdk-node";
import { getNodeAutoInstrumentations } from "@opentelemetry/auto-instrumentations-node";
import { OTLPTraceExporter } from "@opentelemetry/exporter-trace-otlp-http";
import { Resource } from "@opentelemetry/resources";
import { SemanticResourceAttributes } from "@opentelemetry/semantic-conventions";

const resource = new Resource({
  [SemanticResourceAttributes.SERVICE_NAME]: "notifier",
});

const sdk = new opentelemetry.NodeSDK({
  resource,
  traceExporter: new OTLPTraceExporter({ headers: {} }),
  instrumentations: [getNodeAutoInstrumentations()],
});

sdk.start();

Puis relançons :

node --import ./tracing.mjs index.mjs

On constate dans Jaeger que les traces remontent bien

![jaeger4](/img/tutorial-OTel-tracing-microservices_ch2-notifier.png)

## Instrumentons Nginx