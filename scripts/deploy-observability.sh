#!/bin/bash

# Script de déploiement de la stack d'observabilité
# Prometheus + Grafana + Loki + Promtail + Jaeger

set -e

echo "=== Déploiement Stack Observabilité - TP S7 ==="
echo ""

# Vérifier que kubectl est installé
if ! command -v kubectl &> /dev/null; then
    echo "ERREUR: kubectl n'est pas installé"
    exit 1
fi

# Vérifier que helm est installé
if ! command -v helm &> /dev/null; then
    echo "ERREUR: helm n'est pas installé"
    echo "Installation de Helm..."
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

echo "Versions:"
echo "  kubectl: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
echo "  helm: $(helm version --short)"
echo ""

# Créer le namespace observability
echo "[Étape 1/6] Création du namespace observability..."
kubectl create namespace observability --dry-run=client -o yaml | kubectl apply -f -
echo ""

# Installer kube-prometheus-stack (Prometheus + Grafana)
echo "[Étape 2/6] Installation kube-prometheus-stack (Prometheus + Grafana)..."
if helm list -n observability | grep -q "^monitor"; then
    echo "kube-prometheus-stack déjà installé, upgrade..."
    helm upgrade monitor prometheus-community/kube-prometheus-stack \
      -n observability \
      --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
      --set grafana.adminPassword=admin \
      --wait --timeout=10m
else
    echo "Installation de kube-prometheus-stack..."
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null || true
    helm repo update
    helm install monitor prometheus-community/kube-prometheus-stack \
      -n observability \
      --create-namespace \
      --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
      --set grafana.adminPassword=admin \
      --wait --timeout=10m
fi
echo "OK - Prometheus & Grafana installés"
echo ""

# Installer Loki + Promtail
echo "[Étape 3/6] Installation Loki + Promtail..."
if helm list -n observability | grep -q "^loki"; then
    echo "Loki déjà installé, upgrade..."
    helm upgrade loki grafana/loki-stack \
      -n observability \
      --set promtail.enabled=true \
      --set loki.persistence.enabled=false \
      --wait --timeout=5m
else
    echo "Installation de Loki + Promtail..."
    helm repo add grafana https://grafana.github.io/helm-charts 2>/dev/null || true
    helm repo update
    helm install loki grafana/loki-stack \
      -n observability \
      --set promtail.enabled=true \
      --set loki.persistence.enabled=false \
      --wait --timeout=5m
fi
echo "OK - Loki & Promtail installés"
echo ""

# Installer Jaeger Operator
echo "[Étape 4/6] Installation Jaeger Operator..."
if kubectl get deployment jaeger-operator -n observability &> /dev/null; then
    echo "Jaeger Operator déjà installé"
else
    echo "Installation de Jaeger Operator..."
    kubectl apply -n observability -f https://github.com/jaegertracing/jaeger-operator/releases/download/v1.51.0/jaeger-operator.yaml
    echo "Attente du démarrage de Jaeger Operator..."
    kubectl wait --for=condition=available deployment/jaeger-operator -n observability --timeout=120s || true
fi
echo ""

# Déployer instance Jaeger
echo "[Étape 5/6] Déploiement instance Jaeger..."
cat <<'YAML' | kubectl apply -n observability -f -
apiVersion: jaegertracing.io/v1
kind: Jaeger
metadata:
  name: simplest
  namespace: observability
spec:
  strategy: allInOne
  allInOne:
    image: jaegertracing/all-in-one:latest
    options:
      log-level: info
  storage:
    type: memory
    options:
      memory:
        max-traces: 100000
YAML
echo "Attente du démarrage de Jaeger..."
sleep 10
kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=simplest -n observability --timeout=120s || true
echo "OK - Jaeger déployé"
echo ""

# Déployer les ServiceMonitors et PrometheusRules
echo "[Étape 6/6] Déploiement des ServiceMonitors et alertes..."
if [ -d "manifests/observability" ]; then
    kubectl apply -f manifests/observability/
    echo "OK - Manifests déployés"
else
    echo "ATTENTION: Dossier manifests/observability/ non trouvé"
fi
echo ""

# Résumé
echo "=== Déploiement terminé ==="
echo ""
echo "Services déployés:"
kubectl get pods -n observability
echo ""
echo "Accès aux interfaces:"
echo ""
echo "1. Grafana:"
echo "   kubectl port-forward -n observability svc/monitor-grafana 3000:80"
echo "   URL: http://localhost:3000"
echo "   Login: admin / admin"
echo ""
echo "2. Prometheus:"
echo "   kubectl port-forward -n observability svc/monitor-kube-prometheus-prometheus 9090:9090"
echo "   URL: http://localhost:9090"
echo ""
echo "3. Jaeger UI:"
echo "   kubectl port-forward -n observability svc/simplest-query 16686:16686"
echo "   URL: http://localhost:16686"
echo ""
echo "4. Loki (via Grafana):"
echo "   Datasource déjà configuré dans Grafana"
echo "   URL: http://loki:3100"
echo ""
echo "Commandes utiles:"
echo "  - Vérifier alertes: kubectl get prometheusrules -n observability"
echo "  - Vérifier ServiceMonitors: kubectl get servicemonitors -n observability"
echo "  - Logs Prometheus: kubectl logs -n observability -l app.kubernetes.io/name=prometheus"
echo ""

