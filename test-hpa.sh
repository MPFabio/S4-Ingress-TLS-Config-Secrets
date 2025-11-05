#!/bin/bash

# Script de test HPA avec génération de charge CPU

set -e

NAMESPACE="workshop"

echo "=== Test HPA (Horizontal Pod Autoscaler) ==="
echo ""

# Vérifier que HPA existe
if ! kubectl get hpa -n "$NAMESPACE" &> /dev/null; then
    echo "ERREUR: Aucun HPA trouvé. Déployez d'abord avec ./deploy-scaling.sh"
    exit 1
fi

echo "HPA configurés:"
kubectl get hpa -n "$NAMESPACE"
echo ""

# État initial
echo "État initial des pods:"
kubectl get pods -n "$NAMESPACE" -l app=api
echo ""

echo "Génération de charge CPU sur l'API..."
echo "Lancement de 5 générateurs de charge en parallèle..."
echo ""

# Générer de la charge
for i in {1..5}; do
    kubectl run load-generator-$i -n "$NAMESPACE" \
      --image=busybox \
      --restart=Never \
      --rm -i \
      --labels="load=generator" \
      -- /bin/sh -c "while true; do wget -q -O- http://api/delay/0.5; done" &
done

echo "Charge générée. Observation du scaling (2 minutes)..."
echo "Appuyez sur Ctrl+C pour arrêter"
echo ""

# Observer pendant 2 minutes
for i in {1..24}; do
    clear
    echo "=== Observation HPA ($(($i * 5))s) ==="
    echo ""
    kubectl get hpa -n "$NAMESPACE"
    echo ""
    echo "Pods:"
    kubectl get pods -n "$NAMESPACE" -l app=api --no-headers | wc -l
    kubectl get pods -n "$NAMESPACE" -l app=api
    echo ""
    echo "Métriques CPU actuelles:"
    kubectl top pods -n "$NAMESPACE" -l app=api 2>/dev/null || echo "Métriques en cours de collecte..."
    sleep 5
done

echo ""
echo "=== Test terminé ==="
echo ""
echo "Nettoyage des générateurs de charge..."
kubectl delete pods -n "$NAMESPACE" -l load=generator --force --grace-period=0 2>/dev/null || true

echo ""
echo "Le HPA va maintenant descaler progressivement vers minReplicas (5 minutes)"
echo "Observer avec: watch -n 2 'kubectl get hpa,pods -n workshop'"



