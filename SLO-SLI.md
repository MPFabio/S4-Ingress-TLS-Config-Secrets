# SLO/SLI - TP S6

## Service Level Indicators (SLI)

Métriques mesurables basées sur les 4 Golden Signals (Google SRE).

### Golden Signals et mesures

| Golden Signal | SLI | Métrique | Source (TP) | Valeur cible |
|---------------|-----|----------|-------------|--------------|
| **Latency** | Latence p50 | Temps de réponse médian | k6 | < 100ms |
| **Latency** | Latence p95 | 95% des requêtes | k6 | < 300ms |
| **Latency** | Latence p99 | 99% des requêtes | k6 | < 500ms |
| **Traffic** | Throughput | Requêtes par seconde | k6 | > 50 req/s |
| **Errors** | Taux d'erreur | Requêtes échouées / total | k6 | < 1% |
| **Errors** | Disponibilité | 100% - taux d'erreur | k6 | > 99% |
| **Saturation** | CPU | Utilisation CPU moyenne | kubectl top | < 70% |
| **Saturation** | RAM | Utilisation RAM moyenne | kubectl top | < 80% |

**Note** : Disponibilité = 100% - Taux d'erreur (même métrique, vue inversée)

## Service Level Objectives (SLO)

Objectifs de performance sur une période donnée.

### SLO Principal - Taux d'erreur (Errors)

**Objectif** : < 1% d'erreurs (équivalent à 99% de disponibilité)

**Calcul** :
```
Taux d'erreur = (Requêtes échouées / Total requêtes) × 100 < 1%
Disponibilité = 100% - Taux d'erreur = 99%
Budget d'erreur = 1%
```

**Mesure avec k6** :
```
http_req_failed: 0.5% (50/10000)
→ Taux d'erreur = 0.5% ✅ (< 1%)
→ Disponibilité = 99.5% ✅ (> 99%)
```

### SLO Latence

**Objectif** : p95 < 300ms

**Calcul** :
```
95% des requêtes doivent être traitées en moins de 300ms
```

**Mesure** :
```promql
histogram_quantile(0.95, 
  rate(http_request_duration_seconds_bucket[5m])
) < 0.3
```

### SLO Traffic

**Objectif** : Maintenir > 50 req/s

**Mesure avec k6** :
```
http_reqs: 51.2/s ✅ (> 50 req/s)
```

### SLO Saturation

**Objectif** : CPU < 70%, RAM < 80%

**Mesure** :
```bash
kubectl top pods -n workshop
# api-xxx: CPU 45%, RAM 60% ✅
```

## Résultats des tests k6

### Test 1 : Load test API (50 req/s pendant 5min)

**Commande** :
```bash
k6 run k6-tests/load-test-api.js
```

**Résultats attendus** :
```
Durée totale: ~5min
Requêtes totales: ~15000 (50 req/s × 300s)
Requêtes/sec: ~50
Échecs: < 0.01 (< 1%)

Latence:
  p50: < 100ms
  p95: < 300ms
  p99: < 500ms

Status HPA: PASS
```

### Test 2 : Load test Front (rampe progressive)

**Commande** :
```bash
k6 run k6-tests/load-test-front.js
```

**Résultats attendus** :
```
Étape 1 (1min): 10 VU
Étape 2 (3min): 30 VU
Étape 3 (1min): 0 VU

p95: < 500ms
Taux d'erreur: < 5%
```

### Test 3 : Spike test (pic de charge)

**Commande** :
```bash
k6 run k6-tests/spike-test.js
```

**Résultats attendus** :
```
Pic: 100 VU pendant 1min
p95 durant le pic: < 1000ms
Récupération: < 10s
```

## Vérification HPA pendant les tests

### Observer le scaling automatique

```bash
# Terminal 1 : Lancer le test de charge
k6 run k6-tests/load-test-api.js

# Terminal 2 : Observer HPA en temps réel
watch -n 2 'kubectl get hpa,pods -n workshop'

# Terminal 3 : Observer les métriques
kubectl top pods -n workshop
```

**Comportement attendu** :
```
t=0s   : 2 pods (minReplicas)
t=30s  : CPU > 60% → HPA scale à 3-4 pods
t=2min : Charge continue → 5-6 pods (maxReplicas)
t=fin  : Charge arrête → descale progressivement
t+5min : Retour à 2 pods (stabilizationWindow)
```

## Validation PDB

### Test de disruption

```bash
# Tenter de supprimer 2 pods simultanément
kubectl delete pod -n workshop -l app=api --grace-period=0 --force

# Résultat attendu: 
# - 1 pod supprimé (OK)
# - 1 pod bloqué par PDB (minAvailable: 2)
```

**Message attendu** :
```
Cannot evict pod as it would violate the pod's disruption budget
```

## Error Budget

**Exemple pour 99.5% sur 30 jours** :

```
Total minutes sur 30j: 43200 min
Downtime autorisé (0.5%): 216 min = 3.6 heures

Si incident de 2h:
  Consommé: 2h / 3.6h = 55.5% du budget
  Restant: 1.6h pour le mois
```

**Action si budget épuisé** : Freeze des releases, focus stabilité.

## Dashboards Grafana (optionnel)

### Métriques clés à afficher

1. **Disponibilité** : Graphe temps réel du taux de succès
2. **Latence** : Heatmap p50/p95/p99
3. **Throughput** : Req/s par endpoint
4. **HPA** : Nombre de replicas actuel vs cible
5. **Error Budget** : Consommation du budget mensuel

### Alertes recommandées

```yaml
- alert: LatencyHigh
  expr: http_req_duration_p95 > 300
  for: 5m
  
- alert: ErrorRateHigh
  expr: http_req_failed_rate > 0.01
  for: 5m
  
- alert: ErrorBudgetExhausted
  expr: error_budget_remaining < 0.1
  for: 1h
```

## Amélioration continue

Basé sur les résultats k6 :

1. **Si p95 > 300ms** : Optimiser le code, augmenter les ressources, ajouter cache
2. **Si taux erreur > 1%** : Vérifier les logs, augmenter replicas, améliorer health checks
3. **Si HPA ne scale pas** : Vérifier metrics-server, ajuster les seuils CPU/RAM
4. **Si scaling trop lent** : Réduire stabilizationWindow, augmenter scaleUp policies

## Résumé

| Objectif | SLI | Valeur cible | Mesure |
|----------|-----|--------------|--------|
| Service fiable | Disponibilité | 99.5% | Prometheus |
| Service rapide | Latence p95 | < 300ms | k6 |
| Peu d'erreurs | Taux 5xx | < 1% | Prometheus |
| Ressources optimisées | CPU/RAM | 60-80% | Metrics Server |

**SLO = Promesse faite aux utilisateurs**  
**SLI = Métriques pour vérifier qu'on tient la promesse**

