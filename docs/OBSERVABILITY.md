# TP S7 — Observabilité : Logs, Métriques, Traces

Documentation complète du TP S7 sur l'observabilité avec Prometheus, Grafana, Loki et Jaeger.

## Objectifs

- ✅ Collecter & visualiser métriques (Prometheus/Grafana)
- ✅ Centraliser les logs (Loki/Promtail)
- ✅ Traçage distribué OpenTelemetry → Jaeger
- ✅ Créer et documenter 2+ alertes pertinentes

## Architecture Observabilité

```mermaid
flowchart TB
    subgraph Apps["Applications (namespace: workshop)"]
        API[API Pods]
        Front[Front Pods]
    end
    
    subgraph Observability["Stack Observabilité (namespace: observability)"]
        direction TB
        Prometheus[Prometheus<br/>Métriques]
        Grafana[Grafana<br/>Visualisation]
        Loki[Loki<br/>Logs]
        Promtail[Promtail<br/>Collecteur logs]
        Jaeger[Jaeger<br/>Traces]
        AlertManager[AlertManager<br/>Alertes]
    end
    
    API -->|/metrics| Prometheus
    Front -->|/metrics| Prometheus
    
    API -->|logs stdout| Promtail
    Front -->|logs stdout| Promtail
    Promtail -->|push| Loki
    
    API -->|traces OTLP| Jaeger
    
    Prometheus -->|datasource| Grafana
    Loki -->|datasource| Grafana
    Jaeger -->|datasource| Grafana
    
    Prometheus -->|alerts| AlertManager
    
    style Prometheus fill:#ff6b6b,stroke:#333,stroke-width:2px,color:#000
    style Grafana fill:#5fa9f3,stroke:#333,stroke-width:2px,color:#000
    style Loki fill:#f4a261,stroke:#333,stroke-width:2px,color:#000
    style Jaeger fill:#2a9d8f,stroke:#333,stroke-width:2px,color:#000
```

## Prérequis

- Cluster Kubernetes (kind, minikube, etc.)
- kubectl
- Helm 3
- Applications déployées (namespace workshop)

## Déploiement rapide

```bash
./scripts/deploy-observability.sh
```

Le script installe automatiquement :
1. **kube-prometheus-stack** (Prometheus + Grafana + AlertManager)
2. **Loki + Promtail** (logs)
3. **Jaeger Operator + instance** (tracing)
4. **ServiceMonitors** (scraping métriques)
5. **PrometheusRules** (alertes)

## Déploiement manuel

### 1. Installer kube-prometheus-stack

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install monitor prometheus-community/kube-prometheus-stack \
  -n observability \
  --create-namespace \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --set grafana.adminPassword=admin \
  --wait --timeout=10m
```

### 2. Installer Loki + Promtail

```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

helm install loki grafana/loki-stack \
  -n observability \
  --set promtail.enabled=true \
  --set loki.persistence.enabled=false \
  --wait --timeout=5m
```

### 3. Installer Jaeger

```bash
# Installer l'opérateur
kubectl apply -n observability -f \
  https://github.com/jaegertracing/jaeger-operator/releases/download/v1.51.0/jaeger-operator.yaml

kubectl wait --for=condition=available deployment/jaeger-operator \
  -n observability --timeout=120s

# Déployer une instance Jaeger
cat <<YAML | kubectl apply -f -
apiVersion: jaegertracing.io/v1
kind: Jaeger
metadata:
  name: simplest
  namespace: observability
spec:
  strategy: allInOne
  storage:
    type: memory
YAML
```

### 4. Déployer les manifests

```bash
kubectl apply -f manifests/observability/
```

## Accès aux interfaces

### Grafana

```bash
kubectl port-forward -n observability svc/monitor-grafana 3000:80
```

- **URL** : http://localhost:3000
- **Login** : admin / admin
- **Dashboards** : Workshop API - Observabilité

### Prometheus

```bash
kubectl port-forward -n observability svc/monitor-kube-prometheus-prometheus 9090:9090
```

- **URL** : http://localhost:9090
- **Targets** : http://localhost:9090/targets
- **Alertes** : http://localhost:9090/alerts

### Jaeger UI

```bash
kubectl port-forward -n observability svc/simplest-query 16686:16686
```

- **URL** : http://localhost:16686
- **Service** : Sélectionner "api" ou "front"

### Loki (via Grafana)

Datasource déjà configuré dans Grafana :
- Nom : `Loki`
- URL : `http://loki:3100`

Exemple de requête LogQL :
```
{namespace="workshop"} |= "error"
```

## Métriques collectées

### Métriques système (kube-state-metrics)

- `kube_pod_status_phase` : État des pods
- `kube_pod_container_status_restarts_total` : Redémarrages
- `kube_pod_container_resource_limits` : Limites CPU/RAM
- `container_cpu_usage_seconds_total` : Usage CPU
- `container_memory_working_set_bytes` : Usage mémoire

### Métriques applicatives (si exposées)

- `http_requests_total` : Nombre de requêtes HTTP
- `http_request_duration_seconds` : Latence des requêtes
- `http_request_duration_seconds_bucket` : Histogramme (p95, p99)

### ServiceMonitor

Le `ServiceMonitor` configure Prometheus pour scraper les métriques :

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: api-monitor
  namespace: observability
spec:
  selector:
    matchLabels:
      app: api
  namespaceSelector:
    matchNames:
      - workshop
  endpoints:
    - port: http
      interval: 30s
      path: /metrics
```

## Logs centralisés

### Fonctionnement Loki + Promtail

1. **Promtail** : DaemonSet qui collecte les logs de tous les pods
2. **Loki** : Base de données de logs (comme Prometheus pour les logs)
3. **Grafana** : Interface de requête et visualisation

### Requêtes LogQL

```logql
# Tous les logs du namespace workshop
{namespace="workshop"}

# Logs d'erreur uniquement
{namespace="workshop"} |= "error"

# Logs de l'API avec parsing JSON
{namespace="workshop", app="api"} | json

# Compter les erreurs par minute
sum(count_over_time({namespace="workshop"} |= "error" [1m]))
```

### Panel Logs dans Grafana

Le dashboard inclut un panel "Logs" qui affiche en temps réel les logs du namespace workshop.

## Tracing distribué

### Jaeger

Jaeger permet de tracer les requêtes à travers les microservices.

### Instrumentation OpenTelemetry (exemple)

Pour une application Node.js :

```javascript
const { NodeTracerProvider } = require('@opentelemetry/sdk-trace-node');
const { JaegerExporter } = require('@opentelemetry/exporter-jaeger');

const provider = new NodeTracerProvider();
const exporter = new JaegerExporter({
  endpoint: 'http://simplest-collector.observability:14268/api/traces',
});

provider.addSpanProcessor(new SimpleSpanProcessor(exporter));
provider.register();
```

### Visualisation dans Jaeger

1. Ouvrir http://localhost:16686
2. Sélectionner le service (api, front)
3. Cliquer sur "Find Traces"
4. Analyser les spans pour identifier les bottlenecks

## Alerting

### Alertes configurées

5 alertes PrometheusRule déployées :

| Alerte | Seuil | Durée | Sévérité |
|--------|-------|-------|----------|
| **HighErrorRate** | Taux 5xx > 2% | 10min | Warning |
| **PodHighRestarts** | Redémarrages > 5 | 15min | Warning |
| **PodNotReady** | Pod non-Running | 5min | Critical |
| **HighCPUSaturation** | CPU > 80% limites | 10min | Warning |
| **HighLatencyP95** | p95 > 300ms | 10min | Warning |

### PrometheusRule

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: workshop-alerts
  namespace: observability
  labels:
    release: monitor
spec:
  groups:
    - name: api.rules
      rules:
        - alert: HighErrorRate
          expr: |
            sum(rate(http_requests_total{status=~"5..",namespace="workshop"}[5m]))
            / sum(rate(http_requests_total{namespace="workshop"}[5m])) > 0.02
          for: 10m
          labels:
            severity: warning
          annotations:
            summary: "Taux d'erreurs 5xx élevé"
            description: ">2% d'erreurs détectées"
            runbook: "docs/RUNBOOK-ALERTS.md#higherrorrate"
```

### Vérifier les alertes

```bash
# Lister les PrometheusRules
kubectl get prometheusrules -n observability

# Voir les alertes actives dans Prometheus
# http://localhost:9090/alerts

# Voir les alertes dans Grafana
# Alerting > Alert Rules
```

### Runbook d'exploitation

Voir [RUNBOOK-ALERTS.md](RUNBOOK-ALERTS.md) pour les procédures détaillées de résolution.

## Dashboard Grafana

### Panels inclus

1. **Requêtes par seconde (RPS)** : Trafic total
2. **Taux d'erreurs 5xx** : % d'erreurs avec seuil à 1%
3. **Latence p50, p95, p99** : Distribution de latence
4. **Saturation CPU** : Usage CPU par pod
5. **Saturation Mémoire** : Usage RAM par pod
6. **Nombre de pods Running** : Disponibilité
7. **Redémarrages pods** : Stabilité
8. **Logs récents (Loki)** : Stream de logs en temps réel

### Import du dashboard

```bash
# Via l'interface Grafana
# Dashboards > Import > Upload JSON file
# Fichier: dashboards/workshop-api-dashboard.json
```

Ou via API :

```bash
DASHBOARD=$(cat dashboards/workshop-api-dashboard.json)
curl -X POST http://admin:admin@localhost:3000/api/dashboards/db \
  -H "Content-Type: application/json" \
  -d "$DASHBOARD"
```

## Golden Signals (SRE)

Le dashboard couvre les **4 Golden Signals** :

| Signal | Métrique | Panel |
|--------|----------|-------|
| **Latency** | p50, p95, p99 | "Latence p50, p95, p99" |
| **Traffic** | RPS | "Requêtes par seconde" |
| **Errors** | Taux 5xx | "Taux d'erreurs (5xx)" |
| **Saturation** | CPU, RAM | "Saturation CPU/Mémoire" |

## Vérifications

### 1. Vérifier Prometheus scrape les targets

```bash
# Port-forward Prometheus
kubectl port-forward -n observability svc/monitor-kube-prometheus-prometheus 9090:9090

# Ouvrir http://localhost:9090/targets
# Vérifier que les ServiceMonitors sont "UP"
```

### 2. Vérifier les logs dans Loki

```bash
# Via Grafana Explore
# Datasource: Loki
# Requête: {namespace="workshop"}
```

### 3. Vérifier les traces dans Jaeger

```bash
# Port-forward Jaeger
kubectl port-forward -n observability svc/simplest-query 16686:16686

# Ouvrir http://localhost:16686
# Service: api
# Find Traces
```

### 4. Tester une alerte

```bash
# Générer des erreurs pour déclencher HighErrorRate
kubectl run load-test -n workshop --image=curlimages/curl --rm -it -- sh -c \
  'while true; do curl http://api/status/500; sleep 1; done'

# Attendre 10 minutes
# Vérifier dans Prometheus: http://localhost:9090/alerts
```

## Structure des fichiers

```
.
├── scripts/
│   └── deploy-observability.sh       # Déploiement automatique
├── manifests/observability/
│   ├── servicemonitor-api.yaml       # Scraping métriques API
│   └── prometheusrules-alerts.yaml   # 5 alertes configurées
├── dashboards/
│   └── workshop-api-dashboard.json   # Dashboard Grafana
└── docs/
    ├── OBSERVABILITY.md              # Ce fichier
    └── RUNBOOK-ALERTS.md             # Runbook des alertes
```

## Troubleshooting

### Prometheus ne scrape pas les métriques

```bash
# Vérifier les ServiceMonitors
kubectl get servicemonitors -n observability

# Vérifier les targets dans Prometheus
# http://localhost:9090/targets

# Vérifier les labels du Service
kubectl get svc -n workshop --show-labels

# Le Service doit avoir le label "app: api" pour matcher le ServiceMonitor
```

### Pas de logs dans Loki

```bash
# Vérifier que Promtail tourne
kubectl get pods -n observability -l app=promtail

# Vérifier les logs de Promtail
kubectl logs -n observability -l app=promtail

# Tester Loki directement
kubectl port-forward -n observability svc/loki 3100:3100
curl http://localhost:3100/ready
```

### Pas de traces dans Jaeger

```bash
# Vérifier Jaeger
kubectl get pods -n observability -l app.kubernetes.io/instance=simplest

# L'application doit être instrumentée avec OpenTelemetry
# et exporter vers: http://simplest-collector.observability:14268/api/traces
```

### Alertes ne se déclenchent pas

```bash
# Vérifier les PrometheusRules
kubectl get prometheusrules -n observability

# Vérifier que les labels sont corrects
kubectl get prometheusrules workshop-alerts -n observability -o yaml

# Les PrometheusRules doivent avoir le label "release: monitor"
# pour être détectées par kube-prometheus-stack
```

## Bonnes pratiques

1. **Naming des métriques** : Suivre la convention Prometheus (`<namespace>_<name>_<unit>`)
2. **Labels** : Limiter le nombre de labels (cardinalité)
3. **Retention** : Configurer la rétention selon les besoins (défaut: 15j)
4. **Alertes** : Éviter les alertes bruyantes (false positives)
5. **Runbooks** : Documenter chaque alerte avec procédure de résolution
6. **Dashboards** : Structurer par service/composant
7. **Logs** : Utiliser un format structuré (JSON)
8. **Traces** : Instrumenter les points critiques uniquement (sampling)

## Livrables S7

- ✅ **Dashboard Grafana** : `dashboards/workshop-api-dashboard.json`
- ✅ **2+ Alertes** : 5 alertes dans `manifests/observability/prometheusrules-alerts.yaml`
- ✅ **Runbook alertes** : `docs/RUNBOOK-ALERTS.md`
- ✅ **ServiceMonitor** : `manifests/observability/servicemonitor-api.yaml`
- ✅ **Script déploiement** : `scripts/deploy-observability.sh`
- ✅ **Documentation** : Ce fichier

## Évaluation (10 pts)

- **Dashboard (5 pts)** : Latence, erreurs, saturation couverts
- **Alertes (3 pts)** : 5 alertes + runbook documenté
- **Traces (2 pts)** : Jaeger installé et accessible

## Ressources

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Dashboards](https://grafana.com/grafana/dashboards/)
- [Loki LogQL](https://grafana.com/docs/loki/latest/logql/)
- [Jaeger Tracing](https://www.jaegertracing.io/docs/)
- [OpenTelemetry](https://opentelemetry.io/docs/)
- [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)

## Next Steps

- Configurer Alertmanager pour envoyer des notifications (Slack, email)
- Ajouter des dashboards spécifiques par service
- Implémenter le tracing dans les applications
- Configurer la persistance Loki/Prometheus
- Automatiser les backups des dashboards Grafana
- Créer des SLO/SLI basés sur les métriques réelles

