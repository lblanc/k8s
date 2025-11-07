#!/bin/bash
set -euo pipefail

# ========= CONFIG ==========
NAMESPACE="puls8"
HELM_RELEASE="puls8"
HELM_REPO="oci://docker.io/datacoresoftware/puls8"
# Mastes + Workers nodes list
nodes="node1 node2 node3 node4"
masternode="node1"
workernodes="node2 node3 node4"

# Linux user
user="root"
# ===========================

pause() {
  echo
  read -rp "➡️  Appuie sur [Entrée] pour continuer..."
  echo
}

install_helm() {
  echo "🔹 Téléchargement et installation de Helm..."
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
  echo "✅ Helm installé avec succès ($(helm version --short))"
}

echo "🔹 Vérification de la présence d'Helm..."
if ! command -v helm &>/dev/null; then
  echo "⚠️ Helm n'est pas détecté sur ce système."
  read -rp "Souhaites-tu que je l’installe automatiquement ? (y/N) " confirm
  if [[ "${confirm,,}" == "y" ]]; then
    install_helm
  else
    echo "❌ Installation annulée. Helm est requis pour continuer."
    exit 1
  fi
else
  echo "✅ Helm est déjà installé ($(helm version --short))"
fi
pause

echo "🔹 Création du namespace '${NAMESPACE}' (si nécessaire)..."
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -
echo "✅ Namespace ${NAMESPACE} prêt."
pause

echo "🔹 Déploiement de Puls8 via Helm..."
helm install "${HELM_RELEASE}" -n "${NAMESPACE}" --create-namespace "${HELM_REPO}" \
--set openebs.mayastor.etcd.image.repository=openebs/etcd,openebs.preUpgradeHook.image.repo=openebs/kubectl,backup.velero.kubectl.image.repository=docker.io/openebs/kubectl,openebs.engines.replicated.mayastor.enabled=true,openebs.engines.local.lvm.enabled=false,openebs.engines.local.zfs.enabled=false


echo
echo "✅ Chart Puls8 installé avec succès."
echo "Tu peux vérifier les ressources avec : kubectl get pods -n ${NAMESPACE}"
pause


echo "🔹 Installation du plugin Puls8..."
for node in ${nodes}; do
ssh ${user}@${node} "wget https://raw.githubusercontent.com/lblanc/k8s/main/debian-13/kubectl-puls8-x86_64-linux-musl.tar.gz"
ssh ${user}@${node} "tar -xvzf kubectl-puls8-x86_64-linux-musl.tar.gz"
ssh ${user}@${node} "sudo mv kubectl-puls8 /usr/local/bin/"
done

echo
echo "✅ Plugin Puls8 installé avec succès."
pause

echo "🔹 Label worker nodes..."
for node in ${workernodes}; do
kubectl label node ${node} openebs.io/engine=mayastor
done

echo
echo "✅ Label worker nodes avec succès."
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
