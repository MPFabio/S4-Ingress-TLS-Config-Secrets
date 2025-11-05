# TP Kubernetes - Ingress, TLS & Configuration

Projet pratique Kubernetes couvrant les concepts :
- **Ingress** : Routage HTTP/HTTPS
- **TLS** : Certificats auto-signés avec cert-manager
- **Configuration** : ConfigMap et Secrets
- **Services** : Front et API

## Architecture

```
Client
  ↓
Ingress (workshop.local)
  ├─→ /front → Service front → Pods front
  └─→ /api   → Service api   → Pods api
```

Voir [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) pour les diagrammes détaillés.

## Déploiement rapide

```bash
./scripts/deploy.sh
```

Le script installe automatiquement :
- Cluster KinD (si nécessaire)
- Ingress NGINX Controller
- cert-manager
- Applications (front + api)

Documentation complète : [docs/INSTALL.md](docs/INSTALL.md)

## Structure du projet

```
.
├── docs/              # Documentation
│   ├── INSTALL.md     # Guide d'installation détaillé
│   └── ARCHITECTURE.md # Diagrammes et architecture
├── scripts/           # Scripts de déploiement
│   ├── deploy.sh      # Déploiement automatique
│   └── cleanup.sh     # Nettoyage
├── manifests/
│   └── ingress/       # Manifests Kubernetes
│       ├── namespaces.yaml
│       ├── configmap.yaml
│       ├── secrets.yaml
│       ├── certmanager.yaml
│       ├── front.yaml
│       ├── api.yaml
│       └── ingress.yaml
└── kind-config.yaml   # Configuration KinD
```

## Prérequis

- Docker Desktop (ou Docker)
- kubectl
- kind (installé automatiquement si manquant)
- helm (installé automatiquement si manquant)

## Accès

Après déploiement, ajouter dans `/etc/hosts` :

```
127.0.0.1 workshop.local
```

Puis accéder à :
- **Front** : http://workshop.local:8080/front
- **API** : http://workshop.local:8080/api
- **HTTPS** : https://workshop.local:8443/front (certificat auto-signé)

## Vérifications

```bash
# État des pods
kubectl get pods -n workshop

# État de l'Ingress
kubectl get ingress -n workshop

# Logs Ingress Controller
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller

# Test depuis un pod
kubectl run test -n workshop --image=curlimages/curl --rm -it --restart=Never -- curl http://front/
```

## Nettoyage

```bash
./scripts/cleanup.sh
```

## Documentation

- **[Guide d'installation](docs/INSTALL.md)** - Instructions détaillées
- **[Architecture](docs/ARCHITECTURE.md)** - Diagrammes et concepts

## Branches

- `main` - Version stable
- `dev` - Développement actif
- `S4` - Ingress & TLS (branche actuelle)
- `S5` - Persistence (PostgreSQL)
- `S6` - Scalabilité (HPA, PDB)
