# Objectifs

- [Installation et déploiement d'une application complexe](#vue-globale)
- [Ajout de l'instrumentation OpenTelemetry dans le code](#auto-instrumentation)
- [Export et Analyse dans un backend Jaeger](#jaeger)
- [Instrumentation de Nginx](#instrumenter-nginx)
- [Extra: Tracing PHP avec Datadog](#extra-tracing-avec-datadog)

## Vue globale

Voici l'application à déployer, sans télémétrie pour démarrer :

![topo](/img/tutorial-OTel-tracing-microservices_flow.png)

PS : Ce Lab est librement inspiré de cet [article Nginx](https://www.f5.com/company/blog/nginx/nginx-tutorial-opentelemetry-tracing-understand-microservices)

## Recuperation des sources

Sur la VM `clt` :
```
mkdir ~/microservices-march
cd ~/microservices-march
git clone https://github.com/microservices-march/messenger --branch mm23-metrics-start
git clone https://github.com/microservices-march/notifier --branch mm23-metrics-start
git clone https://github.com/microservices-march/platform --branch mm23-metrics-start
```

```
cd platform
```

Modifier le `docker-compose.yml` ainsi (de façon à retirer le `notifier` et le `messenger`)
```
---
services:

  ingress:
    build: ./ingress
    container_name: ingress
    environment:
      - NGINX_UPSTREAM=68.183.74.159
    # The ingress service is the only service that has ports exposed out.
    ports:
      - 8080:8080
    networks:
      - mm_2023

  rabbitmq:
    image: rabbitmq:3.11.4-management-alpine
    container_name: rabbitmq
    hostname: microservices_march
    ports:
      - 5672:5672
      - 15672:15672
    volumes:
      - rabbit-data:/var/lib/rabbitmq/
      - rabbit-log:/var/log/rabbitmq/
    networks:
      - mm_2023

  jaeger:
    image: jaegertracing/all-in-one:1.41
    container_name: jaeger
    ports:
      - "16686:16686"
      - "4317:4317"
      - "4318:4318"
    environment:
      COLLECTOR_OTLP_ENABLED: true
    networks:
      - mm_2023

  messenger-db:
    image: postgres:15
    container_name: messenger-db
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 30s
      timeout: 30s
      retries: 3
    restart: always
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: messenger
      PGDATA: /var/lib/postgresql/data/pgdata
    ports:
      - 5432:5432
    volumes:
      - messenger-db-data:/var/lib/postgresql/data/pgdata
    networks:
      - mm_2023

  notifier-db:
    image: postgres:15
    container_name: notifier-db
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 30s
      timeout: 30s
      retries: 3
    restart: always
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: notifier
      PGDATA: /var/lib/postgresql/data/pgdata
      PGPORT: 5433
    ports:
      - 5433:5433
    volumes:
      - notifier-db-data:/var/lib/postgresql/data/pgdata
    networks:
      - mm_2023

volumes:
  rabbit-data:
  rabbit-log:
  messenger-db-data:
  notifier-db-data:

networks:
  mm_2023:
    name: mm_2023
    driver: bridge
```

Puis lancer les containers :
```
docker compose up -d --build
```

On obtient :
```
[+] Running 6/6
 ✔ Network mm_2023         Created                                                                                         0.1s 
 ✔ Container rabbitmq      Started                                                                                         0.8s 
 ✔ Container jaeger        Started                                                                                         0.9s 
 ✔ Container messenger-db  Started                                                                                         0.7s 
 ✔ Container notifier-db   Started                                                                                         0.7s 
 ✔ Container ingress       Started                                                                                         0.8s 
```

## Installons asdf (installateur Node)
```
cd /root
git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.14.0
```

Ajoutons 2 lignes en fin de `/root/.bashrc`

```
cat <<EOF >> /root/.bashrc
. "$HOME/.asdf/asdf.sh"
. "$HOME/.asdf/completions/asdf.bash"
EOF
```

Relancez le shell :
```
bash
```

## Installation de Node en v19

```
cd ~/microservices-march/messenger/app
apt-get install -y dirmngr gpg curl gawk
asdf plugin add nodejs https://github.com/asdf-vm/asdf-nodejs.git
asdf install
npm install
```

## Initialisation de la Base de Données

Dans `~/microservices-march/messenger/app` :
```
npm run refresh-db
```
Dans `~/microservices-march//notifier/app` :
```
npm run refresh-db
```

Notre appli écoute sur tcp/5000, comme un des agents de Datadog : conflit !
Modifions ce dernier :

Dans  `/etc/datadog-agent/datadog.yaml` , modifier la variable `expvar` de 5000 à 5999 (par exemple) et relancer datadog ainsi :

```
systemctl restart datadog-agent
```

## Notifier & Messenger

```
cd ~/microservices-march/notifier/app
npm install
```

Dans une **première** fenêtre lancer le `notifier` (qui écoute sur tcp/5000) :
```
cd ~/microservices-march/notifier/app
node index.mjs 
```

Dans une **seconde** fenêtre, lancer le `messenger`  (qui écoute sur tcp/5000) 
```
cd ~/microservices-march/messenger/app
node index.mjs 
```

Dans une **troisieme** fenetre, nous allons lancer des requetes de messages :

- créeons une conversation :
```
curl -X POST  \
    -H "Content-Type: application/json" \
    -d '{"participant_ids": [1, 2]}'  \
   'http://localhost:4000/conversations'
```

- envoyons ensuite un message
```
curl -X POST \
    -H "User-Id: 1" \
    -H "Content-Type: application/json" \
    -d '{"content": "This is the first message"}' \
    'http://localhost:4000/conversations/1/messages'
```

Le message apparait dans la feneêtre du `notifier`

## Auto-instrumentation

Voici notre objectif :
![flow](/img/tutorial-OTel-tracing-microservices_topology.png)

Commençons par auto-instrumenter:

Interrompez (Ctrl-C) le service node `messenger`

Puis 
```
cd /root/messenger/app
npm install @opentelemetry/sdk-node@0.36.0 \
            @opentelemetry/auto-instrumentations-node@0.36.4
```

Créer un fichier `tracing.mjs` qui contient :
```
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
```

Relancons le service instrumenté 
```
node --import ./tracing.mjs index.mjs
```
Des spans apparaissent à la console , notamment lors des POST :
```
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
```

## Jaeger

Visiter  http://IP_clt:16686/search

Tout est vide : rien n'est envoyé.

Toujours au niveau de `/root/messenger/app` :
```
npm install @opentelemetry/exporter-trace-otlp-http@0.36.0
```

Modifier ainsi `tracing.mjs` pour inclure la librairie et l'export :
```
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
```

NB : cela suppose que le collecteur de traces se trouve par défaut sur : http://localhost:4318/v1/traces

Relancer :
```
node --import ./tracing.mjs index.mjs
```

Dans Jaeger vous devez voir ceci 

![jaeger1](/img/tutorial-OTel-tracing-microservices_ch2-unknown-service.png)

Lancer une requete vers http://localhost:4000/health et retrouvez-là :

![jaeger2](/img/health.png)

Pour donner un meilleur nom à notre application dans le tracing :

Interrompez messenger (Ctr-c)
Puis
```
npm install @opentelemetry/semantic-conventions@1.10.0 \
            @opentelemetry/resources@1.10.0
```

Modifier tracing.js ainsi :
```
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
```

Puis relancer
```
node --import ./tracing.mjs index.mjs
```

On obtient alors ceci dans Jaeger

![jaeger3](/img/tutorial-OTel-tracing-microservices_ch2-traces.png)

Faisons de même pour le notifier 

Dans /root/notifier/app :
```
npm install @opentelemetry/auto-instrumentations-node@0.36.4 \
  @opentelemetry/exporter-trace-otlp-http@0.36.0 \
  @opentelemetry/resources@1.10.0 \
  @opentelemetry/sdk-node@0.36.0 \
  @opentelemetry/semantic-conventions@1.10.0
```

Créeons un fichier tracing.mjs :
```
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
```

Puis relançons :
```
node --import ./tracing.mjs index.mjs
```
On constate dans Jaeger que les traces remontent bien

![jaeger4](/img/tutorial-OTel-tracing-microservices_ch2-notifier.png)

## Mise en place d'un Reverse Proxy Nginx

Nous allons reverse-proxyfier nos applis avec nginx

Il faut donc ajouter le service suivant dans notre fichier `~/platform/docker-compose.yaml` :
```
  ingress:
    build: ./ingress
    container_name: ingress
    environment:
    ## normalment messenger
      - NGINX_UPSTREAM=<IP_PUB_clt>
    # The ingress service is the only service that has ports exposed out.
    ports:
      - 8080:80
    networks:
      - mm_2023
```

Ce service fait référence à une image Docker locale : on creera le fichier `~/platform/ingress/Dockerfile` avec le contenu suivant
```
FROM nginx:1.23

ENV NGINX_UPSTREAM=localhost

COPY default.conf.template /etc/nginx/templates/default.conf.template
```
et le fichier `~/platform/ingress/default.conf.template` avec le contenu suivant
```
upstream messenger_entrypoint {
  server ${NGINX_UPSTREAM}:4000;
}

server {
  listen 8080;

  location / {
    proxy_pass http://messenger_entrypoint;
  }

  location /health {
    access_log off;
    return 200 "OK\n";
  }

  error_page 500 502 503 504 /50x.html;
  location = /50x.html {
    root /usr/share/nginx/html;
  }
}
```

Lançons notre nouveau container :
```
docker compose create
docker compose start ingress
ufw allow 8080/tcp
ufw allow 4000/tcp
```

On rejoue les mêmes tests, mais cette fois-ci via Nginx :

créeons une conversation :
```
curl -X POST  \
    -H "Content-Type: application/json" \
    -d '{"participant_ids": [1, 2]}'  \
   'http://localhost:8080/conversations'
```

envoyons ensuite un message
```
curl -X POST \
    -H "User-Id: 1" \
    -H "Content-Type: application/json" \
    -d '{"content": "This is the first message"}' \
    'http://localhost:8080/conversations/1/messages'
```

## Instrumenter Nginx

Dans Jaeger, nous voyons toujours les traces, mais aucune mention de Nginx.
Activons OTel dans Nginx !

Retournons dans `~/platform/ingress`, et changeons ainsi le `Dockerfile` :

```
FROM --platform=amd64 nginx:1.23.1
# Replace the nginx.conf file with our own
ENV NGINX_UPSTREAM=localhost
COPY default.conf.template /etc/nginx/templates/default.conf.template

# Define the version of the NGINX OTel module
ARG OPENTELEMETRY_CPP_VERSION=1.0.3

# Define the search path for shared libraries used when compiling and running NGINX
ENV LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/opt/opentelemetry-webserver-sdk/sdk_lib/lib

# 1. Download the latest version of Consul template and the OTel C++ web server module, otel-webserver-module
ADD https://github.com/open-telemetry/opentelemetry-cpp-contrib/releases/download/webserver%2Fv${OPENTELEMETRY_CPP_VERSION}/opentelemetry-webserver-sdk-x64-linux.tgz /tmp

RUN apt-get update \
  && apt-get install -y --no-install-recommends dumb-init unzip \
# 2. Extract the module files
  && tar xvfz /tmp/opentelemetry-webserver-sdk-x64-linux.tgz -C /opt \
  && rm -rf /tmp/opentelemetry-webserver-sdk-x64-linux.tgz \
# 3. Install and add the 'load_module' directive at the top of the main NGINX configuration file
  && /opt/opentelemetry-webserver-sdk/install.sh \
  && echo "load_module /opt/opentelemetry-webserver-sdk/WebServerModule/Nginx/1.23.1/ngx_http_opentelemetry_module.so;\n$(cat /etc/nginx/nginx.conf)" > /etc/nginx/nginx.conf

# 4. Copy in the configuration file for the NGINX OTel module
COPY opentelemetry_module.conf /etc/nginx/conf.d/opentelemetry_module.conf

EXPOSE 8080

STOPSIGNAL SIGQUIT
```
Créeons le fichier `~/platform/ingress/opentelemetry_module.conf` :
```
NginxModuleEnabled ON;
NginxModuleOtelSpanExporter otlp;
NginxModuleOtelExporterEndpoint jaeger:4317;
NginxModuleServiceName messenger-lb;
NginxModuleServiceNamespace MicroservicesMarchDemoArchitecture;
NginxModuleServiceInstanceId DemoInstanceId;
NginxModuleResolveBackends ON;
NginxModuleTraceAsError ON;
```

Refaire des requetes et observer que le service messenger-lb apparait :

![jaeger-nginx](/img/jaeger-nginx.png)


# Extra : Tracing avec Datadog

A vous de jouer pour activer le tracing avec Datadog de l'application [Librespeed](https://github.com/librespeed/speedtest/blob/master/doc_docker.md) (ou autre !)

Quelques pistes pour réaliser cela sur la VM `clt` :

- créer un `docker-compose.yaml` de ce type pour visiter l'application sur tcp/81 et envoyer la telemetrie vers l'agant DD qui tourne déjà sur le host
```
services:
  speedtest:
    container_name: speedtest
      ##image: ghcr.io/librespeed/speedtest:latest
    build: .
    restart: always
    environment:
      MODE: standalone
      #TITLE: "LibreSpeed"
      #TELEMETRY: "false"
      #ENABLE_ID_OBFUSCATION: "false"
      #REDACT_IP_ADDRESSES: "false"
      #PASSWORD:
      #EMAIL:
      #DISABLE_IPINFO: "false"
      #IPINFO_APIKEY: "your api key"
      #DISTANCE: "km"
      #WEBPORT: 80
      DD_SERVICE: "librespeed"
      DD_VERSION: "1.0"
      DD_ENV: "training"
      DD_AGENT_HOST: IP_PUB_CLT
      DD_TRACE_AGENT_PORT: 8126
    ports:
      - "81:80" # webport mapping (host:container)
```

- creer un `Dockerfile` de ce type pour auto-instrumenter l'application
```
FROM ghcr.io/librespeed/speedtest:latest

ADD https://github.com/DataDog/dd-trace-php/releases/latest/download/datadog-setup.php /tmp
RUN php /tmp/datadog-setup.php --php-bin=all --enable-profiling
```


- modifier le `/etc/datadog/datadog.yaml` de cette façon (attention très pointilleux sur les indentations):

```
# grep -v "#" /etc/datadog-agent/datadog.yaml | egrep "[a-z]"
api_key: ZZZZZZ56687417ea7
site: datadoghq.eu
apm_config:
  enabled: true
  apm_non_local_traffic: true
```
puis
```
systemctl restart datadog-agent
```

- vérifier avec `dd-agent` après avoir généré du trafic sur le site web http://IP_clt:81
```
# datadog-agent status | grep -i trace -A10
    https://trace.agent.datadoghq.eu

  Receiver (previous minute)
  ==========================
    From php 8.3.10 (apache2handler), client 1.2.0
      Traces received: 19 (12,071 bytes)
      Spans received: 19


    Priority sampling rate for 'service:librespeed,env:training': 100.0%

  Writer (previous minute)
  ========================
    Traces: 0 payloads, 0 traces, 0 events, 0 bytes
    Stats: 0 payloads, 0 stats buckets, 0 bytes
```


- visualiser sur le portail datadog :

![dd_trace1](/img/dd-trace1.png)

![dd_trace2](/img/dd-trace2.png)