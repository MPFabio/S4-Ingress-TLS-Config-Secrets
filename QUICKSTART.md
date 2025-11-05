# Guide de démarrage rapide - TPs Kubernetes

Ce guide vous permet de naviguer rapidement entre tous les TPs.

## Structure des branches

| Branche | TP | Contenu |
|---------|----|---------| 
| `S4` | Ingress & TLS | Ingress NGINX, cert-manager, ConfigMap, Secrets |
| `S5` | Persistence | StatefulSet PostgreSQL, PVC, Backup/Restore |
| `S6` | Scalabilité | HPA, PDB, SLO/SLI, k6, Argo Rollouts |
| `S7` | Observabilité | Prometheus, Grafana, Loki, Jaeger, Alertes |

## Déploiement rapide par TP

### S4 - Ingress & TLS

```bash
git checkout S4
./scripts/deploy.sh
```

**Documentation** : [docs/INSTALL.md](docs/INSTALL.md)

**Accès** :
- Front : http://workshop.local:8080/front
- API : http://workshop.local:8080/api

---

### S5 - Persistence (PostgreSQL)

```bash
git checkout S5
./scripts/deploy-postgres.sh
```

**Documentation** : [docs/RUNBOOK.md](docs/RUNBOOK.md)

**Opérations** :
```bash
# Backup
./scripts/backup.sh

# Restore
./scripts/restore.sh ./backups/postgres-backup-YYYY-MM-DD_HH-MM-SS.sql.gz

# Test persistance
./scripts/test-postgres.sh
```

---

### S6 - Scalabilité & Résilience

```bash
git checkout S6
./scripts/deploy-scaling.sh
```

**Documentation** : [docs/README.md](docs/README.md) | [docs/SLO-SLI.md](docs/SLO-SLI.md)

**Tests** :
```bash
# Test HPA
./scripts/test-hpa.sh

# Test PDB
./scripts/test-pdb.sh

# Load test
k6 run k6-tests/load-test-api.js
```

---

### S7 - Observabilité

```bash
git checkout S7
./scripts/deploy-observability.sh
```

**Documentation** : [docs/OBSERVABILITY.md](docs/OBSERVABILITY.md) | [docs/RUNBOOK-ALERTS.md](docs/RUNBOOK-ALERTS.md)

**Accès interfaces** :
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

**Tests** :
```bash
# Vérifier la stack
./scripts/test-observability.sh

# Tester les alertes
./scripts/test-alerts.sh
```

---

## Déploiement complet (tous les TPs)

Pour déployer l'ensemble de la stack S4 → S7 :

```bash
# 1. S4: Ingress & TLS
git checkout S4
./scripts/deploy.sh

# 2. S5: PostgreSQL
git checkout S5
./scripts/deploy-postgres.sh

# 3. S6: HPA & PDB
git checkout S6
./scripts/deploy-scaling.sh

# 4. S7: Observabilité
git checkout S7
./scripts/deploy-observability.sh
```

**Note** : Chaque TP hérite des composants précédents. Vous pouvez déployer directement S7 qui contient tout.

---

## Architecture complète

```
┌──────────────────────────────────────────────────┐
│         Observabilité (S7)                       │
│  Prometheus | Grafana | Loki | Jaeger           │
│  • 5 Alertes PrometheusRule                      │
│  • Dashboard Golden Signals                      │
│  • Runbook d'exploitation                        │
└──────────────────────────────────────────────────┘
                    ↓ Monitor
┌──────────────────────────────────────────────────┐
│      Scalabilité & Résilience (S6)               │
│         HPA | PDB | SLO/SLI                      │
│  • HPA: 2-6 replicas (CPU 60%)                   │
│  • PDB: minAvailable 2                           │
│  • k6 load tests                                 │
└──────────────────────────────────────────────────┘
                    ↓ Scale
┌──────────────────────────────────────────────────┐
│         Persistence (S5)                         │
│    StatefulSet PostgreSQL + PVC                  │
│  • PVC dynamique 8Gi                             │
│  • Backup/Restore automatisés                    │
└──────────────────────────────────────────────────┘
                    ↓ Store
┌──────────────────────────────────────────────────┐
│       Ingress & Configuration (S4)               │
│   Ingress NGINX | TLS | ConfigMap                │
│  • TLS auto-signé (cert-manager)                 │
│  • Routage /front et /api                        │
└──────────────────────────────────────────────────┘
                    ↓ Expose
┌──────────────────────────────────────────────────┐
│          Applications                            │
│          Front | API                             │
└──────────────────────────────────────────────────┘
```

---

## Commandes utiles

### Général

```bash
# Voir tous les pods
kubectl get pods -n workshop
kubectl get pods -n observability

# Voir tous les services
kubectl get svc -n workshop
kubectl get svc -n observability

# Voir les ingress
kubectl get ingress -n workshop

# Voir les PVC
kubectl get pvc -n workshop

# Voir HPA
kubectl get hpa -n workshop

# Voir PDB
kubectl get pdb -n workshop
```

### Observabilité

```bash
# Voir les alertes
kubectl get prometheusrules -n observability

# Voir les ServiceMonitors
kubectl get servicemonitors -n observability

# Logs d'un pod
kubectl logs -n workshop -l app=api --tail=50

# Top pods (CPU/RAM)
kubectl top pods -n workshop
```

### Debugging

```bash
# Describe un pod
kubectl describe pod <pod-name> -n workshop

# Exec dans un pod
kubectl exec -it <pod-name> -n workshop -- sh

# Voir les événements
kubectl get events -n workshop --sort-by='.lastTimestamp'

# Port-forward un service
kubectl port-forward -n workshop svc/api 8080:80
```

---

## Nettoyage

### Par TP

```bash
# S4
kubectl delete namespace workshop
kubectl delete namespace ingress-nginx
kubectl delete namespace cert-manager

# S5
kubectl delete statefulset postgres -n workshop
kubectl delete pvc data-postgres-0 -n workshop

# S6
kubectl delete hpa -n workshop --all
kubectl delete pdb -n workshop --all

# S7
kubectl delete namespace observability
```

### Complet

```bash
# Tout supprimer
kubectl delete namespace workshop observability ingress-nginx cert-manager

# Supprimer le cluster KinD
kind delete cluster --name workshop
```

---

## Livrables par TP

### S4
- ✅ Manifests Ingress, ConfigMap, Secrets
- ✅ Script de déploiement automatique
- ✅ Documentation INSTALL.md
- ✅ Diagramme d'architecture

### S5
- ✅ StatefulSet PostgreSQL avec PVC
- ✅ Service headless
- ✅ Scripts backup/restore
- ✅ Runbook opérationnel
- ✅ Test de persistance

### S6
- ✅ HPA (2-6 replicas, CPU 60%)
- ✅ PDB (minAvailable: 2)
- ✅ SLO/SLI documentés (4 Golden Signals)
- ✅ Tests k6 (load, spike)
- ✅ Argo Rollouts canary (bonus)

### S7
- ✅ kube-prometheus-stack (Prometheus + Grafana)
- ✅ Loki + Promtail (logs centralisés)
- ✅ Jaeger (tracing distribué)
- ✅ Dashboard Grafana (Golden Signals)
- ✅ 5 alertes PrometheusRule
- ✅ Runbook d'exploitation des alertes
- ✅ Scripts de test

---

## Documentation complète

| Document | Description |
|----------|-------------|
| [README.md](README.md) | Vue d'ensemble du projet |
| [QUICKSTART.md](QUICKSTART.md) | Ce guide (navigation rapide) |
| [docs/INSTALL.md](docs/INSTALL.md) | Installation S4 (Ingress & TLS) |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Architecture générale |
| [docs/RUNBOOK.md](docs/RUNBOOK.md) | Opérations PostgreSQL S5 |
| [docs/README.md](docs/README.md) | Scalabilité S6 |
| [docs/SLO-SLI.md](docs/SLO-SLI.md) | SLO/SLI S6 |
| [docs/OBSERVABILITY.md](docs/OBSERVABILITY.md) | Observabilité S7 |
| [docs/RUNBOOK-ALERTS.md](docs/RUNBOOK-ALERTS.md) | Runbook alertes S7 |
| [dashboards/README.md](dashboards/README.md) | Import dashboards Grafana |

---

## Prérequis

- **Docker Desktop** (ou Docker)
- **kubectl** (installé avec Docker Desktop)
- **kind** (installé automatiquement par les scripts si manquant)
- **helm** (installé automatiquement par les scripts si manquant)
- **k6** (optionnel, pour tests de charge S6)

### Installation k6 (optionnel)

```bash
# Windows (Chocolatey)
choco install k6

# macOS (Homebrew)
brew install k6

# Linux
wget https://github.com/grafana/k6/releases/download/v0.47.0/k6-v0.47.0-linux-amd64.tar.gz
tar -xzf k6-v0.47.0-linux-amd64.tar.gz
sudo mv k6-v0.47.0-linux-amd64/k6 /usr/local/bin/
```

---

## Troubleshooting

### Pods en CrashLoopBackOff

```bash
# Voir les logs
kubectl logs <pod-name> -n workshop --previous

# Describe le pod
kubectl describe pod <pod-name> -n workshop
```

### Ingress 404 Not Found

```bash
# Vérifier le hosts file
# Linux/Mac: /etc/hosts
# Windows: C:\Windows\System32\drivers\etc\hosts
# Doit contenir: 127.0.0.1 workshop.local

# Vérifier l'Ingress
kubectl describe ingress web -n workshop
```

### Prometheus ne scrape pas

```bash
# Vérifier les targets
kubectl port-forward -n observability svc/monitor-kube-prometheus-prometheus 9090:9090
# → http://localhost:9090/targets

# Vérifier les ServiceMonitors
kubectl get servicemonitors -n observability
```

### Pas de logs dans Loki

```bash
# Vérifier Promtail
kubectl get pods -n observability -l app=promtail
kubectl logs -n observability -l app=promtail
```

---

## Ressources

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Helm Charts](https://artifacthub.io/)
- [Prometheus Operator](https://prometheus-operator.dev/)
- [Grafana Dashboards](https://grafana.com/grafana/dashboards/)
- [Jaeger Tracing](https://www.jaegertracing.io/)
- [k6 Load Testing](https://k6.io/docs/)
- [SRE Google Book](https://sre.google/sre-book/table-of-contents/)

---

## Support

Pour toute question ou problème :
1. Consulter la documentation dans `docs/`
2. Vérifier les logs : `kubectl logs ...`
3. Consulter les événements : `kubectl get events ...`
4. Utiliser les scripts de test : `./scripts/test-*.sh`

