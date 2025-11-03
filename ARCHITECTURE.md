# Architecture du TP S4 — Flux L7 avec Ingress et TLS

## Diagramme général

```mermaid
flowchart TB
    Client[Client HTTPS] --> DNS[workshop.local]
    DNS --> Ingress[Ingress NGINX<br/>TLS Termination]
    
    Ingress -->|/front| SvcFront[Service front:80]
    Ingress -->|/api| SvcApi[Service api:80]
    
    SvcFront --> PodFront1[Pod front-1]
    SvcFront --> PodFront2[Pod front-2]
    
    SvcApi --> PodApi1[Pod api-1]
    SvcApi --> PodApi2[Pod api-2]
    
    CertManager[cert-manager] -.certificat.-> Ingress
    ConfigMap[ConfigMap] -.BANNER_TEXT.-> SvcFront
    SecretApp[Secret] -.credentials.-> SvcApi
```

---

## Détail des composants

### 1. Client & DNS

```mermaid
sequenceDiagram
    participant Client
    participant DNS
    participant Ingress
    
    Client->>DNS: Résolution de workshop.local
    DNS-->>Client: IP du cluster (127.0.0.1)
    Client->>Ingress: HTTPS Request (port 443)
```

**Explication :**
- Le client résout `workshop.local` via le fichier `/etc/hosts`
- La requête HTTPS est envoyée vers l'Ingress Controller
- Port 443 pour HTTPS (ou 8443 si port-forward)

---

### 2. Ingress Controller — Terminaison TLS (L7)

```mermaid
flowchart LR
    A[Client HTTPS<br/>Chiffré] --> B[Ingress NGINX<br/>TLS Termination]
    B --> C[Service front:80<br/>HTTP]
    B --> D[Service api:80<br/>HTTP]
    
    E[Secret web-tls] -.certificat TLS.-> B
```

**Explication :**
- L'Ingress Controller **termine le TLS** (déchiffre HTTPS → HTTP)
- Le trafic entre Ingress et Services est en **HTTP clair** (interne au cluster)
- Le certificat provient du Secret `web-tls` créé par cert-manager

**Règles de routage (Layer 7) :**
```yaml
Host: workshop.local
  ├── /front → Service front:80
  └── /api   → Service api:80
```

---

### 3. Cert-manager — Gestion automatique des certificats

```mermaid
flowchart TB
    A[ClusterIssuer selfsigned] --> B[Ingress]
    B --> C[cert-manager]
    C --> D[CertificateRequest]
    D --> E[Certificate web-tls]
    E --> F[Secret web-tls]
    F --> G[Ingress Controller]
```

**Processus :**
1. L'Ingress a une annotation `cert-manager.io/cluster-issuer: selfsigned`
2. Cert-manager détecte cette annotation
3. Il crée une `CertificateRequest` automatiquement
4. Le ClusterIssuer `selfsigned` génère un certificat auto-signé
5. Le certificat est stocké dans le Secret `web-tls`
6. L'Ingress utilise ce Secret pour le TLS

**Vérification :**
```bash
kubectl get certificate,certificaterequest,secret -n workshop
```

---

### 4. Services et Load Balancing

```mermaid
flowchart TB
    Ingress[Ingress] -->|app=front| SvcFront[Service front]
    Ingress -->|app=api| SvcApi[Service api]
    
    SvcFront -->|round-robin| P1[Pod front-1]
    SvcFront -->|round-robin| P2[Pod front-2]
    
    SvcApi -->|round-robin| P3[Pod api-1]
    SvcApi -->|round-robin| P4[Pod api-2]
```

**Explication :**
- Les Services utilisent des **selectors** pour trouver les pods (`app: front`, `app: api`)
- Le trafic est **load-balancé** entre les pods (Round-robin par défaut)
- Type de Service : **ClusterIP** (interne uniquement, pas exposé à l'extérieur)

---

### 5. ConfigMap & Secret — Injection dans les Pods

```mermaid
flowchart LR
    CM[ConfigMap<br/>BANNER_TEXT] -.valueFrom.-> PF[Pod front]
    S[Secret<br/>DB_USER, DB_PASS] -.secretKeyRef.-> PA[Pod api]
```

**ConfigMap (données non sensibles) :**
```yaml
env:
  - name: BANNER_TEXT
    valueFrom:
      configMapKeyRef:
        name: front-config
        key: BANNER_TEXT
```

**Secret (données sensibles) :**
```yaml
env:
  - name: DB_USER
    valueFrom:
      secretKeyRef:
        name: app-secrets
        key: DB_USER
```

**Différences clés :**
- **ConfigMap** : Données lisibles en clair dans `kubectl get`
- **Secret** : Données encodées base64, accès contrôlé par RBAC

---

## Flux de requête complet

```mermaid
sequenceDiagram
    autonumber
    participant Client
    participant DNS
    participant Ingress as Ingress NGINX
    participant Cert as Secret web-tls
    participant Service as Service front
    participant Pod as Pod front-1
    participant Config as ConfigMap
    
    Client->>DNS: Résolution workshop.local
    DNS-->>Client: 127.0.0.1
    
    Client->>Ingress: GET https://workshop.local/front
    Note over Client,Ingress: TLS Handshake
    
    Ingress->>Cert: Récupère certificat
    Cert-->>Ingress: tls.crt + tls.key
    Ingress-->>Client: Certificat présenté
    
    Note over Client,Ingress: TLS Session établie (chiffré)
    
    Ingress->>Ingress: Déchiffre HTTPS → HTTP
    Note over Ingress: Routing L7: /front → Service front
    
    Ingress->>Service: GET http://front:80/front
    Service->>Service: Load balancing (Round-robin)
    Service->>Pod: Forward vers Pod front-1
    
    Pod->>Config: Lit BANNER_TEXT
    Config-->>Pod: "Hello M2 IR"
    
    Pod-->>Service: HTTP 200 + HTML
    Service-->>Ingress: HTTP 200 + HTML
    
    Ingress->>Ingress: Chiffre HTTP → HTTPS
    Ingress-->>Client: HTTPS 200 + HTML (chiffré)
```

**Points clés :**
1. **TLS Termination** : Le chiffrement s'arrête à l'Ingress
2. **Routing L7** : L'Ingress analyse le path HTTP (pas juste IP:PORT)
3. **Load Balancing** : Le Service répartit entre les pods
4. **Injection Config** : Le pod lit les variables du ConfigMap au démarrage

---

## Comparaison Ingress (L7) vs Service (L4)

| Aspect | Service LoadBalancer (L4) | Ingress (L7) |
|--------|---------------------------|--------------|
| **Layer OSI** | Transport (TCP/UDP) | Application (HTTP/HTTPS) |
| **Routage** | Par IP:PORT uniquement | Par Host + Path |
| **TLS** | Géré par l'application | Terminaison au niveau Ingress |
| **Coût Cloud** | 1 IP publique par service | 1 IP pour tous les services |
| **Exemple** | `myapp.com:8080` → Service | `myapp.com/front`, `myapp.com/api` |

**Exemple de routage L7 :**
```
https://workshop.local/front → Service front
https://workshop.local/api   → Service api
https://workshop.local/admin → Service admin

Avec 1 seule IP publique !
```

**Exemple de routage L4 :**
```
https://front.workshop.local:443   → Service front (IP 1)
https://api.workshop.local:443     → Service api (IP 2)
https://admin.workshop.local:443   → Service admin (IP 3)

3 IP publiques nécessaires
```

---

## Stratégie de déploiement et Rollback

```mermaid
flowchart TB
    subgraph Avant Rollout
        D1[Deployment front<br/>Revision 1<br/>Image: nginx:1.0]
        P1[Pod front-1<br/>Image: nginx:1.0]
        P2[Pod front-2<br/>Image: nginx:1.0]
        D1 --> P1
        D1 --> P2
    end
    
    subgraph Pendant Rollout défectueux
        D2[Deployment front<br/>Revision 2<br/>Image: nginx:broken]
        P3[Pod front-3<br/>ImagePullBackOff]
        P4[Pod front-1<br/>Running - Image: nginx:1.0]
        P5[Pod front-2<br/>Running - Image: nginx:1.0]
        D2 --> P3
        D2 --> P4
        D2 --> P5
        Note1[Nouveaux pods: ImagePullBackOff<br/>Anciens pods: Running]
    end
    
    subgraph Après Rollback
        D3[Deployment front<br/>Revision 3 = Revision 1<br/>Image: nginx:1.0]
        P6[Pod front-1<br/>Image: nginx:1.0]
        P7[Pod front-2<br/>Image: nginx:1.0]
        D3 --> P6
        D3 --> P7
        Note2[Retour à la version stable]
    end
    
    Avant --> Pendant
    Pendant --> Après
```

**Commandes :**
```bash
# Déploiement défectueux
kubectl set image deployment/front front=nginx:broken -n workshop

# Rollback immédiat
kubectl rollout undo deployment/front -n workshop

# Rollback vers une révision spécifique
kubectl rollout undo deployment/front -n workshop --to-revision=1
```

**Stratégie RollingUpdate (par défaut) :**
- Kubernetes remplace les pods **progressivement**
- Si les nouveaux pods échouent, les anciens **restent actifs**
- **Zero downtime** dans la plupart des cas

---

## Isolation et sécurité

```mermaid
flowchart TB
    External[External Traffic] --> NSIngress[ingress-nginx namespace]
    NSIngress --> Ingress[Ingress Controller]
    
    Ingress --> NSWorkshop[workshop namespace]
    
    subgraph NSWorkshop
        SvcF[Service front]
        SvcA[Service api]
        PF1[Pod front-1]
        PF2[Pod front-2]
        PA1[Pod api-1]
        PA2[Pod api-2]
        CM[ConfigMap]
        S[Secret]
        
        SvcF --> PF1
        SvcF --> PF2
        SvcA --> PA1
        SvcA --> PA2
        CM -.-> PF1
        CM -.-> PF2
        S -.-> PA1
        S -.-> PA2
    end
    
    NSCert[cert-manager namespace] -.certificats.-> NSWorkshop
```

**Points de sécurité :**

1. **Namespace isolation** : Les ressources sont isolées dans `workshop`
2. **Secret base64** : Les credentials sont encodés (pas chiffrés !)
3. **TLS termination** : Le trafic externe est chiffré
4. **ClusterIP** : Les services ne sont pas exposés à l'extérieur
5. **RBAC** : L'accès aux Secrets peut être contrôlé (non configuré dans ce TP)

**Important en production :**
- Utiliser **Sealed Secrets** ou **External Secrets** pour chiffrer les secrets dans Git
- Activer **RBAC** strict
- Utiliser **NetworkPolicy** pour limiter la communication entre pods
- Utiliser un certificat **Let's Encrypt** au lieu de self-signed

---

## Résumé des flux de données

### Flux 1 : Configuration au démarrage
```
1. Deployment créé
2. Pod démarre
3. Kubelet lit ConfigMap/Secret
4. Variables injectées dans le conteneur
5. Application démarre avec config
```

### Flux 2 : Requête HTTP
```
1. Client → DNS (workshop.local)
2. Client → Ingress (HTTPS)
3. Ingress → TLS termination (HTTPS → HTTP)
4. Ingress → Routage L7 (/front ou /api)
5. Ingress → Service (ClusterIP)
6. Service → Load balancing (Round-robin)
7. Service → Pod sélectionné
8. Pod → Traite la requête
9. Pod → Service → Ingress → Client (HTTP → HTTPS)
```

### Flux 3 : Gestion des certificats
```
1. Ingress créé avec annotation cert-manager
2. cert-manager détecte l'Ingress
3. cert-manager crée CertificateRequest
4. ClusterIssuer génère certificat
5. Certificat stocké dans Secret web-tls
6. Ingress utilise le Secret pour TLS
7. Renouvellement automatique avant expiration
```

---

## Concepts clés à retenir

| Concept | Description | Exemple dans le TP |
|---------|-------------|-------------------|
| **Ingress** | Routage HTTP L7 | `workshop.local/front` → Service front |
| **Ingress Controller** | Implémentation de l'Ingress | NGINX Ingress Controller |
| **TLS Termination** | Déchiffrement HTTPS au niveau Ingress | Certificat dans Secret web-tls |
| **cert-manager** | Gestion automatique des certificats | ClusterIssuer selfsigned |
| **ConfigMap** | Config non sensible | BANNER_TEXT |
| **Secret** | Données sensibles | DB_USER, DB_PASS |
| **Service ClusterIP** | Exposition interne | front:80, api:80 |
| **Rollback** | Retour version précédente | `kubectl rollout undo` |
| **RollingUpdate** | Mise à jour progressive | 0 downtime |

---

## Ressources

- [Kubernetes Ingress Documentation](https://kubernetes.io/docs/concepts/services-networking/ingress/)
- [NGINX Ingress Controller](https://kubernetes.github.io/ingress-nginx/)
- [cert-manager Documentation](https://cert-manager.io/docs/)
- [ConfigMaps](https://kubernetes.io/docs/concepts/configuration/configmap/)
- [Secrets](https://kubernetes.io/docs/concepts/configuration/secret/)

---

**Félicitations ! Vous avez maintenant une vision complète de l'architecture L7 avec Ingress, TLS et gestion des configurations.**


