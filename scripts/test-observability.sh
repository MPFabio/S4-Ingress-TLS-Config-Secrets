#!/bin/bash

# Script de test de la stack d'observabilité

set -e

echo "=== Test de la Stack Observabilité ==="
echo ""

NAMESPACE_OBS="observability"
NAMESPACE_APP="workshop"

# Fonction pour attendre qu'un port-forward soit prêt
wait_for_port() {
    local port=$1
    local max_wait=10
    local count=0
    
    while ! nc -z localhost $port 2>/dev/null && [ $count -lt $max_wait ]; do
        sleep 1
        ((count++))
    done
    
    if [ $count -eq $max_wait ]; then
        echo "TIMEOUT: Port $port non accessible"
        return 1
    fi
    return 0
}

# 1. Vérifier que les pods sont Running
echo "[Test 1/7] Vérification des pods observability..."
PODS_NOT_RUNNING=$(kubectl get pods -n $NAMESPACE_OBS --field-selector=status.phase!=Running --no-headers 2>/dev/null | wc -l)
if [ "$PODS_NOT_RUNNING" -gt 0 ]; then
    echo "❌ ERREUR: $PODS_NOT_RUNNING pod(s) non-Running"
    kubectl get pods -n $NAMESPACE_OBS
    exit 1
else
    echo "✅ OK - Tous les pods sont Running"
fi
echo ""

# 2. Vérifier Prometheus
echo "[Test 2/7] Test de Prometheus..."
kubectl port-forward -n $NAMESPACE_OBS svc/monitor-kube-prometheus-prometheus 9090:9090 >/dev/null 2>&1 &
PF_PROM_PID=$!
sleep 3

if wait_for_port 9090; then
    PROM_READY=$(curl -s http://localhost:9090/-/ready)
    if [ "$PROM_READY" == "Prometheus is Ready." ]; then
        echo "✅ OK - Prometheus est accessible et ready"
    else
        echo "❌ ERREUR: Prometheus n'est pas ready"
    fi
else
    echo "❌ ERREUR: Impossible d'accéder à Prometheus"
fi
kill $PF_PROM_PID 2>/dev/null || true
echo ""

# 3. Vérifier Grafana
echo "[Test 3/7] Test de Grafana..."
kubectl port-forward -n $NAMESPACE_OBS svc/monitor-grafana 3000:80 >/dev/null 2>&1 &
PF_GRAFANA_PID=$!
sleep 3

if wait_for_port 3000; then
    GRAFANA_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/api/health)
    if [ "$GRAFANA_STATUS" == "200" ]; then
        echo "✅ OK - Grafana est accessible"
    else
        echo "❌ ERREUR: Grafana retourne HTTP $GRAFANA_STATUS"
    fi
else
    echo "❌ ERREUR: Impossible d'accéder à Grafana"
fi
kill $PF_GRAFANA_PID 2>/dev/null || true
echo ""

# 4. Vérifier Loki
echo "[Test 4/7] Test de Loki..."
kubectl port-forward -n $NAMESPACE_OBS svc/loki 3100:3100 >/dev/null 2>&1 &
PF_LOKI_PID=$!
sleep 3

if wait_for_port 3100; then
    LOKI_READY=$(curl -s http://localhost:3100/ready)
    if [ "$LOKI_READY" == "ready" ]; then
        echo "✅ OK - Loki est accessible et ready"
    else
        echo "⚠️  WARNING: Loki retourne: $LOKI_READY"
    fi
else
    echo "❌ ERREUR: Impossible d'accéder à Loki"
fi
kill $PF_LOKI_PID 2>/dev/null || true
echo ""

# 5. Vérifier Jaeger
echo "[Test 5/7] Test de Jaeger..."
kubectl port-forward -n $NAMESPACE_OBS svc/simplest-query 16686:16686 >/dev/null 2>&1 &
PF_JAEGER_PID=$!
sleep 3

if wait_for_port 16686; then
    JAEGER_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:16686/)
    if [ "$JAEGER_STATUS" == "200" ]; then
        echo "✅ OK - Jaeger UI est accessible"
    else
        echo "❌ ERREUR: Jaeger retourne HTTP $JAEGER_STATUS"
    fi
else
    echo "❌ ERREUR: Impossible d'accéder à Jaeger"
fi
kill $PF_JAEGER_PID 2>/dev/null || true
echo ""

# 6. Vérifier les ServiceMonitors
echo "[Test 6/7] Vérification des ServiceMonitors..."
SM_COUNT=$(kubectl get servicemonitors -n $NAMESPACE_OBS --no-headers 2>/dev/null | wc -l)
if [ "$SM_COUNT" -gt 0 ]; then
    echo "✅ OK - $SM_COUNT ServiceMonitor(s) déployé(s)"
    kubectl get servicemonitors -n $NAMESPACE_OBS
else
    echo "⚠️  WARNING: Aucun ServiceMonitor trouvé"
fi
echo ""

# 7. Vérifier les PrometheusRules
echo "[Test 7/7] Vérification des PrometheusRules (alertes)..."
PR_COUNT=$(kubectl get prometheusrules -n $NAMESPACE_OBS --no-headers 2>/dev/null | wc -l)
if [ "$PR_COUNT" -gt 0 ]; then
    echo "✅ OK - $PR_COUNT PrometheusRule(s) déployé(s)"
    kubectl get prometheusrules -n $NAMESPACE_OBS
else
    echo "⚠️  WARNING: Aucune PrometheusRule trouvée"
fi
echo ""

# Résumé
echo "=== Résumé ==="
echo ""
echo "Stack d'observabilité déployée :"
kubectl get pods -n $NAMESPACE_OBS -o wide
echo ""
echo "Accès aux interfaces :"
echo "  - Grafana:    kubectl port-forward -n observability svc/monitor-grafana 3000:80"
echo "                → http://localhost:3000 (admin/admin)"
echo ""
echo "  - Prometheus: kubectl port-forward -n observability svc/monitor-kube-prometheus-prometheus 9090:9090"
echo "                → http://localhost:9090"
echo ""
echo "  - Jaeger:     kubectl port-forward -n observability svc/simplest-query 16686:16686"
echo "                → http://localhost:16686"
echo ""
echo "Dashboard Grafana :"
echo "  1. Importer dashboards/workshop-api-dashboard.json"
echo "  2. Ou aller dans Dashboards > Browse"
echo ""
echo "Pour tester les alertes :"
echo "  ./scripts/test-alerts.sh"
echo ""

