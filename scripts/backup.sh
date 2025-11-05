#!/bin/bash

# Script de backup PostgreSQL
# Effectue un dump logique de toutes les bases de données

set -e

NAMESPACE="workshop"
BACKUP_DIR="./backups"
DATE=$(date +%Y-%m-%d_%H-%M-%S)
BACKUP_FILE="$BACKUP_DIR/postgres-backup-$DATE.sql"

echo "=== Backup PostgreSQL ==="
echo ""

# Créer le dossier de backups
mkdir -p "$BACKUP_DIR"

# Récupérer le nom du pod PostgreSQL
echo "Recherche du pod PostgreSQL..."
POD=$(kubectl -n "$NAMESPACE" get po -l app=postgres -o jsonpath='{.items[0].metadata.name}')

if [ -z "$POD" ]; then
    echo "ERREUR: Aucun pod PostgreSQL trouvé dans le namespace $NAMESPACE"
    exit 1
fi

echo "Pod trouvé: $POD"
echo ""

# Effectuer le backup
echo "Création du backup..."
kubectl -n "$NAMESPACE" exec "$POD" -- bash -c 'pg_dumpall -U postgres' > "$BACKUP_FILE"

# Vérifier que le backup n'est pas vide
if [ ! -s "$BACKUP_FILE" ]; then
    echo "ERREUR: Le fichier de backup est vide"
    exit 1
fi

# Compresser le backup
echo "Compression du backup..."
gzip "$BACKUP_FILE"
BACKUP_FILE="${BACKUP_FILE}.gz"

# Afficher les informations
BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
echo ""
echo "=== Backup terminé ==="
echo "Fichier: $BACKUP_FILE"
echo "Taille: $BACKUP_SIZE"
echo ""

# Lister les backups existants
echo "Backups disponibles:"
ls -lh "$BACKUP_DIR"

