
# Objectifs 

Dans ce lab nous voyons 2 approches de la récupération des métriques :

- mode **Pull** : un serveur central récupère les métriques, c'est le cas de Prometheus
- mode **Push** : sur chaque équipement, un agent exporte les métriques vers un serveur central, c'est le cas de Datadog

# Contenu

- [NodeExporter/Prometheus/Grafana](#nodeexporterprometheusgrafana)
    - [Utilisation de NodeExporter pour publier les métriques systèmes d’un serveur Linux](#nodeexporter)
    - [Installation de NodeExporter](#installation-de-nodeexporter-sur-un-autre-serveur)
    - [Collecte des métriques par Prometheus](#installation-dun-serveur-prometheus)
    - [Visualisation dans Grafana](#dashboard-grafana)
    - [Ajout de metric custom dans NodeExporter](#ajout-dune-metrique-custom-dans-nodeexporter)
    - [Instrumenter le code avec Prometheus](#instrumenter-le-code-pour-prometheus)

- [Datadog](#supervision-avec-datadog)
    - [Installation de l'agent Datadog](#installation-de-lagent-datadog)
    - [Recupération d'une metrique Custom](#metrique-custom-dans-datadog)


# Les serveurs dédiés à la disposition de chaque participant.e

On utilise 2 VMs :
- le serveur de supervision (`srv` ) sur lequel on va installer `Prometheus` et `Grafana`
- la machine supervisée (`clt`) sur lequel on va installer `NodeExporter`

**Note** : L'animateur vous a fournit les noms DNS (FQDN) des serveurs `srv` et `clt`, il suffira de les utiliser à chaque fois que vous vyez dans les labs `srv_FQDN` et `clt_FQDN`

# NodeExporter/Prometheus/Grafana

Prometheus "scrappe" (c-a-d lit et analyse) les métriques sur les serveurs supervisés, les stocke dans sa TSDB, accessible pour Grafana.

![prom-arch](/img/prom-architecture.png)

## Installation d'un serveur `Prometheus`

Connectez-vous au serveur de supervision `srv` suivant les accès fournis par l'animateur.

Vérifions que le moteur `docker` et `docker compose` est bien installé
```
docker version
docker compose version
```

Créeons le répertoire `/home/prometheus` :
```
mkdir /home/prometheus
cd /home/prometheus
```

Créeons dans ce répertoire le fichier ```docker-compose.yml``` ci-dessous qui définit le service `prometheus` en copiant collant directement cette commande dans le shell :

```
cat <<EOF >docker-compose.yml
services:
  prometheus:
    image: prom/prometheus
    container_name: prometheus
    restart: unless-stopped
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus-data:/prometheus
    command:
      - "--config.file=/etc/prometheus/prometheus.yml"
    networks:
      - monitoring

networks:
  monitoring:
    driver: bridge

volumes:
  prometheus-data:
EOF
```

Créeons le fichier de configuration  ```/home/prometheus/prometheus.yml``` en tapant cette ligne de commande  :

```
cat <<EOF >/home/prometheus/prometheus.yml
global:
  scrape_interval: 10s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['prometheus:9090']

EOF
```

Notez l'utilisation du nom `prometheus` qui sera résolu localement par Docker.

Lançons le serveur :
```bash
docker compose up -d --force-recreate
```

Naviguez sur la page Prometheus : `http://srv_FQDN:9090` , et explorez les métriques.

Par exemple, retrouvez la métrique qui donne le timestamp de lancement du service prometheus et affichez sa valeur et son graphe.

Autre exemple (cf [doc](https://prometheus.io/docs/prometheus/latest/querying/examples/)), aggrégez les visites des pages web par URI :
```
sum(prometheus_http_requests_total) by (handler)
```
ou par code retour :
```
sum(prometheus_http_requests_total) by (code)
```
ou lister les 3 URLs qui comptabilisent le plus de code 200
``` 
topk(3,prometheus_http_requests_total{code="200"})
```

## Installation de `NodeExporter` sur un autre serveur (`clt`)

Sur l'autre VM (appellons-la `clt`), installons `NodeExporter` :

Le mieux est de suivre cette [procédure](https://gist.github.com/nwesterhausen/d06a772cbf2a741332e37b5b19edb192) , que nous reproduisons ci-dessous :

```bash
useradd --no-create-home --shell /bin/false node_exporter
wget https://github.com/prometheus/node_exporter/releases/download/v0.18.1/node_exporter-0.18.1.linux-amd64.tar.gz
tar xvf node_exporter-0.18.1.linux-amd64.tar.gz
mv node_exporter-0.18.1.linux-amd64 /opt/node_exporter
chown -R node_exporter:node_exporter /opt/node_exporter
```

Créer le fichier ```/etc/systemd/system/node_exporter.service``` :

```
cat <<EOF >/etc/systemd/system/node_exporter.service
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/opt/node_exporter/node_exporter --collector.systemd

[Install]
WantedBy=multi-user.target

EOF
```

Puis mettons en place le service

```bash
systemctl enable node_exporter
systemctl daemon-reload
systemctl start node_exporter
```

**NB** : à l'heure de la rédaction de ces lignes, la dernière version est 1.8.2

Naviguez sur la page NodeExporter : `http://clt_FQDN:9100/metrics`


## Ajout de la supervision du serveur Linux `clt`

Tout d'abord créez la variable CLT avec la véritable valeur de `clt_FQDN` :

```bash
CLT=clt_FQDN
```

**Sur le serveur Prometheus, c-a-d `srv`**, grâce à la commande suivante, ajoutons (avec interpolation) en fin de fichier ```/home/prometheus/prometheus.yml``` ceci  :

```bash
cat << EOF >> /home/prometheus/prometheus.yml
  - job_name: 'node-exporter'
    static_configs:
      - targets: [${CLT}:9100]
EOF
```

Relancer le service Prometheus :

```bash
cd /home/prometheus
docker compose restart
```

Naviguez sur la page Prometheus : `http://srv_FQDN:9090/targets` 

Requêtez et graphez par exemple la metrique `node_network_receive_bytes_total`

### Ajout du service `Grafana`

Grafana va être executé sous la forme d'un container Docker, sur notre serveur `srv`.

Le plus simple et efficace consiste donc à étendre notre ```docker-compose.yml``` initial ainsi (c-a-d en insérant le bloc `grafana` et son `volume`), grâce à la commande ci-dessous :

```bash
cat << EOF > /home/prometheus/docker-compose.yml
services:
  prometheus:
    image: prom/prometheus
    container_name: prometheus
    restart: unless-stopped
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus-data:/prometheus
    command:
      - "--config.file=/etc/prometheus/prometheus.yml"
    networks:
      - monitoring

  grafana:
    image: grafana/grafana-enterprise
    container_name: grafana
    restart: unless-stopped
    ports:
      - "3000:3000"
    volumes:
      - grafana-data:/var/lib/grafana
    networks:
      - monitoring

networks:
  monitoring:
     driver: bridge

volumes:
  prometheus-data:
  grafana-data:
EOF
```

Relancons les containers grâce à docker-compose :

```bash
docker compose up -d --force-recreate
```

Consultons l'interface web de Grafana en HTTP sur le port 3000 avec les creds `admin/admin` : `http://srv_FQDN:3000`

- Aller dans le menu sur la gauche and sélectionner “Connections / Data Sources”
- Cliquer sur “Add your data source”
- Choisir “Prometheus” dans la liste
- Renseigner cette URL : http://prometheus:9090 (le nom du container prometheus est résolu en interne par docker)
- Cliquer sur  “Save & Test” pour vérifier la connection entre Grafana et Prometheus

## Dashboard Grafana

- Chercher **sur le web** dans la page [Grafana Dashboard](https://grafana.com/grafana/dashboards/) le dashboard ”Node Exporter Full”.
- Copier le dashboard ID. Dans notre cas, l'ID est 1860.
- De retour sur *notre* Grafana, sur la gauche, cliquer sur  “Dashboard” puis le bouton bleu en haut à gauche "New" : dans cette list déroulante, sélectionner “Import”
- Dans la section “Grafana.com Dashboard” , copier le dashboard ID (1860) dans le champ “Grafana.com Dashboard ID” .
- Cliquer sur le bouton “Load” , sélectionner *notre* prometheus dans le champ (liste déroulante)

Naviguer dans la section des Dashboard.... 

![graf-node](img/graf-node.png)

## Ajout d'une metrique custom dans NodeExporter

Sur le serveur supervisé (`clt`) :

```bash
mkdir /home/textfile
```

Configurez le service NodeExporter pour prendre en compte ce répertoire  (modification la ligne suivante dans `/etc/systemd/system/node_exporter.service`) grâce à cette commande :

```bash
cat <<EOF >/etc/systemd/system/node_exporter.service
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/opt/node_exporter/node_exporter --collector.textfile.directory=/home/textfile

[Install]
WantedBy=multi-user.target

EOF
```


Puis relançons NodeExporter :
```bash
systemctl daemon-reload
systemctl restart node_exporter.service  
```

Créeons (à la main) un fichier contenant notre metrique custom (dont la valeur vaut le nombre de secondes depuis l'*epoch*):
```
echo ma_metrique_custom $(date +%s) > /home/textfile/ma_metrique_custom.prom
```

Naviguez sur la page NodeExporter : http://clt_FQDN:9100/metrics  et constatez que notre métrique est incluse dans la page !
```
curl -s http://${CLT}:9100/metrics | grep "ma_metrique_custom"
```

On obtient :
```
# HELP ma_metrique_custom Metric read from /home/textfile/ma_metrique_custom.prom
# TYPE ma_metrique_custom untyped
ma_metrique_custom 1.722946125e+09
node_textfile_mtime_seconds{file="ma_metrique_custom.prom"} 1.722946125e+09
```

Cette métrique doit également être consutable sur Prometheus directement : http://srv_FQDN:9090

![prom-custom](img/prom-custom.png)

Plus de détails [ici](https://github.com/prometheus-community/node-exporter-textfile-collector-scripts)

Notez la mention de ```spunge``` afin d'écrire atomiquement le fichier ```textfile```.

## Instrumenter le Code pour Prometheus

Sur `clt`, nous allons instrumenter  une application API écrite en python avec flask.

Le code de notre application est le suivant :

```python
from flask import Flask, request, render_template_string
from prometheus_client import start_http_server, Counter, Histogram, generate_latest
from prometheus_client.core import CollectorRegistry
import time
import random

# Initialiser l'application Flask
app = Flask(__name__)

# Crée un compteur pour les appels de fonction
REQUEST_COUNT = Counter('my_function_request_count', 'Total number of requests to my_function')

# Crée un histogramme pour les temps d'exécution
REQUEST_LATENCY = Histogram('my_function_request_latency_seconds', 'Latency of requests to my_function in seconds')

# Décorateur pour mesurer les métriques
def metric_decorator(func):
    def wrapper(*args, **kwargs):
        REQUEST_COUNT.inc()  # Incrémente le compteur de requêtes
        with REQUEST_LATENCY.time():  # Mesure le temps d'exécution de la fonction
            result = func(*args, **kwargs)
        return result
    return wrapper

@metric_decorator
def my_function():
    # Simule une tâche longue avec un temps d'exécution aléatoire
    time.sleep(random.uniform(0.1, 0.5))
    return "Function is complete."

@app.route('/')
def index():
    # Appel de la fonction décorée
    message = my_function()
    return render_template_string("<h1>{{ message }}</h1>", message=message)

@app.route('/metrics')
def metrics():
    # Exposer les métriques au format texte brut pour Prometheus
    return generate_latest()

if __name__ == '__main__':
    # Démarre un serveur HTTP pour exposer les métriques sur le port 8000
    start_http_server(8000)
    
    # Démarre l'application Flask sur toutes les interfaces réseau (0.0.0.0) sur le port 5000
    app.run(host='0.0.0.0', port=5000)
```

Importons ce script puis lançons-le :
```bash
wget "https://raw.githubusercontent.com/pragmatic-fermat/observabilite_des_applications/refs/heads/main/data/myapp.py" -O /home/myapp.py
python3 /home/myapp.py
```


Visiter le site web  http://clt_FQDN:5000 (l'application)

![app-inst-metr](img/app-instr-met.png)

puis le site http://clt_FQDN:8000  (les métriques Prometheus) 

![app-instr](img/app-instr.png)

## Cleanup

Arrêter le programme python (Ctrl-C) puis le reste des containers (i.e Prometheus et Grafana) ainsi :

```bash
docker compose down
```

# Supervision avec Datadog

## Installation de l'agent Datadog

Créez un compte (gratuit) sur [Datadog](http://datadog.com)

Suivre la procédure d'[installation d'un agent systeme](https://app.datadoghq.eu/account/settings/agent/latest?platform=overview) (Integration > Agent) avec la création à la volée d'une clé API.

![dd-agent](img/dd-agent.png)

Au bout de quelques minutes, votre serveur `clt` va aparaitre dans le portail DataDog, menu à gauche "Infrastructure > Hosts"

![dd-infra](img/dd-infra.png)

Vous pouvez créer une alerte (monitor) sur cette [page](https://app.datadoghq.eu/monitors/create) en choisissant par exemple la metrique ```system.disk.free``` ou autre...)

## Metrique custom dans Datadog

Supposons que nous souhaitions connaitre le nombre de lignes dans les tables d'une base de données.

### Installation d'une base de données sur le serveur supervisé

Sur notre serveur `clt`, connectons nous à la base de données mariadb (pré-installée, mot de passe vide) :

```bash
mysql -u root
mysql>
```

Importons le fichier de base de données qui se trouve (déja) dans /home/mysqlsampledatabase.sql et configurons le mot de passe root mysql
```
> source /home/mysqlsampledatabase.sql ;
> show databases;
+--------------------+
| Database           |
+--------------------+
| classicmodels      |
| information_schema |
| mysql              |
| performance_schema |
| sys                |
+--------------------+
> ALTER USER 'root'@'localhost' IDENTIFIED BY 'MyN3wP4ssw0rd';
> flush privileges;
> exit;
```

### Configuration de l'agent Datadog

Sur le serveur supervisé (i.e `clt`):

```
sudo usermod -a -G docker dd-agent
cd /etc/datadog-agent/conf.d/mysql.d
```

Dans le fichier `conf.yaml` nous voudrions injecter (en faisant attention aux indentations) quelque chose comme ceci:

```yaml
init_config:
instances:
  - host: localhost
    dbm: true
    username: root
    password: MyN3wP4ssw0rd
    port: 3306

    custom_queries:
      - query: SELECT COUNT(*) FROM classicmodels.customers
        columns:
         - name: classicmodels.customers
           type: gauge
      - query: SELECT COUNT(*) FROM classicmodels.employees
        columns:
         - name: classicmodels.employees
           type: gauge
      - query: SELECT TABLE_NAME, TABLE_ROWS FROM information_schema.TABLES WHERE TABLE_SCHEMA = 'classicmodels'
        columns:
         - name: classicmodels.table_name
           type: tag
         - name: classicmodels.table_rows
           type: gauge
```

Cette commande fera alors l'affaire :

```bash
rm -f conf.yaml.example
wget "https://raw.githubusercontent.com/pragmatic-fermat/observabilite_des_applications/refs/heads/main/config/datadog/conf.yaml" -O conf.yaml
```


Relancer l'agent datadog et vérifier que la plugin SQL est sans erreur :

```bash
systemctl restart datadog-agent
```
Lancer plusieurs fois l'outil de diagnostic jusqu'à ce que le paragraphe MySQL soit ok :

```
# datadog-agent status | grep -A10 -i mysql 
    mysql (12.5.1)
    --------------
      Instance ID: mysql:4bf5f516622ead61 [OK]
      Configuration Source: file:/etc/datadog-agent/conf.d/mysql.d/conf.yaml
      Total Runs: 1
      Metric Samples: Last Run: 69, Total: 69
      Events: Last Run: 0, Total: 0
      Database Monitoring Metadata Samples: Last Run: 1, Total: 1
      Service Checks: Last Run: 1, Total: 1
      Average Execution Time : 533ms
      Last Execution Date : 2024-08-07 06:09:51 UTC (1723010991000)
      Last Successful Execution Date : 2024-08-07 06:09:51 UTC (1723010991000)


```

Ensuite aller dans Datadog :
- activer l'intégration MySQL

![dd-mysql](img/dd-mysql.png)

- explorer les métriques (menu "Metric Explorer" à gauche)

![dd-mysql-metr](img/dd-mysql-metr.png)

- retrouver nos 2 métriques custom :

![dd-class](img/dd-class.png)

- dans un Dasboard, ajouter 2 graphes montrant le nombre de customers et d'employes

![dd-graph1](img/dd-graph1.png)

- puis construisez une TopList qui montre le nombre de lignes par table dans notre database 'classimodels' :

![dd-graph2](img/dd-graph2.png)

Soit

![dd-graph3](img/dd-graph3.png)

## Cleanup

