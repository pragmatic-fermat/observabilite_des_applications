# Objectif

Diagnostiquer grâce aux outils d'observabilité

NB :  ce Lab est très largement  inspiré d'excellent livre [Cloud-Native Observability with OpenTelemetry](https://www.amazon.com/Cloud-Native-Observability-OpenTelemetry-visibility-combining/dp/1801077703)

## Setup

Ce lab peut se dérouler sur l'une des VMs mise à votre disposition.

**PS** : pensez à arreter Datadog éventuellement (`systemctl stop datadog-agent`) afin d'éviter un conflit sur le port TCP/5000.


Il s'agit de mettre en place cet environnement :
![lab-diag](/img/lab-diag.png)

Récupérer localement sur votre serveur l'arborescence de [`config`](/config/), c-a-d l'ensemble des fichiers de configuration des outils d'observabilité du lab :
```
git clone https://github.com/pragmatic-fermat/observabilite_des_applications.git
cd observabilite_des_applications
```


Créer un fichier `.env` :
```
cat <<EOF >.env
suff=''
##suff='-example1'

EOF
```

Creer un fichier `docker-compose.yaml` ainsi :
```
cat <<EOF >docker-compose.yaml
services:
  shopper:
    image: codeboten/shopper:chapter11${suff}
    environment:
      - OTEL_EXPORTER_OTLP_ENDPOINT=opentelemetry-collector:4317
      - OTEL_EXPORTER_OTLP_INSECURE=true
      - GROCERY_STORE_URL=http://grocery-store:5000/products
    networks:
      - cloud-native-observability
    depends_on:
      - grocery-store
      - opentelemetry-collector
    deploy:
      replicas: 15
      resources:
        limits:
          cpus: "0.50"
          memory: 100M
    stop_grace_period: 1s
  grocery-store:
    image: codeboten/grocery-store:chapter11${suff}
    container_name: grocery-store
    environment:
      - OTEL_EXPORTER_OTLP_ENDPOINT=opentelemetry-collector:4317
      - OTEL_EXPORTER_OTLP_INSECURE=true
      - OTEL_SERVICE_NAME=grocery-store
      - INVENTORY_URL=http://legacy-inventory:5001/inventory
    networks:
      - cloud-native-observability
    depends_on:
      - legacy-inventory
      - opentelemetry-collector
    cap_add:
      - NET_ADMIN
    ports:
      - 5000:5000
    deploy:
      resources:
        limits:
          cpus: "0.50"
          memory: 100M
  legacy-inventory:
    image: codeboten/legacy-inventory:chapter11${suff}
    container_name: inventory
    environment:
      - OTEL_EXPORTER_OTLP_ENDPOINT=opentelemetry-collector:4317
      - OTEL_EXPORTER_OTLP_INSECURE=true
      - OTEL_SERVICE_NAME=inventory
    networks:
      - cloud-native-observability
    depends_on:
      - opentelemetry-collector
    ports:
      - 5001:5001
    deploy:
      resources:
        limits:
          cpus: "0.50"
          memory: 100M
  jaeger:
    image: jaegertracing/all-in-one:1.29.0
    container_name: jaeger
    ports:
      - 6831:6831/udp
      - 16686:16686
    networks:
      - cloud-native-observability
  prometheus:
    image: prom/prometheus:v2.29.2
    container_name: prometheus
    volumes:
      - ./config/prometheus/config.yml/:/etc/prometheus/prometheus.yml
    command:
      - "--config.file=/etc/prometheus/prometheus.yml"
      - "--enable-feature=exemplar-storage"
    ports:
      - 9090:9090
    networks:
      - cloud-native-observability
  opentelemetry-collector:
    image: codeboten/collector:0.45.0
    container_name: opentelemetry-collector
    volumes:
      - ./config/collector/config.yml/:/etc/opentelemetry-collector.yml
      - /var/run/docker.sock:/var/run/docker.sock
    command:
      - "--config=/etc/opentelemetry-collector.yml"
    networks:
      - cloud-native-observability
    ports:
      - 4317:4317
      - 13133:13133
      - 8889:8889
  loki:
    image: grafana/loki:2.3.0
    container_name: loki
    ports:
      - 3100:3100
    command: -config.file=/etc/loki/local-config.yaml
    networks:
      - cloud-native-observability
  promtail:
    image: grafana/promtail:2.3.0
    container_name: promtail
    volumes:
      - /var/log:/var/log
    command: -config.file=/etc/promtail/config.yml
    networks:
      - cloud-native-observability
  grafana:
    image: grafana/grafana:8.3.3
    container_name: grafana
    ports:
      - 3000:3000
    volumes:
      - ./config/grafana/provisioning:/etc/grafana/provisioning
    networks:
      - cloud-native-observability
    environment:
      - GF_AUTH_ANONYMOUS_ENABLED=true
      - GF_AUTH_ORG_ROLE=Editor
      - GF_AUTH_ANONYMOUS_ORG_ROLE=Admin
      - GF_AUTH_DISABLE_LOGIN_FORM=true
      - GF_USERS_DEFAULT_THEME=light

networks:
  cloud-native-observability:

EOF
```


## Scenarios

Pour passer d'un scenario à l'autre (`example1` à `example5`), il suffit de :

- modifier en conséquence la variable `suff` dans le fichier `.env`
- relancer `docker compose up -d --force-recreate`
- diagnostiquer les symptomes et leur cause

Jaeger, Prometheus et Grafana sont accessibles sur leurs ports respectifs (et préconfigurés)

**Attention** : aucune authentification n'est en place, les services sont exposés publiquement.

---

Indices et solutions : cf https://github.com/PacktPublishing/Cloud-Native-Observability/tree/main/chapter11/scenarios
