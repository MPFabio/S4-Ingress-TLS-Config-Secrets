# TP Kubernetes - Ingress, TLS, Persistence & Scalabilité

Projets pratiques Kubernetes couvrant plusieurs aspects :
- **S4** : Ingress, TLS et Configuration
- **S5** : Persistence et StatefulSets (PostgreSQL)
- **S6** : Scalabilité et Résilience (HPA, PDB, SLO/SLI)

## Structure du projet

```
.
├── docs/              # Documentation complète
│   ├── README.md      # Documentation S6 (Scalabilité)
│   ├── INSTALL.md     # Guide d'installation S4
│   ├── ARCHITECTURE.md
│   ├── RUNBOOK.md     # Runbook PostgreSQL (S5)
│   └── SLO-SLI.md     # Définition SLO/SLI (S6)
├── scripts/           # Scripts de déploiement et tests
├── manifests/         # Manifests Kubernetes
│   ├── ingress/       # S4: Ingress, ConfigMap, Secrets
│   ├── postgres/      # S5: StatefulSet PostgreSQL
│   └── scaling/       # S6: HPA, PDB, Argo Rollouts
├── k6-tests/          # Tests de charge k6
└── backups/           # Backups PostgreSQL
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

## Documentation

- **[Installation complète](docs/INSTALL.md)** - Guide S4 détaillé
- **[Architecture](docs/ARCHITECTURE.md)** - Diagrammes et concepts
- **[Runbook PostgreSQL](docs/RUNBOOK.md)** - Backup/Restore S5
- **[Scalabilité](docs/README.md)** - HPA/PDB/SLO S6
- **[SLO/SLI](docs/SLO-SLI.md)** - Objectifs et métriques

## Prérequis

- Kubernetes (kind, minikube ou autre)
- kubectl
- helm (pour cert-manager, metrics-server)
- k6 (pour tests de charge)

## Branches

- `main` - Version stable
- `dev` - Développement actif
- `S4` - Ingress & TLS
- `S5` - Persistence
- `S6` - Scalabilité

