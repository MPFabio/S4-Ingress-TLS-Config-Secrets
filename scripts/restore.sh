#!/bin/bash

# Script de restore PostgreSQL
# Restaure une base de données depuis un dump

set -e

NAMESPACE="workshop"
BACKUP_DIR="./backups"

echo "=== Restore PostgreSQL ==="
echo ""

# Vérifier qu'un fichier de backup est fourni
if [ -z "$1" ]; then
    echo "Usage: $0 <fichier-backup>"
    echo ""
    echo "Backups disponibles:"
    ls -lh "$BACKUP_DIR" 2>/dev/null || echo "Aucun backup trouvé"
    exit 1
fi

BACKUP_FILE="$1"

# Vérifier que le fichier existe
if [ ! -f "$BACKUP_FILE" ]; then
    echo "ERREUR: Le fichier $BACKUP_FILE n'existe pas"
    exit 1
fi

# Récupérer le nom du pod PostgreSQL
echo "Recherche du pod PostgreSQL..."
POD=$(kubectl -n "$NAMESPACE" get po -l app=postgres -o jsonpath='{.items[0].metadata.name}')

if [ -z "$POD" ]; then
    echo "ERREUR: Aucun pod PostgreSQL trouvé dans le namespace $NAMESPACE"
    exit 1
fi

echo "Pod trouvé: $POD"
echo ""

# Décompresser si nécessaire
if [[ "$BACKUP_FILE" == *.gz ]]; then
    echo "Décompression du backup..."
    TMP_FILE="${BACKUP_FILE%.gz}"
    gunzip -c "$BACKUP_FILE" > "$TMP_FILE"
    BACKUP_FILE="$TMP_FILE"
    CLEANUP_TMP=true
fi

# Avertissement
echo "ATTENTION: Cette opération va ÉCRASER les données actuelles de PostgreSQL"
echo "Appuyez sur Ctrl+C pour annuler ou Entrée pour continuer..."
read

# Effectuer le restore
echo "Restauration en cours..."
kubectl -n "$NAMESPACE" exec -i "$POD" -- bash -c 'psql -U postgres' < "$BACKUP_FILE"

# Nettoyer le fichier temporaire
if [ "$CLEANUP_TMP" = true ]; then
    rm -f "$TMP_FILE"
fi

echo ""
echo "=== Restore terminé ==="
echo ""

# Vérifier la connexion
echo "Vérification de la connexion..."
kubectl -n "$NAMESPACE" exec "$POD" -- psql -U postgres -c '\l'

