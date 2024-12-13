# Objectif

C'est un lab très complet qui permet de voir l'ensemble de la stack d'observabilité sur une application moderne complexe avec de l'instrumentation au niveau de plusieurs composants codés dans des langages différents.


## Deploiement de l'apli demo-otel

Notre object est de publier l'applications suivante, de l'instrumenter et de la debugger :
![darchi](/img/demo-archi.png)

Nous avons fait le choix du backend [Grafana Cloud](https://grafana.com/), mais d'autres sont possibles tels que [Datadog](https://docs.datadoghq.com/fr/opentelemetry/guide/otel_demo_to_datadog/?tab=kubernetes) ou [Dynatrace](https://www.dynatrace.com/news/blog/opentelemetry-demo-application-with-dynatrace/) pour ne citer qu'eux...

En supposant que nous venons de réaliser le [Lab Logs](/Lab_Logs.md), repartons à vide sur notre cluster Kubernetes :
```
helm delete grafana-k8s-monitoring
```

Le cluster qui vous a été fourni (cf [Lab Logs](/Lab_Logs.md)) est déjà doté d'un ingress `nginx`, que nous ferons pointer sur le service frontend-proxy.

Vérifions que l'ingressClass est bien installée :

```
kubectl get ingressclass
```
On obtient :
```
NAME    CONTROLLER             PARAMETERS   AGE
nginx   k8s.io/ingress-nginx   <none>       82m
```
Un FQDN DNS est également attribué à l'IP publique de cet ingress, appellons-le `my-otel-demo.mydomain.com` dans le reste de ce document.

Les 2 IP publiques doivent concorder :
```
host my-otel-demo.mydomain.com
kubectl get svc -n ingress-nginx | grep LoadBalancer
```

Dans l'interface Grafana Cloud, créer un nouveau connecteur (on peut laisser le Service Namespace et le Service Instance ID vide)

![loki](/img/loki0.png)

![loki](/img/loki1.png)

On crée un répertoire dédié :
```
mkdir /home/otel-demo
cd /home/otel-demo
FQDN="my-otel-demo.mydomain.com"
```

En se basant sur sur la [documentation](https://github.com/open-telemetry/opentelemetry-helm-charts/tree/main/charts/opentelemetry-demo) et le [chart Helm](https://github.com/open-telemetry/opentelemetry-helm-charts/blob/main/charts/opentelemetry-demo/values.yaml) et ce qui est fournit par la procédure  initiée dans Grafana_Cloud, créer un fichier ```otel-values.yaml``` qui contiendra notamment la configuration du collecteur `opentelemetry` embarqué dans l'application de demo.

Cela pourrait ressembler à cela :

```
cat << EOF > otel-values.yaml
components:

  frontendProxy:
    enabled: true
    #service:
    #  type: LoadBalancer
    ingress:
      enabled: true
      ingressClassName: nginx
      annotations: {}
      hosts:
      ## a personnaliser
        - host: $FQDN
          paths:
            - path: /
              pathType: Prefix
              port: 8080

  frontend:
    enabled: true
    envOverrides:
      - name: PUBLIC_OTEL_EXPORTER_OTLP_TRACES_ENDPOINT
        ## a personnaliser
        value: http://$FQDN/otlp-http/v1/traces

  loadgenerator:
  ## si true, quota exhaustion chez grafana_cloud
    enabled: false

  imageprovider:
    enabled: true
  
  flagd:
    enabled: true
    #        - path: /flagservice

opensearch:
  enabled: false
grafana:
  enabled: false
prometheus:
  enabled: false
jaeger:
  enabled: false

opentelemetry-collector:
  ingress:
      enabled: true
      ingressClassName: nginx
      annotations: {}
      hosts:
      ## a personnaliser
        - host: $FQDN
          paths:
            - path: /otlp-httpd/
              pathType: Prefix
              port: 4318

  config:

    extensions:
      basicauth/grafana_cloud:
        client_auth:
        ## !!! a personnaliser, token à copier depuis GrafanaLabs
          username: "1009912"
          password: "glc_eyJvIj.....XXX"

    receivers:
      otlp:
        protocols:
          grpc:
          http:
            endpoint: 0.0.0.0:4318
      hostmetrics:
        scrapers:
          load:
          memory:

    exporters:
      otlphttp/grafana_cloud:
        ## a personnaliser eventuellement....
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
EOF
```

Puis
```
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
```

et enfin :
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
Visiter ce FQDN (en HTTP) pour générer de l'activité :

![otl-demo](/img/otel-demo.png)

## Analyse des traces

Si vous inspectez coté navigateur les requetes,vous verrez même les traces générées par le JS coté navigateur :

![browser](/img/browser-traces.png)

Dans le portail Grafana, renseigner le champ `service_name` et `service_namespace` (que vous pouvez retrouver dans la documentation du Helm Chart), ou comme sur une des images précédentes.

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

Dans le navigateur on voit la trace détaillée :
![trace](/img/trace1.png)

Qu'on peut retrouver dans Grafana :
![trace](/img/trace2.png)

Notez en bas à droite le `Status Message` qui donne la cause de l'erreur (i.e 'FeatureFlag enabled')

On peut également faire le chemin inverse, c-a-d chercher les spans d'erreur puis les investiguer :
![trace](/img/trace3.png)
