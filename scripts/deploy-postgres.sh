#!/bin/bash

# Script de déploiement PostgreSQL avec StatefulSet

set -e

echo "=== Déploiement PostgreSQL - TP S5 ==="
echo ""

# Vérifier que le namespace existe
echo "[1/4] Vérification du namespace workshop..."
if ! kubectl get namespace workshop &> /dev/null; then
    echo "Création du namespace workshop..."
    kubectl create namespace workshop
fi
echo "OK"
echo ""

# Déployer le Secret
echo "[2/4] Déploiement du Secret PostgreSQL..."
kubectl apply -f manifests/postgres/postgres-secret.yaml
echo ""

# Déployer le Service headless
echo "[3/4] Déploiement du Service headless..."
kubectl apply -f manifests/postgres/postgres-service.yaml
echo ""

# Déployer le StatefulSet
echo "[4/4] Déploiement du StatefulSet PostgreSQL..."
kubectl apply -f manifests/postgres/postgres-statefulset.yaml
echo ""

# Attendre que le pod soit prêt
echo "Attente du démarrage de PostgreSQL (max 120s)..."
kubectl wait --for=condition=ready pod -l app=postgres -n workshop --timeout=120s || true
echo ""

# Afficher l'état
echo "=== État du déploiement ==="
echo ""
echo "Pods:"
kubectl get pods -n workshop -l app=postgres
echo ""
echo "Service:"
kubectl get svc -n workshop postgres
echo ""
echo "PVC (volume persistant):"
kubectl get pvc -n workshop
echo ""
echo "PV (volume créé automatiquement):"
kubectl get pv | grep workshop || echo "Aucun PV visible (peut être géré par le provisioner)"
echo ""

# Test de connexion
echo "=== Test de connexion ==="
POD=$(kubectl -n workshop get po -l app=postgres -o jsonpath='{.items[0].metadata.name}')
if [ -n "$POD" ]; then
    echo "Test de connexion à PostgreSQL..."
    kubectl -n workshop exec "$POD" -- psql -U postgres -c '\l' && echo "OK - PostgreSQL est accessible"
else
    echo "Pod non trouvé, impossible de tester la connexion"
fi

echo ""
echo "=== Déploiement terminé ==="
echo ""
echo "Commandes utiles:"
echo "  Se connecter: kubectl exec -it $POD -n workshop -- psql -U postgres"
echo "  Backup:       ./scripts/backup.sh"
echo "  Restore:      ./scripts/restore.sh <fichier-backup>"
echo "  Test:         ./scripts/test-postgres.sh"

