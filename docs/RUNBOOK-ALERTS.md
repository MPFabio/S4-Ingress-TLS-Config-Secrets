# Runbook Alertes - Observabilité S7

Guide d'exploitation pour gérer les alertes Prometheus déployées dans le TP S7.

## Table des matières

1. [HighErrorRate](#higherrorrate)
2. [PodHighRestarts](#podhighrestarts)
3. [PodNotReady](#podnotready)
4. [HighCPUSaturation](#highcpusaturation)
5. [HighLatencyP95](#highlatencyp95)

---

## HighErrorRate

### Description

Alerte déclenchée lorsque le taux d'erreurs 5xx dépasse **2%** sur une fenêtre de **10 minutes**.

### Seuil

- **Métrique** : `sum(rate(http_requests_total{status=~"5..",namespace="workshop"}[5m])) / sum(rate(http_requests_total{namespace="workshop"}[5m]))`
- **Seuil** : > 2% (0.02)
- **Durée** : 10 minutes
- **Sévérité** : Warning

### Impact

- Dégradation de la qualité de service
- Violation potentielle du SLO d'erreurs (< 1%)
- Expérience utilisateur impactée

### Diagnostic

```bash
# 1. Vérifier les logs récents des pods API
kubectl logs -n workshop -l app=api --tail=100 | grep -i error

# 2. Vérifier les événements du namespace
kubectl get events -n workshop --sort-by='.lastTimestamp' | tail -20

# 3. Inspecter les métriques Prometheus
# Aller sur http://localhost:9090 et exécuter:
# sum(rate(http_requests_total{namespace="workshop"}[5m])) by (status)

# 4. Vérifier l'état des pods
kubectl get pods -n workshop -o wide
kubectl describe pod <pod-name> -n workshop

# 5. Consulter les logs Loki via Grafana
# {namespace="workshop"} |= "error" | json | line_format "{{.msg}}"
```

### Actions correctives

1. **Identifier la source des erreurs**
   ```bash
   # Analyser les logs pour trouver la cause racine
   kubectl logs -n workshop -l app=api --tail=500 | grep "5[0-9][0-9]"
   ```

2. **Vérifier les dépendances**
   ```bash
   # Tester la connectivité aux services backend
   kubectl exec -n workshop deploy/api -- curl -v http://backend-service
   ```

3. **Redémarrer les pods si nécessaire**
   ```bash
   kubectl rollout restart deployment/api -n workshop
   ```

4. **Scaler horizontalement si surchargé**
   ```bash
   kubectl scale deployment/api -n workshop --replicas=4
   ```

5. **Investiguer les modifications récentes**
   ```bash
   kubectl rollout history deployment/api -n workshop
   # Rollback si nécessaire
   kubectl rollout undo deployment/api -n workshop
   ```

### Prévention

- Activer les health checks (readinessProbe/livenessProbe)
- Implémenter circuit breaker pour les dépendances
- Tester les déploiements en staging
- Monitorer les métriques en continu

---

## PodHighRestarts

### Description

Alerte déclenchée lorsqu'un pod redémarre plus de **5 fois en 10 minutes**.

### Seuil

- **Métrique** : `increase(kube_pod_container_status_restarts_total{namespace="workshop"}[10m])`
- **Seuil** : > 5 redémarrages
- **Durée** : 15 minutes
- **Sévérité** : Warning

### Impact

- Service instable
- Perte potentielle de requêtes
- Dégradation de performance

### Diagnostic

```bash
# 1. Identifier les pods avec redémarrages
kubectl get pods -n workshop --sort-by='.status.containerStatuses[0].restartCount'

# 2. Consulter les logs du pod
POD=$(kubectl get pods -n workshop -l app=api -o jsonpath='{.items[0].metadata.name}')
kubectl logs -n workshop $POD --previous  # Logs avant le restart
kubectl logs -n workshop $POD             # Logs actuels

# 3. Vérifier les événements du pod
kubectl describe pod $POD -n workshop | grep -A 20 Events

# 4. Inspecter les métriques de ressources
kubectl top pod $POD -n workshop

# 5. Vérifier les probes
kubectl get pod $POD -n workshop -o jsonpath='{.spec.containers[*].livenessProbe}'
```

### Actions correctives

1. **Analyser la cause du crash**
   - OOMKilled → Augmenter les limites mémoire
   - CrashLoopBackOff → Corriger l'erreur applicative
   - Liveness probe fail → Ajuster le probe ou corriger l'app

2. **OOMKilled (Out of Memory)**
   ```bash
   # Augmenter les limites mémoire
   kubectl set resources deployment/api -n workshop \
     --limits=memory=512Mi \
     --requests=memory=256Mi
   ```

3. **CrashLoopBackOff**
   ```bash
   # Vérifier la configuration
   kubectl get configmap -n workshop
   kubectl get secret -n workshop
   
   # Valider les variables d'environnement
   kubectl describe deployment/api -n workshop | grep -A 10 Environment
   ```

4. **Liveness probe trop stricte**
   ```yaml
   # Ajuster dans le deployment
   livenessProbe:
     httpGet:
       path: /healthz
       port: 8080
     initialDelaySeconds: 30  # Augmenter
     periodSeconds: 10
     failureThreshold: 5      # Augmenter
   ```

### Prévention

- Définir correctement requests/limits
- Configurer des probes adaptées
- Tester les changements en staging
- Monitorer l'utilisation mémoire

---

## PodNotReady

### Description

Alerte déclenchée lorsqu'un pod n'est pas en état `Running` pendant **5 minutes**.

### Seuil

- **Métrique** : `kube_pod_status_phase{namespace="workshop",phase!="Running"}`
- **Seuil** : > 0
- **Durée** : 5 minutes
- **Sévérité** : Critical

### Diagnostic

```bash
# 1. Lister les pods non-Running
kubectl get pods -n workshop --field-selector=status.phase!=Running

# 2. Vérifier l'état détaillé
kubectl describe pod <pod-name> -n workshop

# 3. Vérifier les ressources du node
kubectl top nodes
kubectl describe node <node-name>

# 4. Vérifier les PVC si applicable
kubectl get pvc -n workshop
```

### Actions correctives

Selon l'état du pod :

**Pending**
```bash
# Vérifier les événements
kubectl describe pod <pod-name> -n workshop

# Causes possibles:
# - Ressources insuffisantes → Scaler le cluster
# - PVC non bound → Vérifier le StorageClass
# - ImagePullBackOff → Vérifier l'image
```

**ImagePullBackOff**
```bash
# Vérifier l'image
kubectl describe pod <pod-name> -n workshop | grep Image

# Corriger l'image dans le deployment
kubectl set image deployment/api api=correctimage:tag -n workshop
```

**CrashLoopBackOff**
```bash
# Voir section PodHighRestarts
kubectl logs <pod-name> -n workshop --previous
```

---

## HighCPUSaturation

### Description

Alerte déclenchée lorsque l'utilisation CPU dépasse **80%** des limites pendant **10 minutes**.

### Seuil

- **Métrique** : `sum(rate(container_cpu_usage_seconds_total{namespace="workshop"}[5m])) by (pod) / sum(kube_pod_container_resource_limits{resource="cpu"}) by (pod)`
- **Seuil** : > 0.80 (80%)
- **Durée** : 10 minutes
- **Sévérité** : Warning

### Diagnostic

```bash
# 1. Identifier les pods saturés
kubectl top pods -n workshop --sort-by=cpu

# 2. Vérifier HPA
kubectl get hpa -n workshop
kubectl describe hpa api-hpa -n workshop

# 3. Consulter Grafana
# Dashboard: Workshop API - CPU Saturation panel
```

### Actions correctives

1. **Si HPA configuré : Vérifier le scaling**
   ```bash
   kubectl get hpa -n workshop
   # Si HPA ne scale pas, vérifier metrics-server
   kubectl top nodes
   ```

2. **Scaling manuel si nécessaire**
   ```bash
   kubectl scale deployment/api -n workshop --replicas=4
   ```

3. **Augmenter les limites CPU**
   ```bash
   kubectl set resources deployment/api -n workshop \
     --limits=cpu=500m \
     --requests=cpu=200m
   ```

4. **Optimiser l'application**
   - Profiler les hot paths
   - Ajouter du caching
   - Optimiser les requêtes DB

---

## HighLatencyP95

### Description

Alerte déclenchée lorsque la latence p95 dépasse **300ms** pendant **10 minutes**.

### Seuil

- **Métrique** : `histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket{namespace="workshop"}[5m])) by (le, service))`
- **Seuil** : > 0.3s (300ms)
- **Durée** : 10 minutes
- **Sévérité** : Warning
- **SLO** : Latence p95 < 300ms

### Impact

- Violation du SLO de latence
- Expérience utilisateur dégradée
- Risque de timeouts clients

### Diagnostic

```bash
# 1. Vérifier les métriques de latence dans Grafana
# Panel: Latence p50, p95, p99

# 2. Analyser les traces dans Jaeger
# http://localhost:16686
# Identifier les spans les plus lents

# 3. Vérifier la charge système
kubectl top pods -n workshop
kubectl top nodes

# 4. Consulter les logs
kubectl logs -n workshop -l app=api | grep -i "slow\|timeout"
```

### Actions correctives

1. **Scaling horizontal**
   ```bash
   kubectl scale deployment/api -n workshop --replicas=6
   ```

2. **Identifier les requêtes lentes via Jaeger**
   - Ouvrir Jaeger UI
   - Filtrer par latence > 300ms
   - Analyser les spans pour trouver le bottleneck

3. **Optimisations applicatives**
   - Ajouter du caching
   - Optimiser les requêtes DB (index, pagination)
   - Paralléliser les appels externes
   - Implémenter lazy loading

4. **Vérifier les dépendances externes**
   ```bash
   # Tester la latence vers les backends
   kubectl exec -n workshop deploy/api -- time curl http://backend-service
   ```

### Prévention

- Load testing régulier (k6)
- Monitoring continu des traces
- Optimisation proactive du code
- Caching stratégique

---

## Commandes utiles générales

```bash
# Lister toutes les alertes actives
kubectl get prometheusrules -n observability

# Accéder à Prometheus
kubectl port-forward -n observability svc/monitor-kube-prometheus-prometheus 9090:9090

# Accéder à Grafana
kubectl port-forward -n observability svc/monitor-grafana 3000:80

# Accéder à Jaeger
kubectl port-forward -n observability svc/simplest-query 16686:16686

# Vérifier les ServiceMonitors
kubectl get servicemonitors -n observability

# Consulter les logs Loki
kubectl port-forward -n observability svc/loki 3100:3100
curl -G -s "http://localhost:3100/loki/api/v1/query" --data-urlencode 'query={namespace="workshop"}'
```

## Escalade

| Sévérité | Action | Contact |
|----------|--------|---------|
| **Critical** | Intervention immédiate | Astreinte SRE |
| **Warning** | Investigation sous 1h | Équipe Dev/Ops |
| **Info** | Analyse différée | Ticket Jira |

## Références

- [Documentation Prometheus](https://prometheus.io/docs/)
- [Grafana Dashboards](http://localhost:3000)
- [Jaeger Tracing](http://localhost:16686)
- [SLO/SLI du projet](SLO-SLI.md)

