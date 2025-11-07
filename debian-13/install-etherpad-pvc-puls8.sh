#!/bin/bash
set -euo pipefail

# ========= CONFIG ==========
EMAIL="email@luc-blanc.com"
DOMAIN="etherpad.k8s-lab1.demo-lab.site"
NAMESPACE="etherpad"
STORAGE_SIZE="8Gi"
STORAGE_CLASS="mayastor-2"
PVC_NAME="ms-volume-claim"
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

echo "🔹 Installation du cert-manager (si absent)..."
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/latest/download/cert-manager.yaml
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
pause

echo "🔹 Création du PVC Puls8 pour le stockage d’Etherpad..."
cat <<EOF > etherpad-pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ${PVC_NAME}
  namespace: ${NAMESPACE}
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: ${STORAGE_SIZE}
  storageClassName: ${STORAGE_CLASS}
EOF
kubectl apply -f etherpad-pvc.yaml
echo "✅ PVC créé (${STORAGE_SIZE}, classe ${STORAGE_CLASS})."
pause

echo "🔹 Création du ConfigMap 'custom-headers' pour NGINX Ingress..."
kubectl create configmap custom-headers -n ingress-nginx \
  --from-literal=X-Forwarded-Proto=https \
  --from-literal=X-Forwarded-Port=443 \
  --from-literal=X-Forwarded-For=\$proxy_add_x_forwarded_for \
  --from-literal=X-Forwarded-Host=\$host \
  --dry-run=client -o yaml | kubectl apply -f -
echo "✅ ConfigMap appliqué."
pause

echo "🔹 Déploiement de Etherpad (base SQLite locale + proxy headers)..."
cat <<EOF > etherpad-deploy.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: etherpad
  namespace: ${NAMESPACE}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: etherpad
  template:
    metadata:
      labels:
        app: etherpad
    spec:
      containers:
        - name: etherpad
          image: etherpad/etherpad:latest
          imagePullPolicy: IfNotPresent
          ports:
            - containerPort: 9001
          # Exécution en root (compatibilité Mayastor)
          securityContext:
            runAsUser: 0
            runAsGroup: 0
          env:
            - name: TITLE
              value: "Etherpad Demo (SQLite)"
            - name: DEFAULT_PAD_TEXT
              value: "Bienvenue sur ton Etherpad SQLite 🚀"
            - name: ADMIN_PASSWORD
              value: "changeme"
            - name: DB_TYPE
              value: "sqlite"
            - name: DB_FILENAME
              value: "/opt/etherpad-lite/var/etherpad.sqlite"
            - name: TRUST_PROXY
              value: "true"
          volumeMounts:
            - name: etherpad-data
              mountPath: /opt/etherpad-lite/var
          readinessProbe:
            httpGet:
              path: /
              port: 9001
            initialDelaySeconds: 5
            periodSeconds: 10
          livenessProbe:
            httpGet:
              path: /
              port: 9001
            initialDelaySeconds: 15
            periodSeconds: 20
      volumes:
        - name: etherpad-data
          persistentVolumeClaim:
            claimName: ${PVC_NAME}
---
apiVersion: v1
kind: Service
metadata:
  name: etherpad
  namespace: ${NAMESPACE}
spec:
  type: ClusterIP
  selector:
    app: etherpad
  ports:
    - name: http
      port: 80
      targetPort: 9001
EOF

kubectl apply -f etherpad-deploy.yaml
echo "✅ Etherpad déployé (SQLite)."
pause

echo "🔹 Création de l'Ingress Etherpad (TLS sans rewrite)..."
cat <<EOF > etherpad-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: etherpad
  namespace: ${NAMESPACE}
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
    nginx.ingress.kubernetes.io/proxy-set-headers: "ingress-nginx/custom-headers"
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - ${DOMAIN}
      secretName: etherpad-tls
  rules:
    - host: ${DOMAIN}
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: etherpad
                port:
                  number: 80
EOF

kubectl apply -f etherpad-ingress.yaml
echo "✅ Ingress appliqué (sans rewrite)."
pause

echo "🌐 Installation terminée."
echo "Accès : https://${DOMAIN}"
echo
echo "🔑 Admin : https://${DOMAIN}/admin (mot de passe 'changeme')"
echo "💾 Données SQLite stockées dans le PVC Puls8 '${PVC_NAME}' (${STORAGE_SIZE}, classe ${STORAGE_CLASS})."
echo
echo "🔎 Vérifications :"
echo " - kubectl get pods -n ${NAMESPACE}"
echo " - kubectl logs -n ${NAMESPACE} -l app=etherpad"
echo " - kubectl get pvc -n ${NAMESPACE}"
