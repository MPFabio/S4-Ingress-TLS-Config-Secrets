#!/bin/bash

# Script de déploiement automatique - TP S4
# Ingress, TLS, Config & Secrets

set -e

echo "=== Déploiement du TP S4 - Ingress, TLS, Config & Secrets ==="
echo ""

# Détection de l'OS
OS="$(uname -s)"
ARCH="$(uname -m)"

# Fonction d'installation de kubectl
install_kubectl() {
    echo "Installation de kubectl..."
    case "$OS" in
        Linux*)
            curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
            chmod +x kubectl
            sudo mv kubectl /usr/local/bin/
            ;;
        Darwin*)
            curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/darwin/amd64/kubectl"
            chmod +x kubectl
            sudo mv kubectl /usr/local/bin/
            ;;
        MINGW*|MSYS*|CYGWIN*)
            echo "Sur Windows, téléchargez kubectl depuis : https://kubernetes.io/docs/tasks/tools/install-kubectl-windows/"
            exit 1
            ;;
    esac
    echo "kubectl installé"
}

# Fonction d'installation de kind
install_kind() {
    echo "Installation de kind..."
    case "$OS" in
        Linux*)
            curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
            chmod +x ./kind
            sudo mv ./kind /usr/local/bin/kind
            ;;
        Darwin*)
            curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-darwin-amd64
            chmod +x ./kind
            sudo mv ./kind /usr/local/bin/kind
            ;;
        MINGW*|MSYS*|CYGWIN*)
            curl -Lo kind-windows-amd64.exe https://kind.sigs.k8s.io/dl/v0.20.0/kind-windows-amd64
            mkdir -p "$HOME/bin"
            mv kind-windows-amd64.exe "$HOME/bin/kind.exe"
            export PATH="$HOME/bin:$PATH"
            ;;
    esac
    echo "kind installé"
}

# Fonction d'installation de helm
install_helm() {
    echo "Installation de helm..."
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    echo "helm installé"
}

# Vérifications et installations
echo "[Étape 0] Vérification des prérequis..."
echo ""

if ! command -v kubectl &> /dev/null; then
    echo "kubectl non trouvé"
    install_kubectl
else
    echo "kubectl : OK ($(kubectl version --client --short 2>/dev/null || kubectl version --client | head -1))"
fi

if ! command -v kind &> /dev/null; then
    echo "kind non trouvé"
    install_kind
else
    echo "kind : OK ($(kind version 2>/dev/null | head -1))"
fi

if ! command -v helm &> /dev/null; then
    echo "helm non trouvé"
    install_helm
else
    echo "helm : OK ($(helm version --short 2>/dev/null || echo "installé"))"
fi

echo ""

# Vérifier si un cluster existe
echo "[Étape 1] Vérification du cluster..."
if ! kubectl cluster-info &> /dev/null; then
    echo "Aucun cluster détecté. Création d'un cluster kind 'workshop'..."
    
    # Créer la configuration kind
    cat > /tmp/kind-config.yaml <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 8080
    protocol: TCP
  - containerPort: 443
    hostPort: 8443
    protocol: TCP
EOF
    
    kind create cluster --name workshop --config /tmp/kind-config.yaml
    rm /tmp/kind-config.yaml
else
    echo "Cluster existant détecté"
fi
echo ""

# Vérifier et installer Ingress NGINX Controller
echo "[Étape 2] Vérification de l'Ingress NGINX Controller..."
if ! kubectl get namespace ingress-nginx &> /dev/null; then
    echo "Installation de l'Ingress NGINX Controller..."
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
    echo "Attente du démarrage de l'Ingress Controller..."
    kubectl wait --namespace ingress-nginx --for=condition=available deployment --selector=app.kubernetes.io/component=controller --timeout=120s
    echo "Attente de la complétion des jobs d'admission..."
    kubectl wait --namespace ingress-nginx --for=condition=complete job --selector=app.kubernetes.io/component=admission-webhook --timeout=120s || true
    echo "Attente de la disponibilité du webhook (10s supplémentaires)..."
    sleep 10
else
    echo "Ingress NGINX Controller déjà installé"
fi
echo ""

# Vérifier et installer cert-manager
echo "[Étape 3] Vérification de cert-manager..."
if ! kubectl get namespace cert-manager &> /dev/null; then
    echo "Installation de cert-manager..."
    kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.2/cert-manager.yaml
    echo "Attente du démarrage de cert-manager..."
    kubectl wait --namespace cert-manager --for=condition=ready pod --selector=app.kubernetes.io/instance=cert-manager --timeout=120s
else
    echo "cert-manager déjà installé"
fi
echo ""

# Déployer le namespace
echo "[Étape 4] Création du namespace workshop..."
kubectl apply -f namespaces.yaml
echo ""

# Déployer ConfigMap et Secrets
echo "[Étape 5] Déploiement des ConfigMap et Secrets..."
kubectl apply -f configmap.yaml
kubectl apply -f secrets.yaml
echo ""

# Déployer le ClusterIssuer
echo "[Étape 6] Déploiement du ClusterIssuer..."
kubectl apply -f certmanager.yaml
echo ""

# Déployer les applications
echo "[Étape 7] Déploiement des applications (front + api)..."
kubectl apply -f front.yaml
kubectl apply -f api.yaml
echo ""

# Déployer l'Ingress
echo "[Étape 8] Déploiement de l'Ingress..."
kubectl apply -f ingress.yaml
echo ""

# Attendre que les pods soient prêts
echo "Attente du démarrage des pods (max 120s)..."
kubectl wait --for=condition=ready pod -n workshop --all --timeout=120s || true
echo ""

# Afficher l'état
echo "=== État du déploiement ==="
echo ""
echo "Pods :"
kubectl get pods -n workshop
echo ""
echo "Services :"
kubectl get svc -n workshop
echo ""
echo "Ingress :"
kubectl get ingress -n workshop
echo ""
echo "Certificat TLS :"
kubectl get certificate -n workshop 2>/dev/null || echo "Certificat en cours de création..."
echo ""

# Instructions d'accès
echo "=== Accès aux applications ==="
echo ""
echo "Assurez-vous d'avoir ajouté dans votre fichier hosts :"
echo "  127.0.0.1 workshop.local"
echo ""
echo "Fichier hosts :"
case "$OS" in
    Linux*|Darwin*)
        echo "  sudo sh -c 'echo \"127.0.0.1 workshop.local\" >> /etc/hosts'"
        ;;
    MINGW*|MSYS*|CYGWIN*)
        echo "  Éditez C:\\Windows\\System32\\drivers\\etc\\hosts en tant qu'Administrateur"
        ;;
esac
echo ""
echo "Accès HTTP :"
echo "  - Front : http://workshop.local:8080/front"
echo "  - API   : http://workshop.local:8080/api/headers"
echo ""
echo "Accès HTTPS :"
echo "  - Front : https://workshop.local:8443/front"
echo "  - API   : https://workshop.local:8443/api/headers"
echo ""
echo "=== Déploiement terminé ==="
