#!/bin/bash
set -euo pipefail

#==============================
# Logging global
#==============================
LOGFILE="/var/log/install-k8s.log"
[ ! -w /var/log ] && LOGFILE="./install-k8s.log"
exec > >(tee -a "$LOGFILE") 2>&1
echo "=== [$(date '+%F %T')] DÉMARRAGE DU SCRIPT INSTALL-K8S ==="

#==============================
# Configuration
#==============================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

nodes=("node1" "node2" "node3" "node4")
masternode="node1"
workernodes=("node2" "node3" "node4")
user="root"

#==============================
# SSH Key distribution
#==============================
echo -e "${YELLOW}🔑 Génération et distribution de la clé SSH...${NC}"
[[ ! -f ~/.ssh/id_rsa ]] && ssh-keygen -q -f ~/.ssh/id_rsa -N ""

for node in "${nodes[@]}"; do
  echo -e "${BLUE}→ Copie de la clé SSH vers ${node}${NC}"
  ssh-copy-id -o StrictHostKeyChecking=no "${user}@${node}" >/dev/null 2>&1 || {
    echo -e "${RED}Erreur : impossible de copier la clé vers ${node}${NC}"
    exit 1
  }
done

#==============================
# Script distant commun
#==============================
remote_setup=$(cat <<'EOF'
set -euo pipefail
echo "[INFO] Configuration de base sur $(hostname)"
sudo hwclock --hctosys
sudo swapoff -a && sudo sed -i '/ swap / s/^/#/' /etc/fstab
cat <<EOT | sudo tee /etc/modules-load.d/k8s.conf >/dev/null
overlay
br_netfilter
nvme_tcp
ext4
xfs
EOT
sudo modprobe overlay br_netfilter
cat <<EOT | sudo tee /etc/sysctl.d/k8s.conf >/dev/null
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOT
sudo sysctl --system >/dev/null
sudo apt update -y && sudo apt upgrade -y
sudo apt install -y apt-transport-https ca-certificates curl gnupg lsb-release
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
sudo apt update -y && sudo apt install -y containerd.io
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
sudo sed -i '/disabled_plugins/s/^/#/' /etc/containerd/config.toml
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl enable --now containerd
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list >/dev/null
sudo apt update -y && sudo apt install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
EOF
)

#==============================
# Configuration parallèle
#==============================
echo -e "${YELLOW}⚙️  Configuration des nœuds en parallèle...${NC}"

for node in "${nodes[@]}"; do
  (
    echo -e "${BLUE}→ Configuration de ${node}${NC}"
    ssh -o StrictHostKeyChecking=no "${user}@${node}" "bash -s" <<<"$remote_setup" >>"$LOGFILE" 2>&1
    echo -e "${GREEN}✔️  ${node} configuré${NC}"
  ) &
done

# Attente fiable (corrige le blocage)
while [ "$(jobs -r | wc -l)" -gt 0 ]; do
  sleep 1
done
wait 2>/dev/null || true
sync

echo -e "${GREEN}✅ Tous les nœuds sont configurés !${NC}"

#==============================
# Initialisation du master
#==============================
echo -e "${YELLOW}🚀 Initialisation du master (${masternode})${NC}"

ssh -o StrictHostKeyChecking=no "${user}@${masternode}" 'bash -s' <<'EOF' >>"$LOGFILE" 2>&1
set -e
if [ -f /etc/kubernetes/admin.conf ]; then
  echo "[INFO] ✅ Master déjà initialisé."
else
  echo "[INFO] Démarrage kubeadm init..."
  sudo kubeadm reset -f >/dev/null 2>&1 || true
  sudo systemctl restart containerd
  (
    sudo kubeadm init \
      --pod-network-cidr=10.244.0.0/16 \
      --control-plane-endpoint=node1 \
      --upload-certs \
      --ignore-preflight-errors=all \
      > /tmp/kubeadm-init.log 2>&1
    echo "[INFO] kubeadm init terminé."
  ) &
  pid=$!
  while kill -0 "$pid" 2>/dev/null; do sleep 5; done
  mkdir -p /root/.kube
  cp /etc/kubernetes/admin.conf /root/.kube/config
  chown root:root /root/.kube/config
  echo 'export KUBECONFIG=/etc/kubernetes/admin.conf' >> /root/.bashrc
  wget -q -O - https://github.com/derailed/k9s/releases/download/v0.50.16/k9s_Linux_amd64.tar.gz | tar -xz -C /usr/local/bin k9s
  echo "[INFO] ✅ Initialisation terminée."
fi
exit 0
EOF

echo -e "${GREEN}✔️ Master initialisé.${NC}"

#==============================
# Ajout des workers
#==============================
echo -e "${YELLOW}🔗 Ajout des workers${NC}"
join_cmd=$(ssh "${user}@${masternode}" "kubeadm token create --print-join-command")

for node in "${workernodes[@]}"; do
  (
    echo -e "${BLUE}→ Ajout de ${node}${NC}"
    ssh "${user}@${node}" "sudo ${join_cmd}" >>"$LOGFILE" 2>&1
    ssh "${user}@${node}" "mkdir -p /root/.kube"
    scp "${user}@${masternode}:/root/.kube/config" "${user}@${node}:/root/.kube/config" >>"$LOGFILE" 2>&1
    ssh "${user}@${node}" "chown root:root /root/.kube/config"
    echo -e "${GREEN}✔️  ${node} ajouté au cluster${NC}"
  ) &
done

while [ "$(jobs -r | wc -l)" -gt 0 ]; do
  sleep 1
done
wait 2>/dev/null || true
sync

echo -e "${GREEN}✅ Tous les workers ont rejoint le cluster !${NC}"

#==============================
# Installation Flannel
#==============================
echo -e "${YELLOW}🌐 Installation du réseau Flannel${NC}"
ssh "${user}@${masternode}" "kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml" >>"$LOGFILE" 2>&1 || true

#==============================
# Fin et résumé
#==============================
echo -e "${GREEN}✅ Cluster Kubernetes prêt !${NC}"
echo -e "📝 Log complet : ${LOGFILE}"
echo -e "👉 Commandes utiles :
  kubectl get nodes -o wide
  kubectl get pods -A
  k9s${NC}"
echo "=== [$(date '+%F %T')] INSTALLATION TERMINÉE ==="
