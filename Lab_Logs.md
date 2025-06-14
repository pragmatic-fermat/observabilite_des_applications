# Objectifs

- [Export de logs (non-)structurés depuis un serveur Linux avec l’agent `Beats` (`FileBeats`) vers `ElasticSearch`/`Kibana`](#export-de-logs-vers-elastic-avec-filebeat)
- [Export de logs depuis un cluster Kubernetes vers `Grafana_Cloud` avec l'agent `Alloy`](#export-de-logs-depuis-k8s)
- [Visualisation dans `Grafana Loki`](#visualisation-dans-grafana-loki)

## Export de logs vers Elastic avec Filebeat

Sur la VM `srv`, nous allons :
- installer `nginx`
- lancer des containers `Elastic` et `Filebeat`

Nous constaterons que l'utilisation de logs structurés est plus que souhaitable...

### Installation de `nginx`
```
apt install -y nginx
```
### Lancement de `Elastic` et `Filebeat`

L'installation d'un Elastic on-prem dans ses dernières versions est incroyablement complexe ...

Il faut d'abord positionner une variable à un seuil minimum :
```
echo "vm.max_map_count=262144" >> /etc/sysctl.conf
sysctl -p
```

Changeons de répertoire :
```
mkdir -p /home/elastic
cd /home/elastic
```

Puis créeons le fichier `docker-compose.yaml` suivant
```
cat <<EOF > docker-compose.yaml
services:
  elasticsearch:
    image: elasticsearch:7.17.3
    environment:
      - discovery.type=single-node
  
  kibana:
    image: kibana:7.17.3
    environment:
      - ELASTICSEARCH_HOSTS=http://elasticsearch:9200
    ports:
      - 5601:5601
  
  shipper:
    image: docker.elastic.co/beats/filebeat:8.14.0
    user: root
    volumes:
      - /var/log/:/var/log-external
      - ./filebeat.yml:/usr/share/filebeat/filebeat.yml
EOF
```

et le fichier de configuration `filebeat.yml` suivant :
```
cat <<EOF > filebeat.yml
filebeat.modules:
- module: nginx
  access:
    var.paths: ["/var/log-external/nginx/access.log"]
  error:
    var.paths: ["/var/log-external/nginx/error.log"]

filebeat.inputs:
- type: log
  paths:
    - /var/log-external/auth.log

output.elasticsearch:
  hosts: elasticsearch:9200
  indices:
    - index: "nginx-logs"
EOF
```

et lançons les containers :
```
docker compose up -d
```

### Interface de restitution (`Kibana`)

Naviguons sur http://IP_srv:5601

Pendant plusieurs minutes vous aurez :
![kibana_wait](/img/kibana-wait.png)

Après avoir cliqué sur "Explore on my own", allez ensuite dans les menus à gauche :
```
Management > Stack Management > Kibana > Index Patterns > Create index pattern 
```
Puis dans la fenetre modale :
```
> name: *, Timestamp field: @timestamp > Create index pattern
```

Allez ensuite dans le menu global de la racine à gauche  ```Analytics > Discover``` :
![kibana1](/img/kibana1.png)

On constate que le module a parsé les logs `nginx` de façon structurée (via un module `filebeat`) et de façon texte pour les `auth.log`

![struct](/img/struct.png)


![non-struct](/img/non-struct.png)

Comparez la simplicité de recherche suivant le format, et la capacité de recherche croisée...

### Cleanup

```bash
systemctl stop nginx.service
docker compose down
```

## Export de logs depuis K8s

### Mise en place accès à K8s (piloté depuis la VM srv)

Pré-requis :

- Créer un compte (gratuit) sur [Grafanalabs](https://grafana.com/)

- Obtenir un accès à un cluster k8s (fourni par l'animateur). 
Un ingress controler de type nginx est déjà installé, mais il ne sera utilisé que dans le [Lab Demo Otel](/Lab_OpenTelemetry_Demo.md)

- Avoir les outils ```kubectl``` et ```helm``` installés 

Sur la VM `srv`, testons :
```bash
kubectl version
helm version 
```

Nous devons maintenant récupérer le `kubeconfig` qui contient les creds d'accès à notre cluster.

Ceci peut être réalisé executant le script [init.sh](/init.sh) avec les variables `GRP_NUMBER` et `ENTROPY` fournies par l'animateur :
```bash
rm -f ./init.sh
wget https://raw.githubusercontent.com/pragmatic-fermat/observabilite_des_applications/refs/heads/main/init.sh
chmod a+x init.sh
```

Puis, l'animateur vous indiquera la valeur de ENTROPY

```bash
./init.sh  <GRP_NUMBER> <ENTROPY>
```

Vérifions que l'accès est OK :

```bash
kubectl cluster-info
```

Ce qui doit donner :

```
Kubernetes control plane is running at https://xxxxxxxx
CoreDNS is running at https://xxxxxx/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy
```

Pour note, une *cheat-sheet* des commandes kubectl est disponible [ici](https://kubernetes.io/fr/docs/reference/kubectl/cheatsheet/)


On otbient ceci :
```bash
#kubectl get nodes
NAME                   STATUS   ROLES    AGE     VERSION
pool-8mwxj0101-bacu0   Ready    <none>   5m58s   v1.30.2
pool-8mwxj0101-bacu1   Ready    <none>   5m57s   v1.30.2
```


### Installation du HelmChart Grafana

Dans le portail GrafanaLabs, déroulons la procédure d'attachement d'un cluster k8s

Cliquer sur "Start sending data" :

![grafana_labs](/img/graf1.png)

![grafana_labs](/img/graf2.png)

![grafana_labs](/img/graf3.png)

Avec ```Helm``` nous pouvons déployons la stack de monitoring (copier/coller de l'écran de Grafanalabs grâce à l'icone presse-papier en haut à droite) :

![grafana_labs](/img/graf4.png)

**Attention à bien vérifier que la valeur du TOKEN est insérée dans la ligne de commande !!**

```
helm repo add grafana https://grafana.github.io/helm-charts &&
  helm repo update &&
  helm upgrade --install --atomic --timeout 300s grafana-k8s-monitoring grafana/k8s-monitoring \
[..]
```

Ce qui donne
```
[..]
"grafana" already exists with the same configuration, skipping
Hang tight while we grab the latest from your chart repositories...
[..]
...Successfully got an update from the "grafana" chart repository
...Successfully got an update from the "prometheus-community" chart repository
...Successfully got an update from the "bitnami" chart repository
Update Complete. ⎈Happy Helming!⎈
Release "grafana-k8s-monitoring" does not exist. Installing it now.
NAME: grafana-k8s-monitoring
LAST DEPLOYED: Tue Aug 13 09:06:03 2024
NAMESPACE: default
STATUS: deployed
REVISION: 1
```
En cas d'erreur, vous pouvez faire

```bash
helm uninstall grafana-k8s-monitoring
```

Notons

![grafana_labs](/img/graf5.png)

## Visualisation dans `Grafana Loki`

On peut vérifier le statut de l'installation : après quelques minutes, les métriques du cluster remontent bien (cliquer sur 'Refresh' ou **changer de data-source** si besoin , tout doit être vert ...sauf Windows):

![grafana_labs](/img/graf6.png)


![grafana_labs](/img/graf7.png)

On peut ensuite explorer les métriques et les logs :

![grafana_labs](/img/graf8.png)

![grafana_labs](/img/graf9.png)

Pour note, les agents d'observabilité ```Alloy``` et ```NodeExporter``` sous déployés sous la forme de `DaemonSet`

```
 kubectl get ds        
NAME                                              DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR            AGE
grafana-k8s-monitoring-alloy-logs                 2         2         2       2            2           kubernetes.io/os=linux   67m
grafana-k8s-monitoring-prometheus-node-exporter   2         2         2       2            2           kubernetes.io/os=linux   67m
kepler                                            2         2         2       2            2           kubernetes.io/os=linux   67m
```

## Cleanup
```
helm delete grafana-k8s-monitoring
```
