# Dashboards Grafana - S7

## Import du dashboard

### Méthode 1 : Via l'interface Grafana

1. Accéder à Grafana
   ```bash
   kubectl port-forward -n observability svc/monitor-grafana 3000:80
   ```
   Ouvrir http://localhost:3000 (admin/admin)

2. Aller dans **Dashboards** > **Import**

3. Cliquer sur **Upload JSON file**

4. Sélectionner `workshop-api-dashboard.json`

5. Choisir le datasource **Prometheus** et **Loki**

6. Cliquer sur **Import**

### Méthode 2 : Via API

```bash
# Depuis le répertoire racine du projet
DASHBOARD=$(cat dashboards/workshop-api-dashboard.json)

kubectl port-forward -n observability svc/monitor-grafana 3000:80 &

sleep 3

curl -X POST http://admin:admin@localhost:3000/api/dashboards/db \
  -H "Content-Type: application/json" \
  -d "$DASHBOARD"
```

### Méthode 3 : ConfigMap (persistant)

```bash
# Créer un ConfigMap avec le dashboard
kubectl create configmap workshop-dashboard \
  -n observability \
  --from-file=workshop-api-dashboard.json \
  --dry-run=client -o yaml | kubectl apply -f -

# Ajouter le label pour que Grafana le détecte
kubectl label configmap workshop-dashboard \
  -n observability \
  grafana_dashboard=1
```

## Panels inclus

Le dashboard `workshop-api-dashboard.json` contient :

### 1. Requêtes par seconde (RPS)
- **Métrique** : `sum(rate(http_requests_total{namespace="workshop"}[5m]))`
- **Type** : Graph
- **Description** : Volume de trafic total

### 2. Taux d'erreurs (5xx)
- **Métrique** : `sum(rate(http_requests_total{status=~"5..",namespace="workshop"}[5m])) / sum(rate(http_requests_total{namespace="workshop"}[5m])) * 100`
- **Type** : Graph
- **Seuil** : 1% (ligne rouge)
- **Description** : Pourcentage d'erreurs serveur

### 3. Latence p50, p95, p99
- **Métriques** :
  - p50: `histogram_quantile(0.50, ...)`
  - p95: `histogram_quantile(0.95, ...)`
  - p99: `histogram_quantile(0.99, ...)`
- **Type** : Graph
- **Seuil** : 300ms (ligne rouge pour p95)
- **SLO** : p95 < 300ms

### 4. Saturation CPU
- **Métrique** : `sum(rate(container_cpu_usage_seconds_total{namespace="workshop"}[5m])) by (pod)`
- **Type** : Graph
- **Seuil** : 80%
- **Description** : Usage CPU par pod

### 5. Saturation Mémoire
- **Métrique** : `sum(container_memory_working_set_bytes{namespace="workshop"}) by (pod) / sum(kube_pod_container_resource_limits{resource="memory"}) by (pod)`
- **Type** : Graph
- **Seuil** : 80%
- **Description** : Usage mémoire par pod

### 6. Nombre de pods Running
- **Métrique** : `count(kube_pod_status_phase{namespace="workshop",phase="Running"})`
- **Type** : Stat
- **Description** : Disponibilité

### 7. Redémarrages de pods (10min)
- **Métrique** : `sum(increase(kube_pod_container_status_restarts_total{namespace="workshop"}[10m]))`
- **Type** : Stat
- **Seuils** :
  - Vert : 0
  - Jaune : 3
  - Rouge : 5
- **Description** : Stabilité des pods

### 8. Logs récents (Loki)
- **Requête LogQL** : `{namespace="workshop"}`
- **Type** : Logs
- **Datasource** : Loki
- **Description** : Stream de logs en temps réel

## Variables de template (optionnel)

Pour rendre le dashboard réutilisable, vous pouvez ajouter des variables :

```json
{
  "templating": {
    "list": [
      {
        "name": "namespace",
        "type": "query",
        "query": "label_values(kube_pod_info, namespace)",
        "current": {
          "text": "workshop",
          "value": "workshop"
        }
      },
      {
        "name": "app",
        "type": "query",
        "query": "label_values(kube_pod_info{namespace=\"$namespace\"}, pod)",
        "current": {
          "text": "All",
          "value": "$__all"
        },
        "multi": true
      }
    ]
  }
}
```

Puis remplacer `namespace="workshop"` par `namespace="$namespace"` dans les requêtes.

## Datasources requis

Le dashboard nécessite 2 datasources configurés dans Grafana :

### Prometheus
- **Nom** : `Prometheus`
- **Type** : `prometheus`
- **URL** : `http://monitor-kube-prometheus-prometheus.observability:9090`
- **Accès** : Server (default)

### Loki
- **Nom** : `Loki`
- **Type** : `loki`
- **URL** : `http://loki.observability:3100`
- **Accès** : Server (default)

Ces datasources sont automatiquement configurés par kube-prometheus-stack et loki-stack.

## Vérification

```bash
# Lister les datasources
kubectl port-forward -n observability svc/monitor-grafana 3000:80 &
curl -s http://admin:admin@localhost:3000/api/datasources | jq '.[] | {name, type, url}'

# Lister les dashboards
curl -s http://admin:admin@localhost:3000/api/search?type=dash-db | jq '.'
```

## Customisation

Pour personnaliser le dashboard :

1. Ouvrir le dashboard dans Grafana
2. Modifier les panels (Edit)
3. Sauvegarder (Save Dashboard)
4. Exporter le JSON (Share > Export > Save to file)
5. Remplacer `workshop-api-dashboard.json`

## Golden Signals

Le dashboard couvre les **4 Golden Signals** (SRE) :

| Signal | Panel | Métrique clé |
|--------|-------|--------------|
| **Latency** | Panel 3 | p50, p95, p99 |
| **Traffic** | Panel 1 | RPS |
| **Errors** | Panel 2 | Taux 5xx |
| **Saturation** | Panels 4 & 5 | CPU, RAM |

## Troubleshooting

### Pas de données dans les panels

```bash
# Vérifier que Prometheus scrape les métriques
kubectl port-forward -n observability svc/monitor-kube-prometheus-prometheus 9090:9090

# Ouvrir http://localhost:9090/targets
# Vérifier que les targets sont "UP"

# Vérifier les ServiceMonitors
kubectl get servicemonitors -n observability
```

### Panel Loki vide

```bash
# Vérifier que Promtail collecte les logs
kubectl logs -n observability -l app=promtail --tail=50

# Tester Loki
kubectl port-forward -n observability svc/loki 3100:3100
curl -G -s "http://localhost:3100/loki/api/v1/query" \
  --data-urlencode 'query={namespace="workshop"}' | jq '.status'
```

### Métriques applicatives manquantes

Si les métriques `http_requests_total` ou `http_request_duration_seconds` ne sont pas disponibles :

1. L'application doit exposer des métriques au format Prometheus sur `/metrics`
2. Le ServiceMonitor doit être configuré pour scraper ce endpoint
3. Vérifier avec :
   ```bash
   kubectl exec -n workshop deploy/api -- curl localhost:8080/metrics
   ```

Pour les applications sans métriques, seules les métriques système (CPU, RAM, pods) seront disponibles.

## Références

- [Grafana Dashboards Best Practices](https://grafana.com/docs/grafana/latest/dashboards/build-dashboards/best-practices/)
- [PromQL Queries](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [LogQL Queries](https://grafana.com/docs/loki/latest/logql/)
- [Golden Signals](https://sre.google/sre-book/monitoring-distributed-systems/)

