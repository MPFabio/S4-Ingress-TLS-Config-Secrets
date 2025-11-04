#!/bin/bash

# Script de test PostgreSQL
# Crée des données de test et vérifie la persistance

set -e

NAMESPACE="workshop"

echo "=== Test PostgreSQL avec persistance ==="
echo ""

# Récupérer le pod
POD=$(kubectl -n "$NAMESPACE" get po -l app=postgres -o jsonpath='{.items[0].metadata.name}')

if [ -z "$POD" ]; then
    echo "ERREUR: Aucun pod PostgreSQL trouvé"
    exit 1
fi

echo "Pod: $POD"
echo ""

# Test 1: Créer une base de données et une table
echo "[Test 1] Création d'une base de données et insertion de données..."
kubectl -n "$NAMESPACE" exec -i "$POD" -- psql -U postgres <<EOF
SELECT 'CREATE DATABASE testdb' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'testdb')\gexec
\c testdb
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100),
    created_at TIMESTAMP DEFAULT NOW()
);
INSERT INTO users (name) VALUES ('Alice'), ('Bob'), ('Charlie');
SELECT * FROM users;
EOF

echo ""
echo "[Test 2] Vérification que les données sont présentes..."
kubectl -n "$NAMESPACE" exec "$POD" -- psql -U postgres -d testdb -c "SELECT COUNT(*) as total_users FROM users;"

echo ""
echo "[Test 3] Informations sur le volume..."
kubectl -n "$NAMESPACE" exec "$POD" -- sh -c 'df -h /var/lib/postgresql/data'

echo ""
echo "[Test 4] Vérifier le PVC..."
kubectl get pvc -n "$NAMESPACE" -l app=postgres

echo ""
echo "=== Tests terminés ==="
echo ""
echo "Pour tester la persistance complète:"
echo "  1. kubectl delete pod $POD -n $NAMESPACE"
echo "  2. Attendre que le pod redémarre"
echo "  3. Relancer ce script - les données doivent être toujours là"

