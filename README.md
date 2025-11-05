# TP Kubernetes - Ingress, TLS & Persistence

Projets pratiques Kubernetes couvrant plusieurs aspects :
- **S4** : Ingress, TLS et Configuration
- **S5** : Persistence et StatefulSets (PostgreSQL)

## Structure du projet

```
.
├── docs/              # Documentation complète
│   ├── README.md      # Documentation S5 (Persistence)
│   ├── INSTALL.md     # Guide d'installation S4
│   ├── ARCHITECTURE.md
│   └── RUNBOOK.md     # Runbook PostgreSQL (S5)
├── scripts/           # Scripts de déploiement et tests
├── manifests/         # Manifests Kubernetes
│   ├── ingress/       # S4: Ingress, ConfigMap, Secrets
│   └── postgres/      # S5: StatefulSet PostgreSQL
├── backups/           # Backups PostgreSQL
└── kind-config.yaml
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
Documentation : [docs/README.md](docs/README.md) | [docs/RUNBOOK.md](docs/RUNBOOK.md)

## Documentation

- **[PostgreSQL S5](docs/README.md)** - StatefulSet, PVC, Backup/Restore
- **[Runbook PostgreSQL](docs/RUNBOOK.md)** - Procédures opérationnelles
- **[Installation S4](docs/INSTALL.md)** - Guide Ingress & TLS
- **[Architecture](docs/ARCHITECTURE.md)** - Diagrammes et concepts

## Prérequis

- Kubernetes (kind, minikube ou autre)
- kubectl
- helm (pour cert-manager)

## Branches

- `main` - Version stable
- `S4` - Ingress & TLS
- `S5` - Persistence (branche actuelle)
