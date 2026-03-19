#!/bin/bash
set -euo pipefail

# ========= CONFIG ==========
DOMAIN="grafana.k8s-lab1.demo-lab.site"
# ===========================

pause() {
  echo
  read -rp "➡️  Appuie sur [Entrée] pour continuer..."
  echo
}


echo "🔹 Création de l'Ingress Grafana Puls8..."
cat <<EOF > grafana-puls8-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: puls8
  namespace: puls8
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - ${DOMAIN}
      secretName: grafana-puls8-tls
  rules:
    - host: ${DOMAIN}
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: grafana
                port:
                  number: 80
EOF

kubectl apply -f grafana-puls8-ingress.yaml

echo
echo "✅ Ingress Grafana Puls8 appliqué."
pause


echo "🌐 Installation terminée."
echo "Accès via : https://${DOMAIN}"
echo "Ports NodePort exposés : 32080 (HTTP), 32443 (HTTPS)"
echo
echo "🚀 Tu peux maintenant tester ton accès Grafana Puls8 via le navigateur."
