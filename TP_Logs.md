# Objectifs

- Export de logs depuis un serveur Linux avec l’agent Beats (FileBeats) vers un indexeur Logstash
- Export de logs depuis un cluster Kubernetes
- Visualisation dans Grafana Loki

## Export de logs depuis K8s

Pré-requis :
- Créer un compte (gratuit) sur [Grafanalabs](https://grafana.com/)
- Obtenir un accès à un cluster k8s


Testons l'accès à notre cluster :
```
% kubectl get nodes 
```

On otbient ceci :
```
+ kubectl get nodes
NAME                   STATUS   ROLES    AGE     VERSION
pool-8mwxj0101-bacu0   Ready    <none>   5m58s   v1.30.2
pool-8mwxj0101-bacu1   Ready    <none>   5m57s   v1.30.2
```
Vérifion que ```helm``` est bien installé
```
helm version
```
Dans le portail GrafanaLabs, déroulons la procédure d'attachement d'un cluster k8s

![grafana_labs](/img/graf1.png)

![grafana_labs](/img/graf2.png)

![grafana_labs](/img/graf3.png)

Avec ```Helm``` nous pouvons déployons la stack de monitoring (copier/coller de l'écran de Grafanalabs) :

![grafana_labs](/img/graf4.png)

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
...Successfully got an update from the "ingress-nginx" chart repository
...Successfully got an update from the "k8spacket" chart repository
...Successfully got an update from the "jetstack" chart repository
...Successfully got an update from the "kubecost" chart repository
...Successfully got an update from the "traefik" chart repository
...Successfully got an update from the "open-telemetry" chart repository
...Successfully got an update from the "argo" chart repository
...Successfully got an update from the "datadog" chart repository
...Successfully got an update from the "cilium" chart repository
...Successfully got an update from the "grafana" chart repository
...Successfully got an update from the "prometheus-community" chart repository
...Successfully got an update from the "my-repo" chart repository
...Successfully got an update from the "bitnami" chart repository
Update Complete. ⎈Happy Helming!⎈
Release "grafana-k8s-monitoring" does not exist. Installing it now.
NAME: grafana-k8s-monitoring
LAST DEPLOYED: Tue Aug 13 09:06:03 2024
NAMESPACE: default
STATUS: deployed
REVISION: 1
```
Notons

![grafana_labs](/img/graf5.png)

On peut vérifier le statut de l'installation :

![grafana_labs](/img/graf6.png)

Après quelques instants, les métriques du cluster remontent bien (cliquer sur 'Refresh' ou changer de data-source si besoin):

![grafana_labs](/img/graf7.png)

On peut ensuite explorer les métriques et les logs :

![grafana_labs](/img/graf8.png)

![grafana_labs](/img/graf9.png)

Pour note, les agents d'observabilité ```Alloy``` et ```NodeExporter``` sous déployés sous la forme de DaemonSet

```
 kubectl get ds        
+ kubectl get ds
NAME                                              DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR            AGE
grafana-k8s-monitoring-alloy-logs                 2         2         2       2            2           kubernetes.io/os=linux   67m
grafana-k8s-monitoring-prometheus-node-exporter   2         2         2       2            2           kubernetes.io/os=linux   67m
kepler                                            2         2         2       2            2           kubernetes.io/os=linux   67m
```

 
