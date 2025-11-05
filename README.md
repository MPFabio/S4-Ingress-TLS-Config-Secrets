# TP Kubernetes - Ingress, TLS, Persistence, Scalabilité & Observabilité

Projets pratiques Kubernetes couvrant plusieurs aspects :
- **S4** : Ingress, TLS et Configuration
- **S5** : Persistence et StatefulSets (PostgreSQL)
- **S6** : Scalabilité et Résilience (HPA, PDB, SLO/SLI)
- **S7** : Observabilité (Prometheus, Grafana, Loki, Jaeger)

## Structure du projet

```
.
├── docs/                   # Documentation complète
│   ├── README.md           # Documentation S6 (Scalabilité)
│   ├── INSTALL.md          # Guide d'installation S4
│   ├── ARCHITECTURE.md     # Architecture générale
│   ├── RUNBOOK.md          # Runbook PostgreSQL (S5)
│   ├── SLO-SLI.md          # SLO/SLI S6
│   ├── OBSERVABILITY.md    # Documentation S7 (Observabilité)
│   └── RUNBOOK-ALERTS.md   # Runbook alertes S7
├── scripts/                # Scripts de déploiement et tests
│   ├── deploy.sh           # S4: Ingress & TLS
│   ├── deploy-postgres.sh  # S5: PostgreSQL
│   ├── deploy-scaling.sh   # S6: HPA & PDB
│   └── deploy-observability.sh  # S7: Prometheus, Grafana, Loki, Jaeger
├── manifests/              # Manifests Kubernetes
│   ├── ingress/            # S4: Ingress, ConfigMap, Secrets
│   ├── postgres/           # S5: StatefulSet PostgreSQL
│   ├── scaling/            # S6: HPA, PDB, Argo Rollouts
│   └── observability/      # S7: ServiceMonitor, PrometheusRules
├── dashboards/             # Dashboards Grafana
│   └── workshop-api-dashboard.json
├── k6-tests/               # Tests de charge k6
└── backups/                # Backups PostgreSQL
```

## Démarrage rapide

### S4 - Ingress & TLS
```bash
./scripts/deploy.sh
```
Documentation : [docs/INSTALL.md](docs/INSTALL.md)

### S5 - PostgreSQL StatefulSet
```bash
./scripts/deploy-postgres.sh
```
Documentation : [docs/RUNBOOK.md](docs/RUNBOOK.md)

### S6 - Scalabilité & Résilience
```bash
./scripts/deploy-scaling.sh
```
Documentation : [docs/README.md](docs/README.md)

### S7 - Observabilité (Prometheus, Grafana, Loki, Jaeger)
```bash
./scripts/deploy-observability.sh
```
Documentation : [docs/OBSERVABILITY.md](docs/OBSERVABILITY.md)

## Accès rapide S7

Après déploiement de la stack observabilité :

```bash
# Grafana (dashboards + Loki)
kubectl port-forward -n observability svc/monitor-grafana 3000:80
# → http://localhost:3000 (admin/admin)

# Prometheus (métriques)
kubectl port-forward -n observability svc/monitor-kube-prometheus-prometheus 9090:9090
# → http://localhost:9090

# Jaeger (traces)
kubectl port-forward -n observability svc/simplest-query 16686:16686
# → http://localhost:16686
```

## Documentation

- **[Observabilité S7](docs/OBSERVABILITY.md)** - Prometheus, Grafana, Loki, Jaeger
- **[Runbook Alertes](docs/RUNBOOK-ALERTS.md)** - Procédures de résolution des alertes
- **[Scalabilité S6](docs/README.md)** - HPA, PDB, SLO/SLI
- **[PostgreSQL S5](docs/RUNBOOK.md)** - StatefulSet, Backup/Restore
- **[Installation S4](docs/INSTALL.md)** - Ingress & TLS
- **[Architecture](docs/ARCHITECTURE.md)** - Diagrammes et concepts
- **[SLO/SLI](docs/SLO-SLI.md)** - Objectifs et métriques

## Prérequis

- Kubernetes (kind, minikube ou autre)
- kubectl
- helm (installé automatiquement si manquant)
- k6 (pour tests de charge S6)

## Observabilité - Golden Signals

Le dashboard Grafana couvre les **4 Golden Signals** (SRE) :

| Signal | Métrique | Visualisation |
|--------|----------|---------------|
| **Latency** | p50, p95, p99 | Graphique latence |
| **Traffic** | Requêtes/sec | RPS panel |
| **Errors** | Taux 5xx | % erreurs avec seuil |
| **Saturation** | CPU, RAM | Usage par pod |

## Alertes configurées

5 alertes Prometheus déployées :
- **HighErrorRate** : Taux 5xx > 2% (10min)
- **PodHighRestarts** : Redémarrages > 5 (15min)
- **PodNotReady** : Pod non-Running (5min)
- **HighCPUSaturation** : CPU > 80% (10min)
- **HighLatencyP95** : p95 > 300ms (10min)

Voir [docs/RUNBOOK-ALERTS.md](docs/RUNBOOK-ALERTS.md) pour les procédures.

## Branches

- `main` - Version stable
- `dev` - Développement actif
- `S4` - Ingress & TLS
- `S5` - Persistence (PostgreSQL)
- `S6` - Scalabilité (HPA, PDB)
- `S7` - Observabilité (branche actuelle)

## Livrables par TP

### S4 - Ingress & TLS
- ✅ Ingress NGINX configuré
- ✅ TLS avec cert-manager (certificats auto-signés)
- ✅ ConfigMap et Secrets
- ✅ Diagrammes d'architecture

### S5 - Persistence
- ✅ StatefulSet PostgreSQL
- ✅ PVC dynamique (8Gi)
- ✅ Service headless
- ✅ Runbook backup/restore
- ✅ Scripts automatisés

### S6 - Scalabilité & Résilience
- ✅ HPA (CPU + custom metrics)
- ✅ PDB (minAvailable: 2)
- ✅ SLO/SLI documentés
- ✅ Tests de charge k6
- ✅ Argo Rollouts (canary - bonus)

### S7 - Observabilité
- ✅ Prometheus + Grafana (kube-prometheus-stack)
- ✅ Loki + Promtail (centralisation logs)
- ✅ Jaeger (tracing distribué)
- ✅ Dashboard Grafana (4 Golden Signals)
- ✅ 5 alertes PrometheusRule
- ✅ Runbook d'exploitation des alertes
- ✅ ServiceMonitor pour scraping

## Stack complète

```
┌─────────────────────────────────────────┐
│         Observabilité (S7)              │
│  Prometheus | Grafana | Loki | Jaeger  │
└─────────────────────────────────────────┘
              ↓ Monitor
┌─────────────────────────────────────────┐
│      Scalabilité & Résilience (S6)      │
│         HPA | PDB | SLO/SLI             │
└─────────────────────────────────────────┘
              ↓ Scale
┌─────────────────────────────────────────┐
│         Persistence (S5)                │
│    StatefulSet PostgreSQL + PVC         │
└─────────────────────────────────────────┘
              ↓ Store
┌─────────────────────────────────────────┐
│       Ingress & Config (S4)             │
│   Ingress NGINX | TLS | ConfigMap       │
└─────────────────────────────────────────┘
              ↓ Expose
┌─────────────────────────────────────────┐
│          Applications                   │
│          Front | API                    │
└─────────────────────────────────────────┘
```

## Commandes utiles

```bash
# Vérifier tous les composants
kubectl get all -n workshop
kubectl get all -n observability

# Accéder aux dashboards
kubectl port-forward -n observability svc/monitor-grafana 3000:80

# Vérifier les alertes
kubectl get prometheusrules -n observability

# Consulter les métriques
kubectl port-forward -n observability svc/monitor-kube-prometheus-prometheus 9090:9090

# Voir les traces
kubectl port-forward -n observability svc/simplest-query 16686:16686

# Tester la charge (S6)
k6 run k6-tests/load-test-api.js
```

## Évaluation globale

| TP | Points | Livrables |
|----|--------|-----------|
| **S4** | 10 | Ingress TLS + Config/Secret + diagramme |
| **S5** | 10 | StatefulSet Postgres + Runbook backup/restore |
| **S6** | 10 | HPA+PDB + SLO/SLI + k6 |
| **S7** | 10 | Dashboard + 5 alertes + traces |
| **Bonus** | +4 | Canary automatisé + observabilité avancée |
| **Total** | 44 | Documentation + manifests + scripts |

## Bonnes pratiques appliquées

- ✅ Jamais de Secrets en clair (stringData)
- ✅ Toujours requests/limits sur les workloads
- ✅ readinessProbe/livenessProbe configurées
- ✅ Labels cohérents pour le monitoring
- ✅ Documentation complète (README + schémas)
- ✅ Scripts d'automatisation
- ✅ Runbooks opérationnels
- ✅ Observabilité sur les 4 Golden Signals
