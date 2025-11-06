#!/bin/bash
set -euo pipefail

# ========= CONFIG ==========
NAMESPACE="puls8"
HELM_RELEASE="puls8"
HELM_REPO="oci://docker.io/datacoresoftware/puls8"
# ===========================

pause() {
  echo
  read -rp "➡️  Appuie sur [Entrée] pour continuer..."
  echo
}

echo "🔹 Vérification de la présence d'Helm..."
if ! command -v helm &>/dev/null; then
  echo "❌ Helm n'est pas installé. Installe-le avant de continuer."
  exit 1
fi
echo "✅ Helm est installé."
pause

echo "🔹 Création du namespace '${NAMESPACE}' (si nécessaire)..."
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -
echo "✅ Namespace ${NAMESPACE} prêt."
pause

echo "🔹 Déploiement de Puls8 via Helm..."
helm install "${HELM_RELEASE}" -n "${NAMESPACE}" --create-namespace "${HELM_REPO}" \
  --set openebs.engines.replicated.mayastor.enabled=true \
  --set openebs.engines.local.lvm.enabled=false \
  --set openebs.engines.local.zfs.enabled=false

echo
echo "✅ Chart Puls8 installé avec succès."
echo "Tu peux vérifier les ressources avec : kubectl get pods -n ${NAMESPACE}"
pause

echo "🔹 Vérification des pods..."
kubectl get pods -n "${NAMESPACE}" -o wide || true
pause

echo "🔹 Vérification des StorageClasses..."
kubectl get sc || true
pause

echo "🔹 Vérification du statut Helm..."
helm status "${HELM_RELEASE}" -n "${NAMESPACE}"
pause

echo "🌐 Déploiement terminé."
echo
echo "✅ Puls8 est déployé dans le namespace : ${NAMESPACE}"
echo "🧩 Moteurs activés/désactivés :"
echo "   • Mayastor : ✅ activé"
echo "   • LVM      : ❌ désactivé"
echo "   • ZFS      : ❌ désactivé"
echo
echo "💡 Commandes utiles :"
echo "   kubectl get pods -n ${NAMESPACE}"
echo "   helm list -n ${NAMESPACE}"
echo "   kubectl get sc"
echo
echo "🚀 Déploiement Puls8 terminé avec succès !"
