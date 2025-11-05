#!/bin/bash

# Script de nettoyage - TP S4

echo "=== Nettoyage du TP S4 ==="
echo ""

echo "Suppression du namespace workshop..."
kubectl delete namespace workshop --ignore-not-found=true

echo ""
echo "Vérification..."
kubectl get namespace workshop 2>/dev/null && echo "ATTENTION: Le namespace existe encore" || echo "OK - Namespace supprimé"

echo ""
echo "=== Nettoyage terminé ==="
echo ""
echo "Pour supprimer le cluster kind complet :"
echo "  kind delete cluster --name workshop"

