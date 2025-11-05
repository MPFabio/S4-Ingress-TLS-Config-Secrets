#!/bin/bash

# Script de test des alertes Prometheus

set -e

echo "=== Test des Alertes Prometheus ==="
echo ""

NAMESPACE="workshop"

echo "Ce script va générer des conditions pour déclencher les alertes."
echo "Les alertes mettent 10-15 minutes à se déclencher (fenêtre d'observation)."
echo ""

# Menu
echo "Choisissez l'alerte à tester :"
echo "  1) HighErrorRate (taux d'erreurs > 2%)"
echo "  2) PodHighRestarts (redémarrages > 5)"
echo "  3) HighCPUSaturation (CPU > 80%)"
echo "  4) Toutes les alertes"
echo "  0) Annuler"
echo ""
read -p "Votre choix: " CHOICE

case $CHOICE in
    1)
        echo ""
        echo "[Test 1] Déclenchement de HighErrorRate..."
        echo "Génération d'erreurs 5xx sur l'API..."
        echo ""
        
        kubectl run error-generator -n $NAMESPACE \
          --image=curlimages/curl \
          --restart=Never \
          --rm -i \
          -- sh -c 'for i in $(seq 1 100); do curl -s http://api/status/500 >/dev/null; sleep 0.5; done' &
        
        echo "Générateur d'erreurs lancé en arrière-plan"
        echo "Attendre 10 minutes pour que l'alerte se déclenche"
        echo ""
        echo "Vérifier l'alerte sur http://localhost:9090/alerts (HighErrorRate)"
        echo "  kubectl port-forward -n observability svc/monitor-kube-prometheus-prometheus 9090:9090"
        ;;
        
    2)
        echo ""
        echo "[Test 2] Déclenchement de PodHighRestarts..."
        echo "Cette alerte se déclenche automatiquement si un pod crashe."
        echo ""
        echo "Pour simuler, modifier le deployment API avec une commande qui crash :"
        echo ""
        echo "  kubectl patch deployment api -n $NAMESPACE --type='json' \\"
        echo "    -p='[{\"op\": \"replace\", \"path\": \"/spec/template/spec/containers/0/command\", \"value\": [\"sh\", \"-c\", \"exit 1\"]}]'"
        echo ""
        echo "Puis restaurer le deployment :"
        echo "  kubectl rollout undo deployment/api -n $NAMESPACE"
        ;;
        
    3)
        echo ""
        echo "[Test 3] Déclenchement de HighCPUSaturation..."
        echo "Génération de charge CPU intensive..."
        echo ""
        
        # Lancer plusieurs générateurs de charge
        for i in {1..5}; do
            kubectl run cpu-stress-$i -n $NAMESPACE \
              --image=busybox \
              --restart=Never \
              --rm -i \
              --labels="stress=cpu" \
              -- sh -c 'while true; do :; done' &
        done
        
        echo "5 générateurs de charge CPU lancés"
        echo "Attendre 10 minutes pour que l'alerte se déclenche"
        echo ""
        echo "Observer le CPU :"
        echo "  kubectl top pods -n $NAMESPACE"
        echo ""
        echo "Vérifier l'alerte sur http://localhost:9090/alerts (HighCPUSaturation)"
        echo ""
        echo "Arrêter les générateurs :"
        echo "  kubectl delete pods -n $NAMESPACE -l stress=cpu --force --grace-period=0"
        ;;
        
    4)
        echo ""
        echo "[Test All] Déclenchement de toutes les alertes testables..."
        echo ""
        
        # Erreurs
        echo "1. Génération d'erreurs 5xx..."
        kubectl run error-gen -n $NAMESPACE \
          --image=curlimages/curl \
          --restart=Never \
          --labels="test=errors" \
          -- sh -c 'while true; do curl -s http://api/status/500 >/dev/null; sleep 1; done' 2>/dev/null &
        
        # CPU
        echo "2. Génération de charge CPU..."
        for i in {1..3}; do
            kubectl run cpu-$i -n $NAMESPACE \
              --image=busybox \
              --restart=Never \
              --labels="test=cpu" \
              -- sh -c 'while true; do :; done' 2>/dev/null &
        done
        
        echo ""
        echo "Tests lancés en arrière-plan"
        echo "Attendre 10-15 minutes pour que les alertes se déclenchent"
        echo ""
        echo "Vérifier les alertes :"
        echo "  kubectl port-forward -n observability svc/monitor-kube-prometheus-prometheus 9090:9090"
        echo "  → http://localhost:9090/alerts"
        echo ""
        echo "Nettoyer les tests :"
        echo "  kubectl delete pods -n $NAMESPACE -l test=errors,test=cpu --force --grace-period=0"
        ;;
        
    0)
        echo "Annulé"
        exit 0
        ;;
        
    *)
        echo "Choix invalide"
        exit 1
        ;;
esac

echo ""
echo "=== Commandes utiles ==="
echo ""
echo "# Voir les alertes dans Prometheus"
echo "kubectl port-forward -n observability svc/monitor-kube-prometheus-prometheus 9090:9090"
echo "# → http://localhost:9090/alerts"
echo ""
echo "# Voir les alertes dans Grafana"
echo "kubectl port-forward -n observability svc/monitor-grafana 3000:80"
echo "# → http://localhost:3000/alerting/list"
echo ""
echo "# Vérifier les PrometheusRules"
echo "kubectl get prometheusrules -n observability"
echo ""
echo "# Nettoyer tous les pods de test"
echo "kubectl delete pods -n $NAMESPACE -l stress=cpu --force --grace-period=0"
echo "kubectl delete pods -n $NAMESPACE -l test --force --grace-period=0"
echo ""

