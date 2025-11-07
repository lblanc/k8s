#!/bin/bash
set -euo pipefail

# ========= CONFIG ==========
EMAIL="email@luc-blanc.com"
DOMAIN="drawio.k8s-lab1.demo-lab.site"
NAMESPACE="drawio"
# ===========================

pause() {
  echo
  read -rp "➡️  Appuie sur [Entrée] pour continuer..."
  echo
}

echo "🔹 Création du namespace ${NAMESPACE}..."
kubectl get ns "${NAMESPACE}" >/dev/null 2>&1 || kubectl create ns "${NAMESPACE}"
echo "✅ Namespace prêt."
pause

echo "🔹 Installation de NGINX Ingress Controller..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml
echo
echo "✅ Ingress NGINX appliqué."
echo "Tu peux vérifier les pods avec : kubectl get pods -n ingress-nginx"
pause

echo "🔹 Patch du Service ingress-nginx-controller (type NodePort, ports 32080/32443)..."
kubectl patch svc ingress-nginx-controller -n ingress-nginx -p '{
  "spec": {
    "type": "NodePort",
    "externalTrafficPolicy": "Cluster",
    "ports": [
      {
        "name": "http",
        "port": 80,
        "nodePort": 32080,
        "protocol": "TCP",
        "targetPort": "http"
      },
      {
        "name": "https",
        "port": 443,
        "nodePort": 32443,
        "protocol": "TCP",
        "targetPort": "https"
      }
    ]
  }
}' || true
echo "✅ Service patché (ou déjà conforme)."
echo "Tu peux vérifier avec : kubectl get svc ingress-nginx-controller -n ingress-nginx"
pause

echo "🔹 Installation de cert-manager..."
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/latest/download/cert-manager.yaml
echo
echo "✅ cert-manager appliqué."
echo "Tu peux vérifier les pods avec : kubectl get pods -n cert-manager"
pause

echo "🔹 Création du ClusterIssuer (Let's Encrypt prod)..."
cat <<EOF > cluster-issuer.yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    email: ${EMAIL}
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
      - http01:
          ingress:
            class: nginx
EOF

kubectl apply -f cluster-issuer.yaml
echo "✅ ClusterIssuer letsencrypt-prod appliqué."
echo "Vérifie l'état : kubectl describe clusterissuer letsencrypt-prod"
pause

echo "🔹 Déploiement de draw.io (Deployment + Service)..."
cat <<'EOF' > drawio-deploy.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: drawio
  namespace: drawio
spec:
  replicas: 1
  selector:
    matchLabels:
      app: drawio
  template:
    metadata:
      labels:
        app: drawio
    spec:
      containers:
        - name: drawio
          image: jgraph/drawio:latest
          imagePullPolicy: IfNotPresent
          ports:
            - containerPort: 8080
          readinessProbe:
            httpGet:
              path: /
              port: 8080
            initialDelaySeconds: 5
            periodSeconds: 10
          livenessProbe:
            httpGet:
              path: /
              port: 8080
            initialDelaySeconds: 15
            periodSeconds: 20
          resources:
            requests:
              cpu: "100m"
              memory: "128Mi"
            limits:
              cpu: "500m"
              memory: "512Mi"
---
apiVersion: v1
kind: Service
metadata:
  name: drawio
  namespace: drawio
spec:
  type: ClusterIP
  selector:
    app: drawio
  ports:
    - name: http
      port: 80
      targetPort: 8080
EOF

kubectl apply -f drawio-deploy.yaml
echo "✅ draw.io déployé (deployment + service)."
echo "Tu peux vérifier : kubectl get deploy,svc -n ${NAMESPACE}"
pause

echo "🔹 Création de l'Ingress draw.io (TLS via cert-manager)..."
cat <<EOF > drawio-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: drawio
  namespace: ${NAMESPACE}
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - ${DOMAIN}
      secretName: drawio-tls
  rules:
    - host: ${DOMAIN}
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: drawio
                port:
                  number: 80
EOF

kubectl apply -f drawio-ingress.yaml
echo "✅ Ingress appliqué."
pause

echo "🌐 Installation terminée."
echo "Accès (une fois le certificat émis) : https://${DOMAIN}"
echo "Ports NodePort exposés sur les nodes : 32080 (HTTP), 32443 (HTTPS)"
echo
echo "🔎 Debug utiles :"
echo " - kubectl describe ingress drawio -n ${NAMESPACE}"
echo " - kubectl describe certificate drawio-tls -n ${NAMESPACE}"
echo " - kubectl logs -n cert-manager -l app.kubernetes.io/instance=cert-manager"
