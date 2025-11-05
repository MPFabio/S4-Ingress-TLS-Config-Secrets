#!/bin/bash

# Script de déploiement HPA et PDB

set -e

echo "=== Déploiement Scaling & Résilience - TP S6 ==="
echo ""

# Vérifier metrics-server
echo "[1/4] Vérification de metrics-server..."
if ! kubectl get deployment metrics-server -n kube-system &> /dev/null; then
    echo "Installation de metrics-server..."
    kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
    
    # Patch pour kind (self-signed certs)
    kubectl patch deployment metrics-server -n kube-system --type='json' \
      -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'
    
    echo "Attente du démarrage de metrics-server..."
    kubectl wait --for=condition=available deployment/metrics-server -n kube-system --timeout=120s || true
else
    echo "metrics-server déjà installé"
fi
echo ""

# Déployer HPA
echo "[2/4] Déploiement du HorizontalPodAutoscaler..."
kubectl apply -f manifests/scaling/api-hpa.yaml
echo ""

# Déployer PDB
echo "[3/4] Déploiement du PodDisruptionBudget..."
kubectl apply -f manifests/scaling/api-pdb.yaml
echo ""

# Attendre que metrics-server collecte les métriques
echo "[4/4] Attente de la collecte des métriques (30s)..."
sleep 30
echo ""

# Afficher l'état
echo "=== État du déploiement ==="
echo ""
echo "HPA:"
kubectl get hpa -n workshop
echo ""
echo "PDB:"
kubectl get pdb -n workshop
echo ""
echo "Pods actuels:"
kubectl get pods -n workshop
echo ""
echo "Métriques (si disponibles):"
kubectl top pods -n workshop 2>/dev/null || echo "Métriques pas encore disponibles, réessayez dans 1 minute"
echo ""

echo "=== Déploiement terminé ==="
echo ""
echo "Commandes utiles:"
echo "  Observer HPA: watch -n 2 'kubectl get hpa -n workshop'"
echo "  Observer pods: watch -n 2 'kubectl get pods -n workshop'"
echo "  Métriques: kubectl top pods -n workshop"
echo "  Test charge: k6 run k6-tests/load-test-api.js"



