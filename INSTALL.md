# Installation et configuration

## Environnement

Cluster Kubernetes local avec :
- kind v0.20+
- kubectl v1.27+
- Ingress NGINX Controller
- cert-manager v1.13+

## Installation des prérequis

### Cluster kind

```bash
kind create cluster --name workshop
```

### Ingress NGINX

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=120s
```

### cert-manager

```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.2/cert-manager.yaml
kubectl wait --namespace cert-manager --for=condition=ready pod --selector=app.kubernetes.io/instance=cert-manager --timeout=120s
```

## Déploiement de l'application

### Méthode automatique

```bash
./deploy.sh
```

### Méthode manuelle

```bash
kubectl apply -f namespaces.yaml
kubectl apply -f configmap.yaml
kubectl apply -f secrets.yaml
kubectl apply -f certmanager.yaml
kubectl apply -f front.yaml
kubectl apply -f api.yaml
kubectl apply -f ingress.yaml
kubectl wait --for=condition=ready pod -n workshop --all --timeout=120s
```

## Configuration réseau

Ajouter dans `/etc/hosts` (Linux/Mac) ou `C:\Windows\System32\drivers\etc\hosts` (Windows) :

```
127.0.0.1 workshop.local
```

Pour kind avec ports mappés 8080 (HTTP) et 8443 (HTTPS), les applications sont directement accessibles.

## Vérification

```bash
# État des ressources
kubectl get all -n workshop
kubectl get ingress,certificate -n workshop

# Test HTTP
curl http://workshop.local:8080/front
curl http://workshop.local:8080/api/headers

# Test HTTPS
curl -k https://workshop.local:8443/front
curl -k https://workshop.local:8443/api/headers
```

## Configuration détaillée

### ConfigMap

Injecte `BANNER_TEXT` dans les pods front via :

```yaml
env:
  - name: BANNER_TEXT
    valueFrom:
      configMapKeyRef:
        name: front-config
        key: BANNER_TEXT
```

### Secret

Injecte `DB_USER` et `DB_PASS` dans les pods api via :

```yaml
env:
  - name: DB_USER
    valueFrom:
      secretKeyRef:
        name: app-secrets
        key: DB_USER
```

### Ingress

Routage L7 avec rewrite pour l'API :
- `/front` → Service front (rewrite vers `/`)
- `/api/(.*)` → Service api (rewrite vers `/$1`)

Configuration TLS automatique via cert-manager avec ClusterIssuer self-signed.

## Rollback

### Simuler une erreur

```bash
kubectl set image deployment/front front=nginx:broken -n workshop
kubectl rollout status deployment/front -n workshop
```

### Retour arrière

```bash
kubectl rollout undo deployment/front -n workshop
kubectl rollout status deployment/front -n workshop
```

### Historique

```bash
kubectl rollout history deployment/front -n workshop
kubectl rollout undo deployment/front -n workshop --to-revision=1
```

## Troubleshooting

### Pods en erreur

```bash
kubectl describe pod <pod-name> -n workshop
kubectl logs <pod-name> -n workshop
```

### Ingress ne répond pas

```bash
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller --tail=100
kubectl describe ingress web -n workshop
```

### Certificat non créé

```bash
kubectl get certificate,certificaterequest -n workshop
kubectl logs -n cert-manager deploy/cert-manager --tail=100
```

### Test direct des services

```bash
kubectl run test -n workshop --image=curlimages/curl --rm -it --restart=Never -- curl http://front/
kubectl run test -n workshop --image=curlimages/curl --rm -it --restart=Never -- curl http://api/headers
```

## Nettoyage

```bash
# Via script
./cleanup.sh

# Ou manuellement
kubectl delete namespace workshop
kind delete cluster --name workshop
```

## Notes techniques

- L'Ingress utilise `pathType: ImplementationSpecific` avec regex pour le rewrite
- Les certificats sont auto-signés (ClusterIssuer selfsigned) - pour production utiliser ACME/Let's Encrypt
- Les secrets sont encodés base64 mais non chiffrés - pour production utiliser Sealed Secrets ou External Secrets
- Stratégie de déploiement : RollingUpdate (zero downtime)
- Ressources définies : requests et limits pour éviter les noisy neighbors

