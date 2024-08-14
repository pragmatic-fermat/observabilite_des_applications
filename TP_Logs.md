# Objectifs

- Export de logs depuis un serveur Linux avec l’agent Beats (FileBeats) vers un indexeur Logstash
- Visualisation dans Elastic / Kibana
- Export de logs depuis un cluster Kubernetes avec un DaemonSet Fluent Bit
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

 

## Deploiement de l'apli demo-otel

  
Repartons à vide :
```
helm delete grafana-k8s-monitoring
```

Dans l'interface Grafana, créer un nouveau conecteur 

![loki](/img/loki0.png)

![loki](/img/loki1.png)

En se basant sur sur la [documentation](https://github.com/open-telemetry/opentelemetry-helm-charts/tree/main/charts/opentelemetry-demo) et le [chart Helm](https://github.com/open-telemetry/opentelemetry-helm-charts/blob/main/charts/opentelemetry-demo/values.yaml) et ce qui est fournit par la procédure  initiée dans Grafana_Cloud, créer un fichier ```otel-values.yaml``` qui contientdra notamment la configuration du collecteur opentelemetry embarquée dans l'application de demo.

Cela pourrait ressembler à cela :

```
components:
  frontendProxy:
    service:
      type: LoadBalancer
  loadgenerator:
    enabled: false
opensearch:
    enabled: false
grafana:
    enabled: false
prometheus:
  enabled: false
jaeger:
  enabled: false

opentelemetry-collector:
  config:

    extensions:
      basicauth/grafana_cloud:
        client_auth:
          username: "1009912"
          password: "glc_eyJxxx"

    receivers:
      otlp:
        protocols:
          grpc:
          http:
      hostmetrics:
        scrapers:
          load:
          memory:

    exporters:
      otlphttp/grafana_cloud:
        endpoint: "https://otlp-gateway-prod-eu-west-2.grafana.net/otlp"
        auth:
          authenticator: basicauth/grafana_cloud

    processors:
      batch:
        timeout: 5s

    service:
      extensions: [basicauth/grafana_cloud, health_check]
      pipelines:
        traces:
          receivers: [otlp]
          processors: [batch]
          exporters: [otlphttp/grafana_cloud, debug]
        metrics:
          receivers: [otlp, hostmetrics]
          processors: [batch]
          exporters: [otlphttp/grafana_cloud, debug]
        logs:
          receivers: [otlp]
          processors: [batch]
          exporters: [otlphttp/grafana_cloud, debug]
```

Puis

```
helm install my-otel-demo open-telemetry/opentelemetry-demo --values otel-values.yaml
```

On obtient ceci :

```
NAME: my-otel-demo
LAST DEPLOYED: Tue Aug 13 19:59:36 2024
NAMESPACE: default
STATUS: deployed
REVISION: 1
NOTES:

=======================================================================================

  
  

██████╗ ████████╗███████╗██╗ ██████╗ ███████╗███╗ ███╗ ██████╗
██╔═══██╗╚══██╔══╝██╔════╝██║ ██╔══██╗██╔════╝████╗ ████║██╔═══██╗
██║ ██║ ██║ █████╗ ██║ ██║ ██║█████╗ ██╔████╔██║██║ ██║
██║ ██║ ██║ ██╔══╝ ██║ ██║ ██║██╔══╝ ██║╚██╔╝██║██║ ██║
╚██████╔╝ ██║ ███████╗███████╗ ██████╔╝███████╗██║ ╚═╝ ██║╚██████╔╝
╚═════╝ ╚═╝ ╚══════╝╚══════╝ ╚═════╝ ╚══════╝╚═╝ ╚═╝ ╚═════╝



- All services are available via the Frontend proxy: http://localhost:8080

by running these commands:

kubectl --namespace default port-forward svc/my-otel-demo-frontendproxy 8080:8080  

The following services are available at these paths once the proxy is exposed:

Webstore http://localhost:8080/
Grafana http://localhost:8080/grafana/
Load Generator UI http://localhost:8080/loadgen/
Jaeger UI http://localhost:8080/jaeger/ui/
```
Identifier l'IP publique du LoadBalancer par `kubectl get svc` et visiter cette IP sur le port 8080 pour générer des logs/traces.

Dans le portail Grafana, renseigner le champ `service_name` et `service_namespace` (que vous pouvez retrouver dans la documentation du Helm Chart)

![loki](/img/loki2.png)

Normalement le test devrait être OK dans le portail Grafana :

![loki](/img/loki2.png)

Dans le portail Grafana, on retrouve les logs : 

![loki](/img/loki5.png)

Identifier un `trace_id`

![loki](/img/loki6.png)

Cherchez ce `trace_id` chercher dans tempo :

![loki](/img/loki4.png)

Il est alors possible d'avoir cote à coté **corrélés** logs et traces

![loki](/img/loki3.png)


## Extra : Feature FLag

Il est possible de provoquer des pannes, via un FeatureFlag.

Vérifions son état :
```
curl -X POST "http://IP_PUB_ftend_proxy:8080/flagservice//flagd.evaluation.v1.Service/ResolveBoolean" \       
  -d '{"flagKey":"productCatalogFailure","context":{}}' -H "Content-Type: application/json"
```

On obtient :
```
{"value":false,"reason":"STATIC","variant":"off","metadata":{}}%
```   

 Editons le configmap en ```vi``` pour activer les erreurs sur le service ```ProductCatalog``` :
```
 kubectl edit cm/my-otel-demo-flagd-config 
```

La ligne à modifier est celle qui va contenir ``` "defaultVariant": "on" ``` :
```
[..]
      "flags": {
        "productCatalogFailure": {
          "description": "Fail product catalog service on a specific product",
          "state": "ENABLED",
          "variants": {
            "on": true,
            "off": false
          },
          "defaultVariant": "on"
        },
[..]
```

L'application est immédiate :
```
curl -X POST "http://IP_PUB_ftend_proxy:8080/flagservice/flagd.evaluation.v1.Service/ResolveBoolean" \
  -d '{"flagKey":"productCatalogFailure","context":{}}' -H "Content-Type: application/json"
  ```
qui donne :
```
{"value":true,"reason":"STATIC","variant":"on","metadata":{}}  
```

On constate alors que la route ```/product/OLJCESPC7Z``` est KO
![ko](/img/otel-ko.png)