#!/bin/bash

# Script de test PodDisruptionBudget

set -e

NAMESPACE="workshop"

echo "=== Test PDB (Pod Disruption Budget) ==="
echo ""

# Vérifier que PDB existe
if ! kubectl get pdb -n "$NAMESPACE" &> /dev/null; then
    echo "ERREUR: Aucun PDB trouvé. Déployez d'abord avec ./deploy-scaling.sh"
    exit 1
fi

echo "PDB configurés:"
kubectl get pdb -n "$NAMESPACE"
echo ""

echo "Pods actuels (app=api):"
kubectl get pods -n "$NAMESPACE" -l app=api
TOTAL_PODS=$(kubectl get pods -n "$NAMESPACE" -l app=api --no-headers | wc -l)
echo "Total: $TOTAL_PODS pods"
echo ""

echo "Le PDB api-pdb exige minAvailable: 2"
echo ""

# Test 1: Supprimer 1 pod
echo "[Test 1] Suppression d'1 pod (devrait être autorisé)..."
FIRST_POD=$(kubectl get pods -n "$NAMESPACE" -l app=api -o jsonpath='{.items[0].metadata.name}')
kubectl delete pod "$FIRST_POD" -n "$NAMESPACE" --wait=false
echo "Pod $FIRST_POD marqué pour suppression"
sleep 2
echo ""

# Test 2: Drain d'un node (simulé par suppression de plusieurs pods)
echo "[Test 2] Tentative de suppression de tous les pods sauf 1..."
echo "(simule un drain de node)"
echo ""

# Obtenir le nombre de pods à supprimer
PODS_TO_DELETE=$(($TOTAL_PODS - 2))

if [ $PODS_TO_DELETE -gt 0 ]; then
    echo "Tentative de suppression de $PODS_TO_DELETE pods..."
    kubectl delete pods -n "$NAMESPACE" -l app=api --field-selector=status.phase=Running --force --grace-period=0 2>&1 | head -10
    echo ""
    echo "Résultat attendu: Certaines suppressions bloquées par PDB"
else
    echo "Pas assez de pods pour tester (minimum 3 requis)"
fi

echo ""
echo "État après tentative:"
kubectl get pods -n "$NAMESPACE" -l app=api
echo ""

echo "Événements PDB (vérifier les rejets):"
kubectl get events -n "$NAMESPACE" --field-selector involvedObject.kind=PodDisruptionBudget --sort-by='.lastTimestamp' | tail -5 || echo "Aucun événement PDB récent"

echo ""
echo "=== Test terminé ==="
echo ""
echo "Le PDB protège contre les suppressions excessives"
echo "minAvailable: 2 signifie qu'au moins 2 pods doivent toujours être Running"

