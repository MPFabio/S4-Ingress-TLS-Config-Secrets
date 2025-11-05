# Runbook PostgreSQL - Backup & Restore

## Prérequis

- Cluster Kubernetes fonctionnel
- Namespace `workshop` créé
- PostgreSQL déployé via StatefulSet
- StorageClass disponible (vérifier avec `kubectl get sc`)

## Déploiement PostgreSQL

### Déploiement automatique

```bash
./scripts/deploy-postgres.sh
```

### Déploiement manuel

```bash
kubectl apply -f postgres-secret.yaml
kubectl apply -f postgres-service.yaml
kubectl apply -f postgres-statefulset.yaml

# Attendre que le pod soit prêt
kubectl wait --for=condition=ready pod -l app=postgres -n workshop --timeout=120s
```

### Vérification

```bash
# État des ressources
kubectl get statefulset,pod,svc,pvc -n workshop -l app=postgres

# Connexion à PostgreSQL
POD=$(kubectl -n workshop get po -l app=postgres -o jsonpath='{.items[0].metadata.name}')
kubectl exec -it $POD -n workshop -- psql -U postgres

# Commandes PostgreSQL
\l              # Lister les bases de données
\c testdb       # Se connecter à une base
\dt             # Lister les tables
\q              # Quitter
```

## Backup (dump logique)

### Backup automatique

```bash
./scripts/backup.sh
```

Le backup est créé dans `./backups/postgres-backup-YYYY-MM-DD_HH-MM-SS.sql.gz`

### Backup manuel

```bash
# Variables
NAMESPACE="workshop"
POD=$(kubectl -n $NAMESPACE get po -l app=postgres -o jsonpath='{.items[0].metadata.name}')
DATE=$(date +%Y-%m-%d)

# Dump de toutes les bases
kubectl -n $NAMESPACE exec $POD -- pg_dumpall -U postgres > backup-$DATE.sql

# Compresser
gzip backup-$DATE.sql
```

### Backup d'une base spécifique

```bash
# Dump d'une seule base
kubectl -n workshop exec $POD -- pg_dump -U postgres testdb > backup-testdb.sql
```

### Backup avec Velero (optionnel)

Si Velero est installé dans le cluster :

```bash
# Backup du namespace complet (inclut PVC)
velero backup create workshop-backup \
  --include-namespaces workshop \
  --wait \
  --default-volumes-to-restic

# Vérifier le backup
velero backup describe workshop-backup

# Lister les backups
velero backup get
```

## Restore

### Restore automatique

```bash
./scripts/restore.sh ./backups/postgres-backup-2024-11-04_10-30-00.sql.gz
```

### Restore manuel

```bash
# Variables
NAMESPACE="workshop"
POD=$(kubectl -n $NAMESPACE get po -l app=postgres -o jsonpath='{.items[0].metadata.name}')
BACKUP_FILE="backup-2024-11-04.sql"

# Décompresser si nécessaire
gunzip backup-2024-11-04.sql.gz

# Restore
kubectl -n $NAMESPACE exec -i $POD -- psql -U postgres < $BACKUP_FILE
```

### Restore avec Velero

```bash
# Supprimer le namespace actuel (ATTENTION: données perdues)
kubectl delete namespace workshop

# Restaurer depuis Velero
velero restore create --from-backup workshop-backup --wait

# Vérifier
kubectl get all -n workshop
```

## Test de persistance

### Test automatique

```bash
./scripts/test-postgres.sh
```

### Test manuel

```bash
POD=$(kubectl -n workshop get po -l app=postgres -o jsonpath='{.items[0].metadata.name}')

# 1. Créer des données
kubectl exec -i $POD -n workshop -- psql -U postgres <<EOF
CREATE DATABASE testdb;
\c testdb
CREATE TABLE users (id SERIAL PRIMARY KEY, name VARCHAR(100));
INSERT INTO users (name) VALUES ('Alice'), ('Bob');
SELECT * FROM users;
EOF

# 2. Supprimer le pod (simule un crash)
kubectl delete pod $POD -n workshop

# 3. Attendre le redémarrage
kubectl wait --for=condition=ready pod -l app=postgres -n workshop --timeout=60s

# 4. Vérifier que les données sont toujours là
NEW_POD=$(kubectl -n workshop get po -l app=postgres -o jsonpath='{.items[0].metadata.name}')
kubectl exec $NEW_POD -n workshop -- psql -U postgres -d testdb -c "SELECT * FROM users;"
```

Si les données sont présentes après le redémarrage → **persistance OK**.

## Monitoring

### Logs PostgreSQL

```bash
POD=$(kubectl -n workshop get po -l app=postgres -o jsonpath='{.items[0].metadata.name}')
kubectl logs -n workshop $POD -f
```

### État du PVC

```bash
# Voir le PVC
kubectl get pvc -n workshop

# Détails du PVC
kubectl describe pvc data-postgres-0 -n workshop

# Voir le PV associé
kubectl get pv
```

### Espace disque utilisé

```bash
POD=$(kubectl -n workshop get po -l app=postgres -o jsonpath='{.items[0].metadata.name}')
kubectl exec $POD -n workshop -- du -sh /var/lib/postgresql/data
```

## Troubleshooting

### Pod en CrashLoopBackOff

```bash
# Voir les logs
kubectl logs $POD -n workshop --previous

# Vérifier les permissions du volume
kubectl exec $POD -n workshop -- ls -la /var/lib/postgresql/data
```

### PVC en Pending

```bash
# Vérifier les événements
kubectl describe pvc data-postgres-0 -n workshop

# Vérifier les StorageClass disponibles
kubectl get storageclass

# Voir les événements du namespace
kubectl get events -n workshop --sort-by='.lastTimestamp'
```

### Erreur de connexion PostgreSQL

```bash
# Vérifier que PostgreSQL écoute
kubectl exec $POD -n workshop -- pg_isready -U postgres

# Tester la connexion
kubectl exec $POD -n workshop -- psql -U postgres -c 'SELECT version();'
```

## Nettoyage

### Supprimer PostgreSQL (garde le PVC)

```bash
kubectl delete statefulset postgres -n workshop
kubectl delete service postgres -n workshop
kubectl delete secret pg-secret -n workshop

# Le PVC reste pour conserver les données
kubectl get pvc -n workshop
```

### Supprimer tout (inclut les données)

```bash
kubectl delete statefulset postgres -n workshop
kubectl delete service postgres -n workshop
kubectl delete secret pg-secret -n workshop
kubectl delete pvc data-postgres-0 -n workshop

# Vérifier que le PV est aussi supprimé
kubectl get pv
```

## Notes techniques

### Service Headless

Le service avec `clusterIP: None` crée des enregistrements DNS stables :
- `postgres-0.postgres.workshop.svc.cluster.local`

Utilisé par StatefulSet pour l'identité réseau stable.

### volumeClaimTemplates

Crée automatiquement un PVC par replica :
- 1 replica → 1 PVC nommé `data-postgres-0`
- 3 replicas → 3 PVC : `data-postgres-0`, `data-postgres-1`, `data-postgres-2`

### reclaimPolicy

Par défaut : `Delete` (le PV est supprimé avec le PVC)

Pour conserver les données après suppression du PVC, modifier la StorageClass :
```yaml
reclaimPolicy: Retain
```

### Différence Deployment vs StatefulSet

| Aspect | Deployment | StatefulSet |
|--------|-----------|-------------|
| Nom des pods | Aléatoire (front-abc123) | Stable (postgres-0, postgres-1) |
| DNS | Via Service seulement | DNS par pod (postgres-0.postgres) |
| Ordre de démarrage | Parallèle | Séquentiel (0 puis 1 puis 2) |
| Volumes | Partagés ou aucun | PVC dédié par pod |
| Cas d'usage | Applications stateless | Bases de données, Kafka, etc. |

