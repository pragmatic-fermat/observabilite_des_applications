
# Objectifs 

Dans ce TP nous voyons 2 approches de la récupération des métriques :

- mode Pull : un serveur central récupère les métriques, c'est le cas de Prometheus
- mode Push : sur chaque équipement, un agent exporte les métriques vers un serveur central, c'est le cas de Datadog

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


# NodeExporter/Prometheus/Grafana

On utilise 2 VMs :
- le serveur de supervision sur lequel on va installer Prometheus/Grafana
- le serveur supervisé sur lequel on va installer NodeExporter

## Installation d'un serveur Prometheus

Sur le serveur de supervision, vérifions que docker est bien installé
```
docker -v
```

Créeons le répertoire /home/prometheus :
```
mkdir /home/prometheus
cd /home/prometheus
```

Plaçons dans ce répertoire le fichier ```docker-compose.yml``` ci-dessous qui définit le service :

```
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
```

Créeons le fichier de configuration dans ```/home/prometheus/prometheus.yml``` :

```
global:
  scrape_interval: 10s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['prometheus:9090']
```

Lançons le serveur :
```
docker compose create
docker compose up -d
```

Naviguez sur la page Prometheus : http://IP_srv_prom:9090 , et explorez les métriques.


## Installation de NodeExporter sur un autre serveur

Sur un autre serveur, installons NodeExporter :

Le mieux est de suivre cette [procédure](https://gist.github.com/nwesterhausen/d06a772cbf2a741332e37b5b19edb192)

Nb : à l'heure de la rédaction de ces lignes, la dernière version est 1.8.2

## Supervision du serveur Linux

Sur le serveur Prometheus, modifier le fichier ```/home/prometheus/prometheus.yml```, afin d'y ajouter :

```
  - job_name: 'node-exporter'
    static_configs:
      - targets: ['your-node-exporter-host:9100']
```

NB : remplacer ```your-node-exporter-host``` par la véritable IP du serveur à superviser

Relancer prometheus :
```
cd /home/prometheus
docker compose restart -d
```

Naviguez sur la page NodeExporter : http://IP_srv_supervise:9100/metrics 

### Ajout du service Grafana

Grafana va être executé sous la forme d'un container Docker.
Le plus simple et efficace consiste donc à étendre notre ```docker-compose.yml``` initial ainsi :

```
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
```

Relancons docker-compose :
```
docker compose up -d
```

Consultons l'interface web Grafana en HTTP sur le port 3000 avec les creds admin/admin.

##TODO
- Cliquer sur l'icone (⚙️) sur la gauche and sélectionner “Data Sources.”
- Clicquer sur “Add your first data source.”
- Choisir “Prometheus” dans la liste
- Rensigner l'URL http://prometheus:9090 (prometheus est résolu en interne par docker)
- Cliquer sur  “Save & Test” pour vérifier la connection.

## Dashboard Grafana

- Chercher dans la page [Grafana Dashboard](https://grafana.com/grafana/dashboards/) le dashboard ”Node Exporter Full”.
- Copier le dashboard ID. Dans notre case, l'ID est 1860.
- Sur la gauche, clicquer sur le  “+” pour ouvrir le menu “Create” .
- Dans le menu “Create” , selectionner “Import”
- Dans la section “Grafana.com Dashboard” , copier le dashboard ID (1860) dans le champ “Grafana.com Dashboard ID” .
- Cliquer sur le bouton “Load”

Naviger dans la section des Dashboard.... 

## Ajout d'une metrique custom dans NodeExporter

Sur le serveur supervisé :

```
mkdir /root/textfile
```

Configurez nodeexporter pour prendre en compte ce répertoire :
```
./node_exporter --collector.textfile.directory=/home/textfile
```

Créeons (à la main) un fichier contenant notre metrique custom (dont la valeur vaut le nombre de secondes depuis l'epoch):
```
echo ma_metrique_custom $(date +%s) > /home/textfile/ma_metrique_custom.prom
```

Naviguez sur la page NodeExporter : http://IP_srv_supervise:9100/metrics  et constatez que notre métrique est incluse dans la page !

Cette métrique doit également être consutable sur Prometheus directement : http://IP_srv_prom:9090

Plus de détails [ici](https://github.com/prometheus-community/node-exporter-textfile-collector-scripts)
Notez la mention de ```spunge``` afin d'écrire atomiquement le fichier ```textfile```.

## Instrumenter le Code pour Prometheus

```
apt install python3-prometheus-client python3-flask
```

Puis copier le code suivant dans l'invite python3 :

```
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

Visiter le site web sur TCP/8000 (les métriques Prometheus) et TCP/5000 (l'application)


# Supervision avec Datadog

## Installation de l'agent Datadog

Créez un compte (gratuit) sur [Datadog](http://datadog.com)

Suivez la procédure d'[installation d'un agent systeme](https://app.datadoghq.eu/account/settings/agent/latest?platform=overview) avec la création à la volée d'une clé API.

Au bout de quelques minutes, votre serveur va aparaitre dans l'interface.

Vous pouvez créer une alerte (monitor) sur cette [page](https://app.datadoghq.eu/monitors/create) en choisissant par exemple la metrique ```system.disk.free``` ou autre...)

## Metrique custom dans Datadog

Supposons que nous souhaitions connaitre le nombre de ligne dans les tables d'une base de donnée.

### Installation d'une base de données sur le serveur supervisé

```
apt install -y mariadb
```

Injection d'une base de données nommée `classicmodels`

```
cd /home/
curl https://www.mysqltutorial.org/wp-content/uploads/2023/10/mysqlsampledatabase.zip
gunzip mysqlsampledatabase.zip
```

Puis
```
mysql -u root -p
```
Ce qui donne 
```
Enter password: ********
mysql>
```

Enfin, injectons la DB
```
> source mysqlsampledatabase.sql;
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
```

### Configuration de l'agent Datadog

Sur le serveur supervisé :
```
cd /etc/datadog/conf.d/mysql
```

Renommer le fichier `conf.yaml.sample` en `conf.yaml` et injecter (en faisant attention aux indentations) quelque chose comme ceci:

```
init_config:
instances:
  - host: localhost
    dbm: true
    username: root
    password: xxx
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
```

Relancer datadog et vérifier que la plugin SQL est sans erreur :

```
systemctl restart datadog-agent
dd-agent status
```

Ensuite aller dans Datadog :
- activer l'intégration
- explorer les métriques
- dans un dasboard ajouter une table montrant le nombre de customers et de employees

##TO DO screenshot
