#!/bin/bash
set -euo pipefail

# ========= CONFIG ==========
EMAIL="email@luc-blanc.com"
DOMAIN="headlamp.k8s-lab0.demo-lab.site"
# ===========================

pause() {
  echo
  read -rp "➡️  Appuie sur [Entrée] pour continuer..."
  echo
}

echo "🔹 Installation de Headlamp..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/headlamp/main/kubernetes-headlamp.yaml

echo
echo "✅ Headlamp déployé."
echo "Tu peux vérifier avec : kubectl get svc -n kube-system | grep headlamp"
pause

echo "🔹 Installation de NGINX Ingress Controller..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml

echo
echo "✅ Ingress NGINX appliqué."
echo "Tu peux vérifier les pods avec : kubectl get pods -n ingress-nginx"
pause

echo "🔹 Modification automatique du Service ingress-nginx-controller (type NodePort, ports 32080/32443)..."

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
}'

echo
echo "✅ Service patché automatiquement."
echo "Tu peux vérifier avec : kubectl get svc ingress-nginx-controller -n ingress-nginx"
pause

echo "🔹 Installation de cert-manager..."
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/latest/download/cert-manager.yaml

echo
echo "✅ cert-manager appliqué."
echo "Tu peux vérifier les pods avec : kubectl get pods -n cert-manager"
pause

echo "🔹 Création du ClusterIssuer (Let's Encrypt)..."
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

echo
echo "✅ ClusterIssuer créé (letsencrypt-prod)."
echo "Tu peux vérifier son état avec : kubectl describe clusterissuer letsencrypt-prod"
pause

echo "🔹 Création de l'Ingress Headlamp..."
cat <<EOF > headlamp-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: headlamp
  namespace: kube-system
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - ${DOMAIN}
      secretName: headlamp-tls
  rules:
    - host: ${DOMAIN}
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: headlamp
                port:
                  number: 80
EOF

kubectl apply -f headlamp-ingress.yaml

echo
echo "✅ Ingress Headlamp appliqué."
pause

echo "🔹 Installe le metrics-server ..."
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
echo
echo "✅ metrics-server appliqué."
pause

echo "🌐 Installation terminée."
echo "Accès via : https://${DOMAIN}"
echo "Ports NodePort exposés : 32080 (HTTP), 32443 (HTTPS)"
echo
echo "🚀 Tu peux maintenant tester ton accès Headlamp via le navigateur."
